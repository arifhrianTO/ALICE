package connection

import (
	"context"
	"errors"
	"fmt"

	"alice-backend/internal/shared/database"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	// ErrTargetNotFound: user tujuan tidak ada atau bukan tunanetra.
	ErrTargetNotFound = errors.New("connection: tunanetra tidak ditemukan")
	// ErrAlreadyRequested: sudah ada permintaan (Menunggu atau Terhubung).
	ErrAlreadyRequested = errors.New("connection: permintaan sudah ada")
	// ErrRequestNotFound: permintaan tidak ada, bukan milik user ini,
	// atau sudah pernah dijawab.
	ErrRequestNotFound = errors.New("connection: permintaan tidak ditemukan")
)

// Repository adalah kontrak akses tabel request.
type Repository interface {
	// ListByCompanion: semua koneksi milik pendamping (semua status).
	ListByCompanion(ctx context.Context, companionID string) ([]Item, error)

	// ListIncoming: permintaan yang masih "Menunggu" untuk seorang tunanetra.
	ListIncoming(ctx context.Context, tunanetraID string) ([]Item, error)

	// Create: pendamping mengirim permintaan ke tunanetra.
	// Kalau permintaan lama berstatus "Ditolak", dikirim ulang (jadi "Menunggu").
	Create(ctx context.Context, companionID, tunanetraID string) error

	// Respond: tunanetra menerima (true) atau menolak (false).
	Respond(ctx context.Context, requestID, tunanetraID string, accept bool) error

	// Delete: memutus tautan / membatalkan permintaan.
	// Boleh dilakukan oleh pendamping maupun tunanetra yang terlibat.
	Delete(ctx context.Context, requestID, userID string) error
}

type postgresRepository struct {
	pool *pgxpool.Pool
}

func NewRepository(pool *pgxpool.Pool) Repository {
	return &postgresRepository{pool: pool}
}

// ---------------------------------------------------------------------
// Baca
// ---------------------------------------------------------------------

const listByCompanionQuery = `
	SELECT r.request_id::text, u.user_id::text, u.name, COALESCE(u.email, ''),
	       r.status::text, COALESCE(r.request_at, now()::timestamp)
	FROM public.request r
	JOIN public."user" u ON u.user_id = r.visually_impaired_id
	WHERE r.companion_id = $1::uuid
	ORDER BY r.request_at DESC NULLS LAST, u.name`

const listIncomingQuery = `
	SELECT r.request_id::text, u.user_id::text, u.name, COALESCE(u.email, ''),
	       r.status::text, COALESCE(r.request_at, now()::timestamp)
	FROM public.request r
	JOIN public."user" u ON u.user_id = r.companion_id
	WHERE r.visually_impaired_id = $1::uuid
	  AND r.status = 'Menunggu'
	ORDER BY r.request_at DESC NULLS LAST, u.name`

func (r *postgresRepository) ListByCompanion(ctx context.Context, companionID string) ([]Item, error) {
	return r.list(ctx, listByCompanionQuery, companionID)
}

func (r *postgresRepository) ListIncoming(ctx context.Context, tunanetraID string) ([]Item, error) {
	return r.list(ctx, listIncomingQuery, tunanetraID)
}

func (r *postgresRepository) list(ctx context.Context, query, userID string) ([]Item, error) {
	rows, err := r.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("ambil daftar koneksi: %w", err)
	}
	defer rows.Close()

	// Non-nil supaya JSON-nya [] dan bukan null.
	items := make([]Item, 0)
	for rows.Next() {
		var it Item
		if err := rows.Scan(&it.ID, &it.UserID, &it.Name, &it.Email, &it.Status, &it.RequestedAt); err != nil {
			return nil, fmt.Errorf("baca daftar koneksi: %w", err)
		}
		items = append(items, it)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("baca daftar koneksi: %w", err)
	}
	return items, nil
}

// ---------------------------------------------------------------------
// Tulis (lewat WithActor, sama seperti repository user)
// ---------------------------------------------------------------------

// Satu query menangani tiga kasus:
//   - tidak ada permintaan sebelumnya -> baris baru "Menunggu"
//   - ada permintaan "Ditolak"        -> diubah lagi jadi "Menunggu"
//   - ada "Menunggu"/"Terhubung"      -> tidak ada baris yang dikembalikan
//
// Pengecekan peran (tujuan harus tunanetra, pengirim harus pendamping)
// ikut dilakukan di query ini.
const createQuery = `
	INSERT INTO public.request (request_id, visually_impaired_id, companion_id, status, request_at)
	SELECT gen_random_uuid(), t.user_id, $1::uuid, 'Menunggu'::request_status, now()
	FROM public."user" t
	WHERE t.user_id = $2::uuid
	  AND t.role = 'tunanetra'
	  AND EXISTS (
	      SELECT 1 FROM public."user" c
	      WHERE c.user_id = $1::uuid AND c.role = 'pendamping'
	  )
	ON CONFLICT (visually_impaired_id, companion_id) DO UPDATE
	   SET status = 'Menunggu'::request_status,
	       request_at = now(),
	       responded_at = NULL
	   WHERE request.status = 'Ditolak'
	RETURNING request_id::text`

func (r *postgresRepository) Create(ctx context.Context, companionID, tunanetraID string) error {
	return database.WithActor(ctx, r.pool, companionID, func(tx pgx.Tx) error {
		var id string
		err := tx.QueryRow(ctx, createQuery, companionID, tunanetraID).Scan(&id)
		if err == nil {
			return nil
		}
		if !errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("simpan permintaan koneksi: %w", err)
		}

		// Tidak ada baris yang dikembalikan: bedakan "sudah ada"
		// dari "tujuan tidak valid".
		var exists bool
		const check = `
			SELECT EXISTS (
			    SELECT 1 FROM public.request
			    WHERE companion_id = $1::uuid AND visually_impaired_id = $2::uuid
			)`
		if err := tx.QueryRow(ctx, check, companionID, tunanetraID).Scan(&exists); err != nil {
			return fmt.Errorf("cek permintaan koneksi: %w", err)
		}
		if exists {
			return ErrAlreadyRequested
		}
		return ErrTargetNotFound
	})
}

func (r *postgresRepository) Respond(ctx context.Context, requestID, tunanetraID string, accept bool) error {
	status := StatusDitolak
	if accept {
		status = StatusTerhubung
	}

	return database.WithActor(ctx, r.pool, tunanetraID, func(tx pgx.Tx) error {
		const query = `
			UPDATE public.request
			SET status = $3::request_status, responded_at = now()
			WHERE request_id = $1::uuid
			  AND visually_impaired_id = $2::uuid
			  AND status = 'Menunggu'`

		tag, err := tx.Exec(ctx, query, requestID, tunanetraID, status)
		if err != nil {
			return fmt.Errorf("jawab permintaan koneksi: %w", err)
		}
		if tag.RowsAffected() == 0 {
			return ErrRequestNotFound
		}
		return nil
	})
}

func (r *postgresRepository) Delete(ctx context.Context, requestID, userID string) error {
	return database.WithActor(ctx, r.pool, userID, func(tx pgx.Tx) error {
		const query = `
			DELETE FROM public.request
			WHERE request_id = $1::uuid
			  AND (companion_id = $2::uuid OR visually_impaired_id = $2::uuid)`

		tag, err := tx.Exec(ctx, query, requestID, userID)
		if err != nil {
			return fmt.Errorf("hapus koneksi: %w", err)
		}
		if tag.RowsAffected() == 0 {
			return ErrRequestNotFound
		}
		return nil
	})
}
