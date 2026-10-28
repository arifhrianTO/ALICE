// Package repository adalah SATU-SATUNYA tempat query SQL ditulis.
// Tidak boleh ada SELECT / INSERT / UPDATE / DELETE di package lain.
//
// Keuntungan: kalau database pindah atau diganti, yang perlu diajari
// cukup package ini. Service dan handler tidak perlu diubah.
//
// Status: KERANGKA. Belum ada implementasi.
package user

// UserRepository adalah kontrak (interface) untuk mengakses tabel "user".
//
// Service berbicara lewat interface ini, bukan lewat struct konkret.
// Akibatnya, saat menguji fitur login, PostgreSQL bisa diganti dengan
// tiruan (fake) yang isinya data di memori saja.
//
// TODO (M1) definisikan method yang dibutuhkan, misalnya:
//
//	FindByEmail(ctx context.Context, email string) (*models.User, error)
//	FindByID(ctx context.Context, id string) (*models.User, error)
//	Create(ctx context.Context, user *models.User) error
type UserRepository interface {
	// TODO (M1): tambahkan method di atas sebagai signature asli.
}

// SessionRepository adalah kontrak untuk mengakses tabel "session",
// yaitu tabel yang menyimpan token login.
//
// TODO (M1) definisikan method yang dibutuhkan, misalnya:
//
//	Create(ctx context.Context, s *models.Session) error
//	FindByToken(ctx context.Context, token string) (*models.Session, error)
//	Delete(ctx context.Context, token string) error
type SessionRepository interface {
	// TODO (M1): tambahkan method di atas sebagai signature asli.
}

// postgresUserRepository adalah implementasi asli UserRepository yang
// membaca tabel "user" di PostgreSQL.
//
// TODO (M1):
//
//  1. tambahkan field: pool *pgxpool.Pool
//
//  2. buat constructor: func NewUserRepository(pool *pgxpool.Pool) UserRepository
//
//  3. implementasikan setiap method, contoh query:
//
//     SELECT user_id, role, email, password, name
//     FROM "user"
//     WHERE email = $1
//
//  4. pgx.ErrNoRows BUKAN error fatal: artinya user tidak ditemukan.
//     Kembalikan (nil, nil) supaya service bisa membalas "email/password salah".
type postgresUserRepository struct {
	// TODO (M1): pool *pgxpool.Pool
}
