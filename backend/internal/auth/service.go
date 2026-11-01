// Package auth menampung logika bisnis autentikasi: daftar, login, logout.
//
// Package ini TIDAK tahu soal HTTP (tidak ada gin di sini) dan TIDAK
// menulis SQL. Analogi: ini kokinya. Tahu resep dan urutan memasaknya,
// tapi tidak tahu bahan disimpan di rak mana.
//
// Keuntungan pemisahan ini kelihatan saat menguji: resepnya bisa diuji
// tanpa menyalakan server web dan tanpa database sungguhan.
package auth

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"

	"alice-backend/internal/shared/audit"
	"alice-backend/internal/shared/validation"
	"alice-backend/internal/user"

	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

// ---------------------------------------------------------------------
// Error yang bisa dikenali lapisan di atasnya
// ---------------------------------------------------------------------

// ValidationError berarti isi permintaan tidak memenuhi aturan.
//
// Bedanya dengan error biasa: pesannya SENGaja ditulis ramah-pengguna,
// karena akan diteruskan apa adanya ke aplikasi Flutter untuk ditampilkan
// di layar. Pesan error biasa (misalnya dari database) tidak boleh
// diperlakukan begitu — bisa membocorkan hal internal.
type ValidationError struct {
	Message string
}

func (e *ValidationError) Error() string { return e.Message }

// ErrEmailTaken dikembalikan kalau emailnya sudah dipakai akun lain.
//
// Perhatikan bahwa ini error MILIK auth, berbeda dari user.ErrEmailTaken.
// Service menerjemahkan yang satu menjadi yang lain. Gunanya: lapisan HTTP
// cukup mengenal istilah milik auth saja, tidak perlu tahu seluk-beluk
// package user.
var ErrEmailTaken = errors.New("email sudah terdaftar")

// ErrInvalidCredentials dikembalikan saat email tidak ada atau password salah.
// Pesan sengaja dibuat samar supaya tidak membocorkan keberadaan email.
var ErrInvalidCredentials = errors.New("email atau password salah")

// invalid membuat ValidationError dengan ringkas.
func invalid(message string) error {
	return &ValidationError{Message: message}
}

// ---------------------------------------------------------------------
// Aturan main
// ---------------------------------------------------------------------

// PasswordMinLength adalah panjang password terkecil yang diterima.
//
// Angka ini SAMA dengan aturan di formulir Flutter ("min 6 karakter").
// Bukan kebetulan, dan bukan berarti salah satu tidak perlu:
//   - Flutter memeriksa supaya pengguna langsung dapat balasan tanpa
//     menunggu jaringan.
//   - Backend memeriksa supaya aturannya TIDAK BISA DILEWATI. Siapa pun
//     bisa mengirim permintaan langsung lewat curl dan mengabaikan
//     semua pemeriksaan di aplikasi.
//
// Aturan praktisnya: pemeriksaan di sisi klien itu kenyamanan,
// pemeriksaan di sisi server itu keamanan. Keduanya perlu.
const PasswordMinLength = 6

// bcryptCost menentukan seberapa berat proses hashing.
//
// bcrypt sengaja dibuat LAMBAT. Tujuannya: kalau suatu hari database
// bocor, penyerang yang mencoba menebak password satu per satu butuh
// waktu sangat lama. Semakin tinggi angkanya, semakin lama pula — untuk
// penyerang maupun untuk pengguna sah yang sedang login.
//
// bcrypt.DefaultCost bernilai 10 dan merupakan titik seimbang yang
// disarankan library-nya. Nilai ini sama dengan yang dipakai seeder,
// supaya semua password di database punya kekuatan yang seragam.
const bcryptCost = bcrypt.DefaultCost

// tokenBytes adalah panjang token login dalam byte.
// 32 byte = 256 bit keacakan, jauh di luar jangkauan tebak paksa.
const tokenBytes = 32

// emailPattern adalah pemeriksaan bentuk email yang sederhana tapi cukup:
// ada teks, satu tanda @, teks lagi, sebuah titik, lalu akhiran.
//
// Kenapa tidak 100% ketat? Karena aturan email resmi (RFC 5322) sangat
// rumit — ada alamat sah yang memakai tanda kutip dan karakter aneh.
// Memaksakan aturan itu akan MENOLAK email yang sebenarnya valid, dan itu
// lebih menyakitkan daripada membiarkan satu-dua alamat aneh lolos.
// Cara paling meyakinkan untuk tahu sebuah email benar-benar hidup adalah
// mengiriminya surat konfirmasi.
//
// Pola ini dikompilasi SEKALI di luar fungsi, bukan di dalam Register.
// Kalau ditaruh di dalam, pola yang sama akan dirakit ulang setiap kali
// ada yang mendaftar — pemborosan yang tidak perlu.
var emailPattern = regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)

// ---------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------

// Service adalah logika autentikasi.
//
// Perhatikan bentuknya: dia hanya MENYIMPAN dua repository dan satu
// durasi. Tidak ada koneksi database langsung, tidak ada variabel global.
// Semua yang dibutuhkan masuk lewat constructor.
//
// Ini yang disebut "dependency injection" di Go. Tidak ada framework,
// tidak ada anotasi — cukup parameter fungsi. Efeknya: saat menulis test,
// cukup membuat tiruan dua repository itu, tanpa menyentuh database.
type Service struct {
	users    user.Repository
	sessions SessionRepository
	pool     *pgxpool.Pool
	ttl      time.Duration
}

// NewService merakit Service beserta seluruh kebutuhannya.
func NewService(users user.Repository, sessions SessionRepository, pool *pgxpool.Pool, ttl time.Duration) *Service {
	return &Service{users: users, sessions: sessions, pool: pool, ttl: ttl}
}

// RegisterInput adalah data yang dibutuhkan untuk mendaftar.
//
// Perhatikan tipenya: struct biasa, BUKAN struct JSON. Struct JSON ada di
// berkas dto.go. Pemisahan ini disengaja: lapisan bisnis tidak seharusnya
// bergantung pada bentuk data di jaringan. Kalau besok register juga
// dipanggil dari perintah terminal (misalnya `make seed`), struct ini
// tetap bisa dipakai apa adanya.
type RegisterInput struct {
	Name        string
	Email       string
	Password    string
	Role        string
	PhoneNumber string
	Address     string
}

// RegisterResult adalah hasil pendaftaran yang berhasil.
type RegisterResult struct {
	User *user.User

	// Token adalah karcis login. Langsung diberikan supaya pengguna tidak
	// perlu mengetik ulang email dan password — sesuai tulisan tombol di
	// aplikasi: "Daftar & Masuk".
	Token string

	// ExpiredAt adalah waktu kedaluwarsa token tersebut.
	ExpiredAt time.Time
}

// Register membuat akun baru sekaligus sesi loginnya (auto-login).
//
// Urutannya sengaja begini:
//  1. periksa isi permintaan — lebih baik menolak sebelum menyentuh database
//  2. ubah password menjadi hash — password asli tidak boleh pernah tersimpan
//  3. simpan user + baris profilnya dalam satu transaksi
//  4. buat token acak, simpan sebagai sesi
func (s *Service) Register(ctx context.Context, in RegisterInput) (*RegisterResult, error) {
	// 1. Periksa dan rapikan isi permintaan.
	clean, err := validateRegister(in)
	if err != nil {
		return nil, err
	}

	// 2. Hash password.
	//
	// bcrypt menghasilkan hash yang berbeda setiap kali, walaupun password
	// dan salt-nya sama — karena salt dibuat acak dan ikut tertanam di
	// dalam hash. Jadi dua orang dengan password "rahasia123" punya hash
	// yang sama sekali berbeda di database.
	hash, err := bcrypt.GenerateFromPassword([]byte(in.Password), bcryptCost)
	if err != nil {
		return nil, fmt.Errorf("hash password: %w", err)
	}
	hashStr := string(hash)

	// 3. Simpan ke database.
	//
	// Password diisi dengan HASH, bukan password asli. Password asli
	// hilang begitu fungsi ini selesai — memang begitu seharusnya.
	u := &user.User{
		Name:         clean.Name,
		Email:        &clean.Email,
		Password:     &hashStr,
		Role:         clean.Role,
		AuthProvider: user.AuthProviderEmail,
	}

	if err := s.users.Create(ctx, user.CreateInput{
		User:        u,
		PhoneNumber: clean.PhoneNumber,
		Address:     clean.Address,
	}); err != nil {
		// Terjemahkan istilah milik package user menjadi istilah milik auth.
		if errors.Is(err, user.ErrEmailTaken) {
			return nil, ErrEmailTaken
		}
		return nil, err
	}

	// 4. Buat token login.
	token, err := newToken()
	if err != nil {
		return nil, err
	}

	session := &Session{
		UserID:       u.UserID,
		SessionToken: token,
		ExpiredAt:    time.Now().Add(s.ttl),
	}
	if err := s.sessions.Create(ctx, session); err != nil {
		return nil, err
	}

	return &RegisterResult{
		User:      u,
		Token:     token,
		ExpiredAt: session.ExpiredAt,
	}, nil
}

// LoginInput data kebutuhan masuk akun.
type LoginInput struct {
	Email    string
	Password string
}

// LoginResult cerminan data kembalian register (user, token, expired_at).
type LoginResult = RegisterResult

// Login periksa kecocokan kredensial dan buat session baru.
func (s *Service) Login(ctx context.Context, in LoginInput) (*LoginResult, error) {
	email := strings.ToLower(strings.TrimSpace(in.Email))
	password := in.Password

	if email == "" || password == "" {
		return nil, invalid("email dan password wajib diisi")
	}

	u, err := s.users.FindByEmail(ctx, email)
	if err != nil {
		return nil, err
	}
	if u == nil || u.Password == nil {
		_ = audit.Record(ctx, s.pool, "anonymous", "LOGIN", "user", email, "FAILED")
		return nil, ErrInvalidCredentials
	}

	if err := bcrypt.CompareHashAndPassword([]byte(*u.Password), []byte(password)); err != nil {
		_ = audit.Record(ctx, s.pool, "anonymous", "LOGIN", "user", email, "FAILED")
		return nil, ErrInvalidCredentials
	}

	token, err := newToken()
	if err != nil {
		return nil, err
	}

	session := &Session{
		UserID:       u.UserID,
		SessionToken: token,
		ExpiredAt:    time.Now().Add(s.ttl),
	}
	if err := s.sessions.Create(ctx, session); err != nil {
		return nil, err
	}

	_ = audit.Record(ctx, s.pool, u.UserID, "LOGIN", "user", u.UserID, "SUCCESS")

	return &LoginResult{
		User:      u,
		Token:     token,
		ExpiredAt: session.ExpiredAt,
	}, nil
}

// cleanRegister adalah hasil validasi yang sudah rapi dan siap disimpan.
//
// PhoneNumber dan Address bertipe pointer karena hanya berlaku untuk
// pendamping. Untuk tunanetra keduanya nil, dan kolom itu memang tidak
// ada di tabel profilnya.
type cleanRegister struct {
	Name        string
	Email       string
	Role        string
	PhoneNumber *string
	Address     *string
}

// validateRegister memeriksa isi permintaan pendaftaran sekaligus
// merapikannya, lalu mengembalikan nilai yang sudah bersih.
//
// Kenapa sekaligus merapikan, bukan memeriksa saja? Supaya tidak ada
// langkah yang terlupa. Kalau fungsi ini hanya memeriksa, pemanggilnya
// masih harus ingat untuk melakukan TrimSpace dan ToLower sendiri.
// Menyuruh pemanggil "ingat ya, nanti dirapikan" adalah cara paling
// mudah menciptakan bug.
func validateRegister(in RegisterInput) (cleanRegister, error) {
	var out cleanRegister

	// Rapikan dulu, baru periksa. Kalau diperiksa dulu, nama berisi
	// spasi saja ("   ") akan lolos dan tersimpan sebagai nama kosong.
	out.Name = strings.TrimSpace(in.Name)

	// Email dirapikan DAN dijadikan huruf kecil.
	//
	// Alasannya konkret: aturan UNIQUE di PostgreSQL peka huruf besar-
	// kecil. Tanpa langkah ini, "Budi@gmail.com" dan "budi@gmail.com"
	// dianggap dua akun berbeda — padahal bagi manusia keduanya sama,
	// dan pemiliknya jadi bingung karena tidak bisa login.
	out.Email = strings.ToLower(strings.TrimSpace(in.Email))

	out.Role = strings.TrimSpace(in.Role)

	switch {
	case out.Name == "":
		return cleanRegister{}, invalid("nama lengkap wajib diisi")

	case out.Email == "":
		return cleanRegister{}, invalid("email wajib diisi")

	case !emailPattern.MatchString(out.Email):
		return cleanRegister{}, invalid("format email tidak valid")

	case len(in.Password) < PasswordMinLength:
		// Perhatikan: password TIDAK dirapikan dengan TrimSpace.
		// Spasi di awal atau akhir password adalah bagian sah dari
		// password itu sendiri. Merapikannya diam-diam bikin pengguna
		// tidak bisa login padahal dia mengetik persis seperti saat daftar.
		return cleanRegister{}, invalid(fmt.Sprintf("password minimal %d karakter", PasswordMinLength))

	case out.Role != user.RolePendamping && out.Role != user.RoleTunanetra:
		return cleanRegister{}, invalid(`peran harus "pendamping" atau "tunanetra"`)
	}

	// Telepon & alamat hanya relevan untuk pendamping. Pengguna tunanetra
	// tidak punya kolom itu di tabel profilnya, jadi isian apa pun dari
	// klien diabaikan — bukan disimpan ke tempat yang salah.
	if out.Role == user.RolePendamping {
		phone, err := validation.NormalizePhone(in.PhoneNumber)
		if err != nil {
			return cleanRegister{}, invalid(err.Error())
		}
		out.PhoneNumber = &phone

		address, err := validation.NormalizeAddress(in.Address)
		if err != nil {
			return cleanRegister{}, invalid(err.Error())
		}
		if address != "" {
			out.Address = &address
		}
	}

	return out, nil
}

// newToken membuat token acak sepanjang tokenBytes byte, lalu menulisnya
// sebagai huruf heksadesimal (32 byte menjadi 64 huruf).
//
// Kenapa crypto/rand, bukan math/rand?
//
// math/rand menghasilkan deretan angka yang sepenuhnya bisa DITEBAK kalau
// keadaan awalnya diketahui. Untuk simulasi atau undian, itu cukup. Untuk
// token login, itu sama saja menggantung kunci di gagang pintu.
//
// crypto/rand mengambil keacakan dari sistem operasi (di Linux, dari
// /dev/urandom) yang memang dirancang tidak bisa ditebak.
func newToken() (string, error) {
	buf := make([]byte, tokenBytes)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("buat token acak: %w", err)
	}
	return hex.EncodeToString(buf), nil
}
