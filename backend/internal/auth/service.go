// Package service menampung logika bisnis aplikasi (aturan main).
// Package ini TIDAK tahu soal HTTP dan TIDAK menulis SQL.
//
// Analogi: ini kokinya. Tahu resep, tapi tidak tahu bahan disimpan
// di rak mana.
//
// Status: KERANGKA. Belum ada implementasi.
package auth

import "errors"

// ErrNotImplemented dikembalikan oleh fungsi kerangka di package ini.
var ErrNotImplemented = errors.New("service: belum diimplementasikan")

// AuthService menampung logika autentikasi (daftar, login, logout).
type AuthService struct {
	// TODO (M1) isi dengan dependency yang dibutuhkan, misalnya:
	//
	//	users    repository.UserRepository
	//	sessions repository.SessionRepository
	//	ttl      time.Duration
}

// NewAuthService membuat AuthService baru beserta seluruh dependency-nya.
//
// Ini bentuk "dependency injection" di Go: tidak ada framework dan tidak ada
// anotasi, cukup menerima lewat parameter lalu menyimpannya di struct.
//
// TODO (M1): terima repository sebagai parameter, misalnya:
//
//	func NewAuthService(users repository.UserRepository, sessions repository.SessionRepository, ttl time.Duration) *AuthService
func NewAuthService() *AuthService {
	return &AuthService{}
}

// Login memeriksa email & password, lalu membuat session token.
//
// TODO (M1) implementasi:
//  1. cari user berdasarkan email -> s.users.FindByEmail(...)
//  2. kalau tidak ditemukan, kembalikan error yang SAMA dengan kasus
//     "password salah" (jangan membocorkan mana yang salah)
//  3. cocokkan password -> bcrypt.CompareHashAndPassword
//  4. buat token acak 32 byte -> crypto/rand, lalu ubah ke hex
//  5. simpan ke tabel session dengan expired_at = sekarang + ttl
//  6. kembalikan token tersebut
func (s *AuthService) Login(email, password string) (string, error) {
	return "", ErrNotImplemented
}

// Register membuat akun baru.
//
// TODO (M1) implementasi:
//  1. validasi input (email tidak kosong, password minimal 6 karakter)
//  2. pastikan email belum terpakai
//  3. hash password -> bcrypt.GenerateFromPassword dengan cost 12
//  4. simpan ke tabel "user", lalu tambahkan data sesuai role:
//     role "pendamping" -> tambah baris di tabel companion
//     role "tunanetra"  -> tambah baris di tabel visually_impaired
func (s *AuthService) Register(name, email, password, role string) error {
	return ErrNotImplemented
}
