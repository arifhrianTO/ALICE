// Command server adalah pintu masuk program.
//
// Padanan Laravel: `public/index.php` + `bootstrap/app.php`.
//
// Tugasnya cuma menyambung bagian-bagian, tidak berisi logika bisnis:
//  1. baca konfigurasi
//  2. sambung ke database
//  3. rakit router
//  4. nyalakan server
package main

import (
	"context"
	"log"
	"time"

	"alice-backend/internal/server"
	"alice-backend/internal/shared/config"
	"alice-backend/internal/shared/database"
)

func main() {
	// 1. Baca konfigurasi
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("konfigurasi tidak valid: %v", err)
	}

	// 2. Sambung ke database
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	db, err := database.Connect(ctx, cfg.DSN())
	if err != nil {
		log.Fatalf("gagal konek ke database: %v", err)
	}
	defer db.Close()

	log.Println("Database: TERSAMBUNG")

	// 3. Rakit router.
	//    Semua pendaftaran endpoint ada di internal/server, bukan di sini.
	//    Seluruh konfigurasi diteruskan karena di dalamnya dibutuhkan
	//    APP_ENV (mode debug) dan SESSION_TTL_HOURS (umur token login).
	router, err := server.Setup(db, cfg)
	if err != nil {
		log.Fatalf("gagal merakit router: %v", err)
	}

	// 4. Nyalakan server
	log.Printf("Server berjalan di http://localhost:%s", cfg.AppPort)
	if err := router.Run(":" + cfg.AppPort); err != nil {
		log.Fatalf("server berhenti: %v", err)
	}
}
