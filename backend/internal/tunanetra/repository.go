package tunanetra

import (
	"context"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

// SearchItem adalah bentuk data yang dikirim ke halaman Tautkan.
//
// Field-nya sengaja hanya tiga karena itulah yang dibutuhkan aplikasi
// Flutter (`TunanetraItem.fromJson`). Nama JSON-nya memakai `user_id`,
// bukan `id`, supaya cocok dengan kunci yang dibaca aplikasi.
type SearchItem struct {
	UserID string `json:"user_id"`
	Name   string `json:"name"`
	Email  string `json:"email"`
}

// Repository adalah kontrak pencarian pengguna tunanetra.
type Repository interface {
	// Search mencari tunanetra berdasarkan nama atau email.
	// Keyword kosong berarti tampilkan semua (dibatasi limit).
	Search(ctx context.Context, keyword string, limit int) ([]SearchItem, error)
}

type postgresRepository struct {
	pool *pgxpool.Pool
}

// NewRepository menyiapkan Repository yang siap dipakai.
func NewRepository(pool *pgxpool.Pool) Repository {
	return &postgresRepository{pool: pool}
}

// Search menjalankan pencarian dengan ILIKE supaya tidak peka huruf besar/kecil.
//
// Kenapa memakai parameter ($1, $2, $3), bukan menempel keyword ke query?
// Karena parameter mencegah SQL injection: nilai dari pengguna selalu
// diperlakukan sebagai data, bukan bagian dari perintah SQL.
func (r *postgresRepository) Search(ctx context.Context, keyword string, limit int) ([]SearchItem, error) {
	keyword = strings.TrimSpace(keyword)
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	const query = `
		SELECT u.user_id::text, u.name, COALESCE(u.email, '')
		FROM public."user" u
		WHERE u.role = 'tunanetra'
		  AND ($1 = '' OR u.name ILIKE $2 OR COALESCE(u.email, '') ILIKE $2)
		ORDER BY u.name
		LIMIT $3`

	rows, err := r.pool.Query(ctx, query, keyword, "%"+keyword+"%", limit)
	if err != nil {
		return nil, fmt.Errorf("cari tunanetra: %w", err)
	}
	defer rows.Close()

	// Dibuat non-nil supaya JSON-nya menjadi [] dan bukan null.
	// Flutter membaca `body['data'] as List`, jadi null akan membuat error.
	items := make([]SearchItem, 0)
	for rows.Next() {
		var item SearchItem
		if err := rows.Scan(&item.UserID, &item.Name, &item.Email); err != nil {
			return nil, fmt.Errorf("baca hasil pencarian tunanetra: %w", err)
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("baca hasil pencarian tunanetra: %w", err)
	}

	return items, nil
}
