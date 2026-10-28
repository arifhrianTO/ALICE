// Package server adalah SATU-SATUNYA tempat endpoint API didaftarkan.
// Kalau ada yang bertanya "API project ini ada apa saja?", jawabannya
// ada di berkas ini.
//
// Padanan Laravel: `routes/api.php`.
package server

import (
	"net/http"
	"time"

	"alice-backend/internal/auth"
	"alice-backend/internal/shared/config"
	"alice-backend/internal/shared/middleware"
	"alice-backend/internal/shared/response"
	"alice-backend/internal/system"
	"alice-backend/internal/tunanetra"
	"alice-backend/internal/user"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Setup merakit seluruh endpoint menjadi satu router siap jalan.
//
// Inilah satu-satunya tempat "kabel" disambungkan. Alurnya selalu sama:
//
//	repository  -> juru gudang, satu-satunya yang bicara ke database
//	service     -> koki, tahu resep, memakai repository
//	handler     -> pelayan, menerima permintaan HTTP, memakai service
//	route       -> menyambungkan URL ke handler
//
// Di Laravel, penyambungan ini terjadi otomatis lewat service container
// dan anotasi. Di Go tidak ada sihir seperti itu — semuanya ditulis
// terang-terangan di bawah ini. Terkesan lebih ribet, tapi keuntungannya:
// cukup membaca beberapa baris untuk tahu persis aplikasi ini dirakit
// dari apa. Tidak ada yang tersembunyi.
func Setup(db *pgxpool.Pool, cfg *config.Config) *gin.Engine {
	// Mode produksi mematikan tulisan debug supaya log tidak berisik
	// dan tidak membocorkan informasi internal.
	if cfg.AppEnv == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	// `gin.New()` membuat router KOSONG. `gin.Default()` sama saja tapi
	// sudah otomatis memasang Logger + Recovery. Kita pakai New() supaya
	// middleware yang terpasang terlihat jelas di bawah ini.
	r := gin.New()
	r.Use(
		gin.Logger(),      // catat setiap permintaan ke terminal
		gin.Recovery(),    // kalau handler panic, server tidak ikut mati
		middleware.CORS(), // izin untuk aplikasi Flutter
	)

	// Endpoint yang tidak dikenal menjawab JSON, bukan teks kosong,
	// supaya aplikasi tidak bingung saat mengurai balasan.
	r.NoRoute(func(c *gin.Context) {
		c.JSON(http.StatusNotFound, response.Fail("endpoint tidak ditemukan"))
	})

	// Bawaannya Gin menjawab 404 juga untuk method yang salah, padahal
	// endpoint-nya ADA (misal `POST /api/hello`). Dua hal itu beda makna:
	//   404 = "endpoint ini tidak ada"
	//   405 = "endpoint ada, tapi method-nya salah"
	// Saat men-debug, perbedaan ini menghemat banyak waktu.
	r.HandleMethodNotAllowed = true
	r.NoMethod(func(c *gin.Context) {
		c.JSON(http.StatusMethodNotAllowed, response.Fail("method tidak didukung untuk endpoint ini"))
	})

	// ---------------------------------------------------------------
	// Perakitan dependency (dari dalam ke luar)
	// ---------------------------------------------------------------

	// Lapis 1: repository. Hanya lapisan ini yang menyentuh database.
	userRepo := user.NewRepository(db)
	sessionRepo := auth.NewSessionRepository(db)

	// Lapis 2: service. Menerima repository, bukan membuatnya sendiri.
	//
	// Umur token diambil dari konfigurasi (SESSION_TTL_HOURS di .env).
	// int diubah menjadi time.Duration dengan mengalikannya dengan
	// time.Hour. Di Go, `24 * time.Hour` berarti "24 jam" dan tipenya
	// benar-benar durasi waktu, bukan sekadar angka.
	authService := auth.NewService(
		userRepo,
		sessionRepo,
		time.Duration(cfg.SessionTTLHours)*time.Hour,
	)

	// Lapis 3: handler. Hanya tahu soal HTTP.
	authHandler := auth.NewHandler(authService)
	health := system.NewHealthHandler(db)

	// ---------------------------------------------------------------
	// Pendaftaran endpoint
	// ---------------------------------------------------------------

	api := r.Group("/api")
	{
		// --- sudah ada, jangan diubah bentuk balasannya ---
		// Aplikasi Flutter sudah bergantung pada bentuk lama ini.
		api.GET("/hello", system.Hello)
		api.GET("/tunanetra", tunanetra.List)

		// --- M0: fondasi ---
		api.GET("/health", health.Check)

		// --- M1: auth inti ---
		api.POST("/auth/register", authHandler.Register)
		api.POST("/auth/login", authHandler.Login)

		// --- M2: proteksi (belum dibuat) ---
		// Butuh middleware.Auth(), contoh:
		//   protected := api.Group("", middleware.Auth())
		//   protected.GET("/auth/me", authHandler.Me)
		//   protected.POST("/auth/logout", authHandler.Logout)
	}

	return r
}
