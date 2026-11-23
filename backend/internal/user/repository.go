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

	"alice-backend/internal/shared/crypto"
	"alice-backend/internal/shared/database"

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
	// ListAccountsByRole mengambil ringkasan semua akun dengan peran
	// tertentu (mis. semua tunanetra), diurutkan menurut nama.
	ListAccountsByRole(ctx context.Context, role string) ([]Account, error)

	// FindByEmail mencari satu pengguna berdasarkan email.
	//
	// Kalau emailnya tidak ada, hasilnya (nil, nil) — BUKAN error. "Tidak
	// ketemu" itu kejadian biasa, bukan kerusakan. Belum dipakai oleh
	// fitur register, tapi sudah disiapkan untuk login (langkah berikutnya).
	FindByEmail(ctx context.Context, email string) (*User, error)

	// Create menyimpan pengguna baru BESERTA baris profilnya.
	// Isi field UserID pada struct akan diisi oleh database.
	// Mengembalikan ErrEmailTaken kalau emailnya sudah terpakai.
	Create(ctx context.Context, in CreateInput) error

	// FindProfile mengambil data akun + profil pendamping dalam satu query.
	//
	// Kalau penggunanya tidak ada, hasilnya (nil, nil) — sama seperti
	// FindByEmail, "tidak ketemu" bukan kerusakan.
	FindProfile(ctx context.Context, userID string) (*Profile, error)

	// UpdateProfile menyimpan perubahan nama, telepon, dan alamat.
	//
	// Nama masuk ke tabel "user", telepon & alamat ke tabel "companion".
	// Keduanya dibungkus satu transaksi supaya tidak ada perubahan separuh.
	UpdateProfile(ctx context.Context, userID, name string, phoneNumber, address *string) error
}

// postgresRepository adalah implementasi Repository yang benar-benar
// berbicara dengan PostgreSQL lewat pgx.
//
// Dia sengaja tidak diekspor (huruf kecil). Pemanggil di luar package ini
// memakai interfacenya, jadi bentuk aslinya bebas diubah kapan saja.
type postgresRepository struct {
	pool   *pgxpool.Pool
	cipher *crypto.Cipher
}

// NewRepository adalah constructor: menyiapkan Repository yang siap pakai.
//
// Kenapa lewat fungsi, bukan langsung membuat struct? Supaya "kabelnya"
// terlihat jelas saat dirakit di internal/server/routes.go. Di Laravel ini
// peran service container; di Go ditulis terang-terangan.
//
// cipher dipakai untuk mengenkripsi nomor telepon & alamat sebelum masuk
// database, dan mendekripsinya saat dibaca. Repository adalah satu-satunya
// lapisan yang menyentuh database, jadi di sinilah batas plaintext↔ciphertext
// dijaga.
func NewRepository(pool *pgxpool.Pool, cipher *crypto.Cipher) Repository {
	return &postgresRepository{pool: pool, cipher: cipher}
}

// FindByEmail mengambil satu pengguna berdasarkan email.
func (r *postgresRepository) FindByEmail(ctx context.Context, email string) (*User, error) {
	// Daftar kolom ditulis lengkap, tidak memakai `SELECT *`.
	// Kalau memakai bintang, lalu suatu hari ada kolom baru bertipe aneh,
	// query yang tadinya sehat bisa tiba-tiba gagal.
	const query = `
		SELECT u.user_id, u.role, u.email, u.password, u.auth_provider, u.name, u.provider_id,
		       c.phone_number, c.address
		FROM "user" u
		LEFT JOIN public.companion c ON u.user_id = c.user_id
		WHERE u.email = $1`

	// "$1" adalah placeholder nilai. Nilainya dikirim terpisah lewat
	// parameter kedua QueryRow, TIDAK ditempel ke dalam teks query.
	// Inilah yang membuat serangan SQL injection tidak mungkin terjadi.
	var u User
	var phone, address *string
	err := r.pool.QueryRow(ctx, query, email).Scan(
		&u.UserID,
		&u.Role,
		&u.Email,
		&u.Password,
		&u.AuthProvider,
		&u.Name,
		&u.ProviderID,
		&phone,
		&address,
	)

	// ErrNoRows artinya query berjalan lancar tapi tidak ada barisnya.
	// Ini kejadian normal, jadi kita kembalikan (nil, nil) — bukan error.
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("cari user berdasarkan email: %w", err)
	}

	// Data profil tersimpan sebagai ciphertext. Buka di sini supaya respons
	// login tidak pernah mengirim nilai "v1:..." ke aplikasi.
	if phone != nil {
		plain, err := r.cipher.Decrypt(*phone, PhoneAAD(u.UserID))
		if err != nil {
			return nil, fmt.Errorf("dekripsi nomor telepon: %w", err)
		}
		u.PhoneNumber = plain
	}
	if address != nil {
		plain, err := r.cipher.Decrypt(*address, AddressAAD(u.UserID))
		if err != nil {
			return nil, fmt.Errorf("dekripsi alamat: %w", err)
		}
		u.Address = plain
	}

	return &u, nil
}

// ListAccountsByRole mengambil ringkasan semua akun dengan peran tertentu.
//
// Dipakai halaman "Tautkan Tunanetra" supaya yang tampil adalah akun
// tunanetra yang benar-benar terdaftar, bukan data contoh.
//
// Pengurutan `lower(name)` membuat urutan abjad tidak terpengaruh
// huruf besar/kecil. Akun tanpa email dilewati karena halaman itu
// menampilkan email sebagai penanda.
func (r *postgresRepository) ListAccountsByRole(ctx context.Context, role string) ([]Account, error) {
	const query = `
		SELECT user_id, name, COALESCE(email, '')
		FROM "user"
		WHERE role = $1::user_role AND email IS NOT NULL
		ORDER BY lower(name)`

	rows, err := r.pool.Query(ctx, query, role)
	if err != nil {
		return nil, fmt.Errorf("daftar akun %s: %w", role, err)
	}
	defer rows.Close()

	var accounts []Account
	for rows.Next() {
		var a Account
		if err := rows.Scan(&a.UserID, &a.Name, &a.Email); err != nil {
			return nil, fmt.Errorf("baca akun %s: %w", role, err)
		}
		accounts = append(accounts, a)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("daftar akun %s: %w", role, err)
	}

	return accounts, nil
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
func (r *postgresRepository) Create(ctx context.Context, in CreateInput) error {
	u := in.User

	return database.WithActor(ctx, r.pool, "anonymous", func(tx pgx.Tx) error {
		const insertUser = `
			INSERT INTO "user" (role, email, password, auth_provider, name, provider_id)
			VALUES ($1::user_role, $2, $3, $4::auth_provider_type, $5, $6)
			RETURNING user_id`

		err := tx.QueryRow(ctx, insertUser,
			u.Role, u.Email, u.Password, u.AuthProvider, u.Name, u.ProviderID,
		).Scan(&u.UserID)
		if err != nil {
			if isUniqueViolation(err) {
				return ErrEmailTaken
			}
			return fmt.Errorf("simpan user: %w", err)
		}

		// Update actor context dengan user_id yang baru dibuat untuk trigger profil
		if _, err := tx.Exec(ctx, "SELECT set_config('app.current_user_id', $1, true)", u.UserID); err != nil {
			return fmt.Errorf("set actor user: %w", err)
		}

		// Baris profil dipilih menurut peran.
		insertProfile, err := profileInsertQuery(u.Role)
		if err != nil {
			return err
		}

		// Hanya pendamping yang punya kolom telepon & alamat.
		args := []any{u.UserID}
		if u.Role == RolePendamping {
			phone, err := r.encryptPhone(u.UserID, in.PhoneNumber)
			if err != nil {
				return err
			}
			address, err := r.encryptAddress(u.UserID, in.Address)
			if err != nil {
				return err
			}
			args = append(args, phone, address)
		}

		if _, err := tx.Exec(ctx, insertProfile, args...); err != nil {
			return fmt.Errorf("simpan profil %s: %w", u.Role, err)
		}

		return nil
	})
}

// profileInsertQuery mengembalikan perintah INSERT untuk tabel profil yang
// sesuai dengan peran pengguna.
func profileInsertQuery(role string) (string, error) {
	switch role {
	case RolePendamping:
		return `INSERT INTO public.companion (user_id, phone_number, address) VALUES ($1, $2, $3)`, nil
	case RoleTunanetra:
		return `INSERT INTO public.visually_impaired (user_id) VALUES ($1)`, nil
	default:
		return "", fmt.Errorf("peran tidak dikenal: %q", role)
	}
}

// FindProfile mengambil data akun dan profil pendamping sekaligus.
//
// LEFT JOIN dipakai (bukan JOIN biasa) karena pengguna tunanetra tidak
// punya baris di tabel "companion". Dengan LEFT JOIN, mereka tetap
// ditemukan, hanya kolom telepon & alamatnya bernilai NULL.
func (r *postgresRepository) FindProfile(ctx context.Context, userID string) (*Profile, error) {
	const query = `
		SELECT u.user_id, u.name, u.email, u.role, c.phone_number, c.address
		FROM "user" u
		LEFT JOIN public.companion c ON c.user_id = u.user_id
		WHERE u.user_id = $1`

	var p Profile
	err := r.pool.QueryRow(ctx, query, userID).Scan(
		&p.UserID,
		&p.Name,
		&p.Email,
		&p.Role,
		&p.PhoneNumber,
		&p.Address,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("cari profil pengguna: %w", err)
	}

	// Data di database masih berupa ciphertext. Buka di sini, tepat
	// sebelum keluar dari lapisan repository, supaya lapisan di atasnya
	// tidak pernah melihat bentuk tersandi.
	if p.PhoneNumber != nil {
		plain, err := r.cipher.Decrypt(*p.PhoneNumber, PhoneAAD(p.UserID))
		if err != nil {
			return nil, fmt.Errorf("dekripsi nomor telepon: %w", err)
		}
		p.PhoneNumber = &plain
	}
	if p.Address != nil {
		plain, err := r.cipher.Decrypt(*p.Address, AddressAAD(p.UserID))
		if err != nil {
			return nil, fmt.Errorf("dekripsi alamat: %w", err)
		}
		p.Address = &plain
	}

	return &p, nil
}

// UpdateProfile menyimpan perubahan nama, telepon, dan alamat.
//
// Perhatikan syarat `u.role = 'pendamping'` pada UPDATE companion:
// tanpa syarat itu, pengguna tunanetra bisa tanpa sengaja dibuatkan baris
// companion — padahal perannya bukan pendamping.
func (r *postgresRepository) UpdateProfile(ctx context.Context, userID, name string, phoneNumber, address *string) error {
	// Enkripsi dulu sebelum menyentuh database.
	encryptedPhone, err := r.encryptPhone(userID, phoneNumber)
	if err != nil {
		return err
	}
	encryptedAddress, err := r.encryptAddress(userID, address)
	if err != nil {
		return err
	}

	return database.WithActor(ctx, r.pool, userID, func(tx pgx.Tx) error {
		const updateUser = `UPDATE "user" SET name = $2 WHERE user_id = $1`
		if _, err := tx.Exec(ctx, updateUser, userID, name); err != nil {
			return fmt.Errorf("ubah nama pengguna: %w", err)
		}

		const updateCompanion = `
			UPDATE public.companion c
			SET phone_number = $2, address = $3
			FROM "user" u
			WHERE c.user_id = u.user_id
			  AND u.user_id = $1
			  AND u.role = $4`

		if _, err := tx.Exec(ctx, updateCompanion, userID, encryptedPhone, encryptedAddress, RolePendamping); err != nil {
			return fmt.Errorf("ubah profil pendamping: %w", err)
		}

		return nil
	})
}

// encryptPhone dan encryptAddress membungkus dua hal yang selalu terjadi
// bersamaan: menangani nilai NULL dan memberi AAD yang benar.
//
// AAD mengikat ciphertext ke pemiliknya. Tanpa AAD, ciphertext nomor
// telepon milik A bisa disalin ke baris B, lalu aplikasi akan menampilkan
// nomor A sebagai milik B — enkripsinya tetap sah, tapi datanya tertukar.
func (r *postgresRepository) encryptPhone(userID string, plain *string) (*string, error) {
	if plain == nil {
		return nil, nil
	}
	encrypted, err := r.cipher.Encrypt(*plain, PhoneAAD(userID))
	if err != nil {
		return nil, fmt.Errorf("enkripsi nomor telepon: %w", err)
	}
	return &encrypted, nil
}

func (r *postgresRepository) encryptAddress(userID string, plain *string) (*string, error) {
	if plain == nil {
		return nil, nil
	}
	encrypted, err := r.cipher.Encrypt(*plain, AddressAAD(userID))
	if err != nil {
		return nil, fmt.Errorf("enkripsi alamat: %w", err)
	}
	return &encrypted, nil
}

// AAD (Additional Authenticated Data) untuk masing-masing kolom.
// Memakai user_id + nama kolom membuat ciphertext tidak bisa dipindah
// ke pengguna atau kolom lain tanpa membuat dekripsi gagal.
func PhoneAAD(userID string) string   { return userID + ":phone_number" }
func AddressAAD(userID string) string { return userID + ":address" }

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
