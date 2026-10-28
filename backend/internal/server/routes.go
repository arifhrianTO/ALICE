// Package routes adalah SATU-SATUNYA tempat endpoint API didaftarkan.
// Kalau ada yang bertanya "API project ini ada apa saja?", jawabannya
// ada di file ini.
//
// Padanan Laravel: `routes/api.php`.
package server

import (
	"net/http"

	"alice-backend/internal/shared/middleware"
	"alice-backend/internal/shared/response"
	"alice-backend/internal/system"
	"alice-backend/internal/tunanetra"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Setup merakit seluruh endpoint menjadi satu router siap jalan.
//
// Parameter `db` diteruskan ke handler yang butuh database. Inilah cara
// "menyambung kabel" ala Go — tidak ada service container otomatis
// seperti di Laravel, jadi penyambungannya ditulis terang-terangan.
func Setup(db *pgxpool.Pool, appEnv string) *gin.Engine {
	// Mode produksi mematikan tulisan debug supaya log tidak berisik
	// dan tidak membocorkan informasi internal.
	if appEnv == "production" {
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

	health := system.NewHealthHandler(db)

	api := r.Group("/api")
	{
		// --- sudah ada ---
		api.GET("/hello", system.Hello)
		api.GET("/tunanetra", tunanetra.List)

		// --- M0: fondasi ---
		api.GET("/health", health.Check)

		// --- M1: auth inti (belum dibuat) ---
		// api.POST("/auth/register", auth.Register)
		// api.POST("/auth/login", auth.Login)

		// --- M2: proteksi (belum dibuat) ---
		// Butuh middleware.Auth(), contoh:
		//   protected := api.Group("", middleware.Auth())
		//   protected.GET("/auth/me", auth.Me)
		//   protected.POST("/auth/logout", auth.Logout)
	}

	return r
}
