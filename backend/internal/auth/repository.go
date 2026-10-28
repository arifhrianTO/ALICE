package auth

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

// SessionRepository adalah kontrak akses tabel "session".
//
// Nama `Repository` saja, karena nama package-nya sudah auth. Dibaca
// lengkap menjadi `auth.SessionRepository`.
type SessionRepository interface {
	// Create menyimpan satu sesi login baru.
	Create(ctx context.Context, s *Session) error
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
	// Kolom request_at sengaja TIDAK ikut diisi. Database sudah punya
	// nilai bawaannya sendiri: CURRENT_TIMESTAMP. Aturan praktisnya:
	// jangan mengirim ulang nilai yang sudah punya default — kecuali
	// memang ada alasan kuat untuk menimpanya.
	//
	// Tanda kutip pada "session" bukan keharusan (kata itu bukan kata
	// terlarang di PostgreSQL), tapi dipakai supaya seragam dengan
	// "user" yang memang WAJIB dikutip. `user` adalah kata kunci SQL.
	const query = `
		INSERT INTO "session" (user_id, session_token, expired_at)
		VALUES ($1, $2, $3)`

	if _, err := r.pool.Exec(ctx, query, s.UserID, s.SessionToken, s.ExpiredAt); err != nil {
		return fmt.Errorf("simpan session: %w", err)
	}

	return nil
}
