// Command seed mengisi database dengan data uji.
//
// Padanan Laravel: `php artisan db:seed`
// Cara pakai:      `make seed`
//
// Kenapa ini program Go, bukan file .sql seperti Laravel?
// Karena password harus di-hash dengan bcrypt, dan hashing itu butuh
// library. Menulis hash bcrypt langsung di file .sql akan berbahaya:
// hash yang salah ketik tetap terlihat "seperti hash", tapi login
// selalu gagal tanpa pesan error yang jelas.
//
// CATATAN soal aturan "SQL hanya boleh ada di repository/":
// Aturan itu berlaku untuk ALUR PERMINTAAN (request dari pengguna).
// Seeder ini alat pengembangan yang dijalankan manual dari terminal,
// jadi dia berbicara langsung ke database — persis seperti seeder
// Laravel yang juga memakai query sendiri.
package main

import (
	"context"
	"fmt"
	"log"
	"time"

	"alice-backend/internal/shared/config"
	"alice-backend/internal/shared/database"

	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

// seedUser adalah satu baris data uji yang akan dimasukkan.
type seedUser struct {
	Name     string
	Email    string
	Role     string // harus cocok dengan enum user_role: "tunanetra" / "pendamping"
	Password string // password asli, nanti di-hash; hanya untuk development
}

// Password untuk SEMUA akun uji di bawah ini. Jangan dipakai di produksi.
const seedPassword = "password123"

var seedUsers = []seedUser{
	{Name: "Rizky", Email: "user1@gmail.com", Role: "tunanetra", Password: seedPassword},
	{Name: "Pengguna Tunanetra", Email: "tunanetra@example.com", Role: "tunanetra", Password: seedPassword},
	{Name: "Pengguna Pendamping", Email: "pendamping@example.com", Role: "pendamping", Password: seedPassword},
}

func main() {
	if err := run(); err != nil {
		log.Fatalf("seeder gagal: %v", err)
	}
}

func run() error {
	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("konfigurasi tidak valid: %w", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	db, err := database.Connect(ctx, cfg.DSN())
	if err != nil {
		return fmt.Errorf("tidak bisa konek ke database: %w", err)
	}
	defer db.Close()

	fmt.Printf("Mengisi data uji ke database %q\n\n", cfg.DBName)

	for _, u := range seedUsers {
		if err := upsertUser(ctx, db, u); err != nil {
			return fmt.Errorf("gagal mengisi %s: %w", u.Email, err)
		}
		fmt.Printf("  OK  %-24s %-11s %s\n", u.Email, u.Role, u.Name)
	}

	total, err := countUsers(ctx, db)
	if err != nil {
		return err
	}

	fmt.Printf("\nSelesai. Tabel \"user\" sekarang berisi %d baris.\n", total)
	fmt.Printf("Semua akun uji memakai password: %s\n", seedPassword)

	return nil
}

// upsertUser memasukkan satu pengguna.
//
// Disebut "upsert" (update + insert): kalau email-nya SUDAH ADA, datanya
// diperbarui; kalau belum ada, baris baru dibuat. Karena itu perintah ini
// aman dijalankan berulang kali — tidak akan membuat data ganda.
//
// Inilah yang memperbaiki hash password rusak di user1@gmail.com:
// baris lama ditimpa dengan hash bcrypt yang sah.
func upsertUser(ctx context.Context, db *pgxpool.Pool, u seedUser) error {
	hash, err := bcrypt.GenerateFromPassword([]byte(u.Password), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("gagal membuat hash password: %w", err)
	}

	const query = `
		INSERT INTO public."user" (role, name, email, password)
		VALUES ($1::user_role, $2, $3, $4)
		ON CONFLICT (email) DO UPDATE
		   SET name     = EXCLUDED.name,
		       role     = EXCLUDED.role,
		       password = EXCLUDED.password
		RETURNING user_id`

	var userID string
	err = db.QueryRow(ctx, query, u.Role, u.Name, u.Email, string(hash)).Scan(&userID)
	if err != nil {
		return err
	}

	// Tabel profil hanya ada untuk peran tertentu:
	//   tunanetra  -> visually_impaired
	//   pendamping -> companion
	// Kalau barisnya sudah ada, DO NOTHING membuat perintah ini aman diulang.
	switch u.Role {
	case "tunanetra":
		_, err = db.Exec(ctx,
			`INSERT INTO public.visually_impaired (user_id) VALUES ($1)
			 ON CONFLICT (user_id) DO NOTHING`, userID)
	case "pendamping":
		_, err = db.Exec(ctx,
			`INSERT INTO public.companion (user_id) VALUES ($1)
			 ON CONFLICT (user_id) DO NOTHING`, userID)
	}

	return err
}

func countUsers(ctx context.Context, db *pgxpool.Pool) (int, error) {
	var n int
	err := db.QueryRow(ctx, `SELECT count(*) FROM public."user"`).Scan(&n)
	return n, err
}
