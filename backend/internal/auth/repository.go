package auth

import (
	"context"
	"fmt"

	"alice-backend/internal/shared/database"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// SessionRepository adalah kontrak akses tabel "session".
//
// Nama `Repository` saja, karena nama package-nya sudah auth. Dibaca
// lengkap menjadi `auth.SessionRepository`.
type SessionRepository interface {
	// Create menyimpan satu sesi login baru.
	Create(ctx context.Context, s *Session) error

	// DeleteByToken mencabut satu sesi sehingga tokennya tidak berlaku lagi.
	DeleteByToken(ctx context.Context, token string) error
}

type postgresSessionRepository struct {
	pool *pgxpool.Pool
}

// NewSessionRepository adalah constructor untuk SessionRepository.
func NewSessionRepository(pool *pgxpool.Pool) SessionRepository {
	return &postgresSessionRepository{pool: pool}
}

// Create menyimpan satu sesi login.
func (r *postgresSessionRepository) Create(ctx context.Context, s *Session) error {
	const query = `
		INSERT INTO "session" (user_id, session_token, expired_at)
		VALUES ($1, $2, $3)`

	return database.WithActor(ctx, r.pool, s.UserID, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, query, s.UserID, s.SessionToken, s.ExpiredAt); err != nil {
			return fmt.Errorf("simpan session: %w", err)
		}
		return nil
	})
}

// DeleteByToken menghapus sesi berdasarkan nilai tokennya.
func (r *postgresSessionRepository) DeleteByToken(ctx context.Context, token string) error {
	const query = `DELETE FROM "session" WHERE session_token = $1`

	if _, err := r.pool.Exec(ctx, query, token); err != nil {
		return fmt.Errorf("hapus session: %w", err)
	}
	return nil
}
