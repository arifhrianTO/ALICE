// Package config bertanggung jawab membaca konfigurasi aplikasi dari
// environment sistem.
//
// ATURAN: hanya package ini yang boleh memanggil os.Getenv.
// Package lain cukup menerima struct Config.
package config

import (
	"encoding/base64"
	"fmt"
	"net"
	"net/url"
	"os"
	"strconv"
	"strings"

	"alice-backend/internal/shared/crypto"

	"github.com/joho/godotenv"
)

// Config menampung seluruh konfigurasi aplikasi.
// Nama field di bawah mencerminkan isi file .env (lihat .env.example).
type Config struct {
	AppEnv          string // "development" | "production"
	AppPort         string // port HTTP server, contoh "8080"
	DBHost          string // contoh "localhost"
	DBPort          string // contoh "5432"
	DBUser          string // contoh "app_user"
	DBPassword      string // boleh kosong untuk koneksi lokal (trust auth)
	DBName          string // contoh "db_alice"
	DBSSLMode       string // "disable" di lokal, "require" di produksi
	SessionTTLHours int    // umur token login, dalam jam

	// ProfileEncryptionKey adalah kunci AES-256 (32 byte) untuk mengenkripsi
	// nomor telepon & alamat pendamping. Sudah dalam bentuk byte hasil
	// decode base64, siap dipakai crypto.New.
	//
	// Kunci ini HANYA boleh hidup di environment aplikasi, tidak pernah
	// disimpan di database.
	ProfileEncryptionKey []byte
	GoogleClientID       string // Client ID OAuth 2.0 dari Google Cloud Console
}

// Load merakit konfigurasi dari file .env (kalau ada) dan environment sistem.
//
// Urutan prioritasnya:
//  1. environment sistem (menang) - berguna untuk menimpa nilai saat menguji
//  2. isi file .env
//  3. nilai cadangan di kode ini
//
// Catatan: file .env dibaca dari direktori kerja saat program dijalankan.
// Jadi jalankan server dari dalam folder backend/ (`go run ./cmd/server`).
func Load() (*Config, error) {
	// Error sengaja diabaikan: di produksi file .env memang tidak ada,
	// nilainya datang dari environment sistem.
	_ = godotenv.Load()

	ttl, err := strconv.Atoi(getEnv("SESSION_TTL_HOURS", "24"))
	if err != nil {
		return nil, fmt.Errorf("SESSION_TTL_HOURS harus berupa angka: %w", err)
	}

	// Kunci enkripsi profil WAJIB ada dan sah. Kalau tidak, lebih baik
	// aplikasi berhenti sekarang daripada diam-diam menyimpan nomor
	// telepon & alamat dalam bentuk plaintext.
	keyEncoded := getEnv("PROFILE_ENCRYPTION_KEY", "")
	if keyEncoded == "" {
		return nil, fmt.Errorf(
			"PROFILE_ENCRYPTION_KEY wajib diisi (buat dengan: openssl rand -base64 32)",
		)
	}

	key, err := base64.StdEncoding.DecodeString(strings.TrimSpace(keyEncoded))
	if err != nil {
		return nil, fmt.Errorf("PROFILE_ENCRYPTION_KEY harus base64 yang valid: %w", err)
	}
	if len(key) != crypto.KeySize {
		return nil, fmt.Errorf(
			"PROFILE_ENCRYPTION_KEY harus %d byte setelah di-decode, sekarang %d",
			crypto.KeySize, len(key),
		)
	}

	cfg := &Config{
		AppEnv:               getEnv("APP_ENV", "development"),
		AppPort:              getEnv("APP_PORT", "8080"),
		DBHost:               getEnv("DB_HOST", "localhost"),
		DBPort:               getEnv("DB_PORT", "5432"),
		DBUser:               getEnv("DB_USER", "app_user"),
		DBPassword:           getEnv("DB_PASSWORD", ""),
		DBName:               getEnv("DB_NAME", "db_alice"),
		DBSSLMode:            getEnv("DB_SSLMODE", "disable"),
		SessionTTLHours:      ttl,
		ProfileEncryptionKey: key,
		GoogleClientID:       getEnv("GOOGLE_CLIENT_ID", ""),
	}

	if cfg.DBUser == "" || cfg.DBName == "" {
		return nil, fmt.Errorf("DB_USER dan DB_NAME wajib diisi")
	}

	return cfg, nil
}

// DSN mengembalikan alamat koneksi database dalam format URL yang
// dimengerti pgx (driver PostgreSQL).
//
// Contoh hasil:
//
//	postgres://app_user:@localhost:5432/db_alice?sslmode=disable
//
// Kenapa pakai format URL, bukan "host=... user=..."?
// Karena password bisa berisi karakter khusus (@, :, /). Kalau memakai
// format kata kunci, karakter itu harus dikutip manual dan gampang salah.
// url.UserPassword menangani peng-encode-an itu otomatis.
//
// Bahaya yang sudah teruji: format kata kunci dengan password KOSONG
// membuat parser salah baca - "password= dbname=db_alice" terbaca sebagai
// password bernilai "dbname=db_alice" dan nama database jadi kosong.
func (c *Config) DSN() string {
	u := &url.URL{
		Scheme: "postgres",
		User:   url.UserPassword(c.DBUser, c.DBPassword),
		Host:   net.JoinHostPort(c.DBHost, c.DBPort),
		Path:   c.DBName,
	}

	q := u.Query()
	q.Set("sslmode", c.DBSSLMode)
	u.RawQuery = q.Encode()

	return u.String()
}

// getEnv mengambil nilai environment variable.
// Kalau tidak ada atau kosong, kembalikan nilai cadangan.
func getEnv(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return fallback
}
