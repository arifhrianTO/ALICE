// Package user mengurus data pengguna: tabel "user" beserta tabel
// profilnya ("companion" dan "visually_impaired").
//
// ATURAN: SQL untuk ketiga tabel itu hanya ditulis di berkas ini.
// Service dan handler tidak boleh menulis SQL.
//
// Kenapa? Karena SQL itu hal paling cepat berubah saat proyek tumbuh
// (kolom ditambah, nama tabel disesuaikan). Kalau query tersebar di
// sepuluh berkas, perubahan kecil menuntut sepuluh perbaikan.
//
// Padanan Laravel: kira-kira seperti mengumpulkan semua `User::query()`
// ke satu kelas, tapi tanpa sihir Eloquent — query-nya terlihat utuh.
package user

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ErrEmailTaken dikembalikan saat email yang didaftarkan sudah dipakai.
//
// Perhatikan asalnya: error ini DITERJEMAHKAN dari kode kesalahan
// PostgreSQL 23505, bukan dari pengecekan manual "SELECT dulu, ada tidak?".
// Alasannya ada di komentar method Create.
var ErrEmailTaken = errors.New("user: email sudah terdaftar")

// Repository adalah kontrak akses tabel-tabel pengguna.
//
// Service berbicara lewat interface ini, bukan lewat struct konkret.
// Akibatnya saat pengujian, PostgreSQL bisa diganti tiruan (fake) berisi
// data di memori — tanpa perlu menyalakan database.
//
// Nama `Repository` saja (bukan `UserRepository`) karena nama package-nya
// sudah `user`. Ditulis lengkap jadi `user.Repository`, bukan
// `user.UserRepository` yang mengulang kata. Sama seperti di Laravel kamu
// menulis `User::find()` dan bukan `User::userFind()`.
type Repository interface {
	// FindByEmail mencari satu pengguna berdasarkan email.
	//
	// Kalau emailnya tidak ada, hasilnya (nil, nil) — BUKAN error. "Tidak
	// ketemu" itu kejadian biasa, bukan kerusakan. Belum dipakai oleh
	// fitur register, tapi sudah disiapkan untuk login (langkah berikutnya).
	FindByEmail(ctx context.Context, email string) (*User, error)

	// Create menyimpan pengguna baru BESERTA baris profilnya.
	// Isi field UserID pada struct akan diisi oleh database.
	// Mengembalikan ErrEmailTaken kalau emailnya sudah terpakai.
	Create(ctx context.Context, u *User) error
}

// postgresRepository adalah implementasi Repository yang benar-benar
// berbicara dengan PostgreSQL lewat pgx.
//
// Dia sengaja tidak diekspor (huruf kecil). Pemanggil di luar package ini
// memakai interfacenya, jadi bentuk aslinya bebas diubah kapan saja.
type postgresRepository struct {
	pool *pgxpool.Pool
}

// NewRepository adalah constructor: menyiapkan Repository yang siap pakai.
//
// Kenapa lewat fungsi, bukan langsung membuat struct? Supaya "kabelnya"
// terlihat jelas saat dirakit di internal/server/routes.go. Di Laravel ini
// peran service container; di Go ditulis terang-terangan.
func NewRepository(pool *pgxpool.Pool) Repository {
	return &postgresRepository{pool: pool}
}

// FindByEmail mengambil satu pengguna berdasarkan email.
func (r *postgresRepository) FindByEmail(ctx context.Context, email string) (*User, error) {
	// Daftar kolom ditulis lengkap, tidak memakai `SELECT *`.
	// Kalau memakai bintang, lalu suatu hari ada kolom baru bertipe aneh,
	// query yang tadinya sehat bisa tiba-tiba gagal.
	const query = `
		SELECT user_id, role, email, password, auth_provider, name, provider_id
		FROM "user"
		WHERE email = $1`

	// "$1" adalah placeholder nilai. Nilainya dikirim terpisah lewat
	// parameter kedua QueryRow, TIDAK ditempel ke dalam teks query.
	// Inilah yang membuat serangan SQL injection tidak mungkin terjadi.
	var u User
	err := r.pool.QueryRow(ctx, query, email).Scan(
		&u.UserID,
		&u.Role,
		&u.Email,
		&u.Password,
		&u.AuthProvider,
		&u.Name,
		&u.ProviderID,
	)

	// ErrNoRows artinya query berjalan lancar tapi tidak ada barisnya.
	// Ini kejadian normal, jadi kita kembalikan (nil, nil) — bukan error.
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("cari user berdasarkan email: %w", err)
	}

	return &u, nil
}

// Create menyimpan pengguna baru beserta baris profilnya.
//
// Register menyentuh DUA tabel: "user" dan salah satu dari "companion" /
// "visually_impaired". Keduanya dibungkus satu TRANSAKSI.
//
// Transaksi = rangkaian perintah yang dianggap satu pekerjaan utuh:
// berhasil semua, atau batal semua. Tanpa itu, kalau penyimpanan profil
// gagal, baris "user" sudah terlanjur masuk — lahirlah pengguna tanpa
// profil, dan semua kode yang mengira profilnya ada akan ikut rusak.
func (r *postgresRepository) Create(ctx context.Context, u *User) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("mulai transaksi: %w", err)
	}

	// Rollback dipanggil lewat `defer` supaya PASTI berjalan, termasuk
	// kalau terjadi panic di tengah jalan. Kalau transaksinya sudah
	// di-commit, panggilan ini tidak melakukan apa-apa.
	defer func() { _ = tx.Rollback(ctx) }()

	// Tanda `::user_role` dan `::auth_provider_type` adalah cast (paksaan
	// jenis). Kata "pendamping" hanyalah teks biasa bagi PostgreSQL;
	// cast memberi tahu bahwa yang dimaksud adalah nilai enum user_role.
	// Tanpa cast, PostgreSQL menolak dengan "column is of type user_role
	// but expression is of type text".
	const insertUser = `
		INSERT INTO "user" (role, email, password, auth_provider, name)
		VALUES ($1::user_role, $2, $3, $4::auth_provider_type, $5)
		RETURNING user_id`

	err = tx.QueryRow(ctx, insertUser,
		u.Role, u.Email, u.Password, u.AuthProvider, u.Name,
	).Scan(&u.UserID)
	if err != nil {
		// Di sini kita TIDAK melakukan "SELECT dulu, sudah ada tidak?".
		// Kita biarkan database yang menjadi hakim lewat aturan UNIQUE,
		// lalu menerjemahkan penolakannya.
		//
		// Kenapa begitu? Karena pengecekan manual punya celah balapan:
		// dua orang mendaftar dengan email sama pada milidetik yang sama
		// bisa sama-sama lolos pengecekan, lalu tetap bentrok saat
		// disimpan. Aturan UNIQUE tidak punya celah itu.
		if isUniqueViolation(err) {
			return ErrEmailTaken
		}
		return fmt.Errorf("simpan user: %w", err)
	}

	// Baris profil dipilih menurut peran.
	insertProfile, err := profileInsertQuery(u.Role)
	if err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, insertProfile, u.UserID); err != nil {
		return fmt.Errorf("simpan profil %s: %w", u.Role, err)
	}

	// Commit = "ya, saya yakin, simpan permanen".
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit transaksi: %w", err)
	}

	return nil
}

// profileInsertQuery mengembalikan perintah INSERT untuk tabel profil yang
// sesuai dengan peran pengguna.
func profileInsertQuery(role string) (string, error) {
	switch role {
	case RolePendamping:
		return `INSERT INTO public.companion (user_id) VALUES ($1)`, nil
	case RoleTunanetra:
		return `INSERT INTO public.visually_impaired (user_id) VALUES ($1)`, nil
	default:
		return "", fmt.Errorf("peran tidak dikenal: %q", role)
	}
}

// isUniqueViolation menjawab pertanyaan: apakah error ini berasal dari
// aturan UNIQUE di PostgreSQL?
//
// Kode 23505 adalah kode baku PostgreSQL untuk "unique_violation".
// Angka ini sama di seluruh dunia, jadi aman dipakai.
//
// `errors.As` dipakai (bukan type assertion biasa) karena error yang
// sampai ke sini sudah dibungkus beberapa lapis oleh pgx. errors.As
// membongkar bungkusannya untuk mencari error aslinya.
func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}
