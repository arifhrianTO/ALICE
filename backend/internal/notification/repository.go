package notification

import (
	"context"
	"errors"
	"fmt"

	"alice-backend/internal/shared/database"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repository adalah kontrak akses tabel "device_token".
//
// Sama seperti package lain: hanya berkas ini yang boleh menulis SQL untuk
// tabel tersebut.
type Repository interface {
	// Upsert menyimpan token perangkat. Kalau token yang sama sudah ada
	// (misalnya aplikasi dibuka lagi), barisnya diperbarui, bukan
	// diduplikasi.
	Upsert(ctx context.Context, userID, token, platform string) (*DeviceToken, error)

	// ListByUser mengambil semua token milik satu pengguna.
	ListByUser(ctx context.Context, userID string) ([]DeviceToken, error)

	// Delete membuang satu token. Dipakai saat pengguna logout atau saat
	// FCM menyatakan token itu sudah tidak terdaftar lagi.
	Delete(ctx context.Context, token string) error
}

type postgresRepository struct {
	pool *pgxpool.Pool
}

// NewRepository adalah constructor untuk Repository.
func NewRepository(pool *pgxpool.Pool) Repository {
	return &postgresRepository{pool: pool}
}

// Upsert menyimpan token perangkat beserta pemiliknya.
//
// Kenapa hapus-dulu-baru-simpan, bukan `ON CONFLICT`?
//
// `ON CONFLICT` menuntut aturan UNIQUE pada kolom "token". Aturan itu
// sengaja belum dipasang karena aplikasi memakai `app_user`, yang tidak
// boleh mengubah struktur tabel (lihat README bagian database). Selama
// aturan itu belum ada, cara yang tetap aman adalah: buang baris lama
// dengan token yang sama, lalu tulis baris baru — keduanya dalam SATU
// transaksi supaya tidak ada saat token hilang dari database.
//
// Kalau nanti DBA memasang `UNIQUE (token)`, query ini tetap benar.
func (r *postgresRepository) Upsert(ctx context.Context, userID, token, platform string) (*DeviceToken, error) {
	const deleteExisting = `DELETE FROM device_token WHERE token = $1`
	const insert = `
		INSERT INTO device_token (user_id, token, platform, upload_at)
		VALUES ($1, $2, $3::device_platform, CURRENT_TIMESTAMP)
		RETURNING token_id, upload_at`

	saved := &DeviceToken{UserID: userID, Token: token, Platform: platform}
	err := database.WithActor(ctx, r.pool, userID, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, deleteExisting, token); err != nil {
			return fmt.Errorf("bersihkan device token lama: %w", err)
		}
		if err := tx.QueryRow(ctx, insert, userID, token, platform).
			Scan(&saved.TokenID, &saved.UploadAt); err != nil {
			return fmt.Errorf("simpan device token: %w", err)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}

	return saved, nil
}

// ListByUser mengambil seluruh token milik satu pengguna.
func (r *postgresRepository) ListByUser(ctx context.Context, userID string) ([]DeviceToken, error) {
	const query = `
		SELECT token_id, user_id, token, platform, upload_at
		FROM device_token
		WHERE user_id = $1
		ORDER BY upload_at DESC`

	rows, err := r.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("daftar device token: %w", err)
	}
	defer rows.Close()

	var tokens []DeviceToken
	for rows.Next() {
		var t DeviceToken
		if err := rows.Scan(&t.TokenID, &t.UserID, &t.Token, &t.Platform, &t.UploadAt); err != nil {
			return nil, fmt.Errorf("baca device token: %w", err)
		}
		tokens = append(tokens, t)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("daftar device token: %w", err)
	}

	return tokens, nil
}

// Delete membuang satu token perangkat.
func (r *postgresRepository) Delete(ctx context.Context, token string) error {
	const query = `DELETE FROM device_token WHERE token = $1`

	if _, err := r.pool.Exec(ctx, query, token); err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return fmt.Errorf("hapus device token: %w", err)
	}
	return nil
}
