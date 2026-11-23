// Package request mengurus pengajuan tautan antara pendamping dan
// tunanetra: tabel `request` beserta statusnya (Menunggu/Terhubung/Ditolak).
//
// ATURAN: SQL untuk tabel `request` hanya ditulis di berkas ini. Service
// dan handler tidak boleh menulis SQL — sama seperti package lain di
// proyek ini.
package request

import (
	"context"
	"errors"
	"fmt"

	"alice-backend/internal/shared/database"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ErrNotFound dikembalikan kalau pengajuan yang mau dihapus tidak ada,
// atau bukan milik pendamping yang meminta.
var ErrNotFound = errors.New("request: pengajuan tidak ditemukan")

// Repository adalah kontrak akses tabel `request`.
//
// Service berbicara lewat interface ini supaya saat pengujian PostgreSQL
// bisa diganti tiruan berisi data di memori.
type Repository interface {
	// ListByCompanion mengambil semua pengajuan milik satu pendamping,
	// terbaru lebih dulu, sudah digabung dengan nama & email tunanetra.
	ListByCompanion(ctx context.Context, companionID string) ([]Request, error)

	// Create membuat pengajuan baru berstatus "Menunggu".
	//
	// Kalau pasangan pendamping↔tunanetra ini sudah pernah mengajukan,
	// barisnya TIDAK diduplikasi (ada UNIQUE constraint), melainkan
	// dikembalikan ke status "Menunggu" supaya pengajuan ulang setelah
	// "Ditolak" tetap bekerja.
	Create(ctx context.Context, companionID, visuallyImpairedID string) (*Request, error)

	// Delete membuang satu pengajuan milik pendamping tersebut.
	// Mengembalikan ErrNotFound kalau tidak ada baris yang cocok.
	Delete(ctx context.Context, companionID, requestID string) error

	// ListIncoming mengambil semua pengajuan berstatus "Menunggu" untuk
	// seorang tunanetra, terbaru lebih dulu, sudah digabung dengan nama &
	// email pendamping pengaju.
	ListIncoming(ctx context.Context, tunanetraID string) ([]IncomingRequest, error)

	// Respond menandai pengajuan sebagai "Terhubung" (accept true) atau
	// "Ditolak" (accept false). Hanya baris milik tunanetra tersebut dan
	// yang masih berstatus "Menunggu" yang boleh berubah. Mengembalikan
	// ErrNotFound kalau tidak ada baris yang cocok.
	Respond(ctx context.Context, requestID, tunanetraID string, accept bool) error
}

type postgresRepository struct {
	pool *pgxpool.Pool
}

// NewRepository adalah constructor untuk Repository.
func NewRepository(pool *pgxpool.Pool) Repository {
	return &postgresRepository{pool: pool}
}

// kolomSelect dipakai bersama oleh query daftar dan query satu baris,
// supaya bentuk hasilnya selalu sama.
const kolomSelect = `
	SELECT r.request_id, r.visually_impaired_id, v.name, COALESCE(v.email, ''),
	       r.status::text, r.request_at, r.responded_at
	FROM request r
	JOIN "user" v ON v.user_id = r.visually_impaired_id`

// ListByCompanion mengambil semua pengajuan milik satu pendamping.
//
// `r.status::text` dipakai supaya hasil enum dibaca sebagai teks biasa
// oleh pgx, bukan tipe enum yang tidak dikenal.
func (r *postgresRepository) ListByCompanion(ctx context.Context, companionID string) ([]Request, error) {
	const query = kolomSelect + `
		WHERE r.companion_id = $1
		ORDER BY r.request_at DESC`

	rows, err := r.pool.Query(ctx, query, companionID)
	if err != nil {
		return nil, fmt.Errorf("daftar pengajuan pendamping: %w", err)
	}
	defer rows.Close()

	var items []Request
	for rows.Next() {
		var it Request
		if err := rows.Scan(
			&it.ID,
			&it.VisuallyImpairedID,
			&it.Name,
			&it.Email,
			&it.Status,
			&it.RequestAt,
			&it.RespondedAt,
		); err != nil {
			return nil, fmt.Errorf("baca pengajuan pendamping: %w", err)
		}
		items = append(items, it)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("daftar pengajuan pendamping: %w", err)
	}

	return items, nil
}

// listIncomingQuery mengambil pengajuan masuk milik seorang tunanetra.
//
// Nama & email di sini milik PENDAMPING (c), karena dialah pengajunya —
// kebalikan dari `kolomSelect` yang mengambil data tunanetra.
const listIncomingQuery = `
	SELECT r.request_id, r.companion_id, c.name, COALESCE(c.email, ''),
	       r.status::text, r.request_at
	FROM request r
	JOIN "user" c ON c.user_id = r.companion_id
	WHERE r.visually_impaired_id = $1
	  AND r.status = 'Menunggu'
	ORDER BY r.request_at DESC`

// ListIncoming mengambil semua pengajuan "Menunggu" untuk seorang tunanetra.
func (r *postgresRepository) ListIncoming(ctx context.Context, tunanetraID string) ([]IncomingRequest, error) {
	rows, err := r.pool.Query(ctx, listIncomingQuery, tunanetraID)
	if err != nil {
		return nil, fmt.Errorf("daftar permintaan masuk: %w", err)
	}
	defer rows.Close()

	var items []IncomingRequest
	for rows.Next() {
		var it IncomingRequest
		if err := rows.Scan(
			&it.ID,
			&it.CompanionID,
			&it.CompanionName,
			&it.CompanionEmail,
			&it.Status,
			&it.RequestAt,
		); err != nil {
			return nil, fmt.Errorf("baca permintaan masuk: %w", err)
		}
		items = append(items, it)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("baca permintaan masuk: %w", err)
	}

	return items, nil
}

// Create membuat (atau mengaktifkan kembali) pengajuan berstatus "Menunggu".
//
// Tabel `request` punya trigger audit, jadi operasinya dibungkus
// database.WithActor agar trigger tahu siapa pelakunya.
func (r *postgresRepository) Create(ctx context.Context, companionID, visuallyImpairedID string) (*Request, error) {
	const upsert = `
		INSERT INTO request (companion_id, visually_impaired_id, status)
		VALUES ($1, $2, 'Menunggu')
		ON CONFLICT (visually_impaired_id, companion_id)
		DO UPDATE SET status = 'Menunggu',
		              request_at = CURRENT_TIMESTAMP,
		              responded_at = NULL`

	const selectOne = kolomSelect + `
		WHERE r.companion_id = $1 AND r.visually_impaired_id = $2`

	var created Request
	err := database.WithActor(ctx, r.pool, companionID, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, upsert, companionID, visuallyImpairedID); err != nil {
			return fmt.Errorf("simpan pengajuan: %w", err)
		}
		if err := tx.QueryRow(ctx, selectOne, companionID, visuallyImpairedID).Scan(
			&created.ID,
			&created.VisuallyImpairedID,
			&created.Name,
			&created.Email,
			&created.Status,
			&created.RequestAt,
			&created.RespondedAt,
		); err != nil {
			return fmt.Errorf("baca pengajuan tersimpan: %w", err)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}

	return &created, nil
}

// Delete membuang satu pengajuan milik pendamping tersebut.
//
// Filter companion_id memastikan seseorang tidak bisa menghapus pengajuan
// milik pendamping lain walaupun tahu request_id-nya.
func (r *postgresRepository) Delete(ctx context.Context, companionID, requestID string) error {
	const query = `DELETE FROM request WHERE request_id = $1 AND companion_id = $2`

	err := database.WithActor(ctx, r.pool, companionID, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, query, requestID, companionID)
		if err != nil {
			return fmt.Errorf("hapus pengajuan: %w", err)
		}
		if tag.RowsAffected() == 0 {
			return ErrNotFound
		}
		return nil
	})
	if err != nil {
		return err
	}

	return nil
}

// Respond menandai satu pengajuan sebagai "Terhubung" atau "Ditolak".
//
// Filter `visually_impaired_id` memastikan tunanetra hanya bisa menjawab
// pengajuan yang memang ditujukan kepadanya, dan `status = 'Menunggu'`
// mencegah menjawab ulang pengajuan yang sudah dijawab.
func (r *postgresRepository) Respond(ctx context.Context, requestID, tunanetraID string, accept bool) error {
	status := StatusDitolak
	if accept {
		status = StatusTerhubung
	}

	const query = `
		UPDATE request
		SET status = $3::request_status, responded_at = CURRENT_TIMESTAMP
		WHERE request_id = $1
		  AND visually_impaired_id = $2
		  AND status = 'Menunggu'`

	return database.WithActor(ctx, r.pool, tunanetraID, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, query, requestID, tunanetraID, status)
		if err != nil {
			return fmt.Errorf("jawab pengajuan: %w", err)
		}
		if tag.RowsAffected() == 0 {
			return ErrNotFound
		}
		return nil
	})
}
