// Package server adalah SATU-SATUNYA tempat endpoint API didaftarkan.
// Kalau ada yang bertanya "API project ini ada apa saja?", jawabannya
// ada di berkas ini.
//
// Padanan Laravel: `routes/api.php`.
package server

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"time"

	"alice-backend/internal/assistant"
	"alice-backend/internal/auth"
	"alice-backend/internal/notification"
	"alice-backend/internal/profile"
	"alice-backend/internal/request"
	"alice-backend/internal/schedule"
	"alice-backend/internal/shared/config"
	"alice-backend/internal/shared/crypto"
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
func Setup(db *pgxpool.Pool, cfg *config.Config) (*gin.Engine, error) {
	// Siapkan alat enkripsi profil. Kunci sudah divalidasi di config.Load,
	// jadi kegagalan di sini hanya mungkin karena masalah internal.
	fieldCipher, err := crypto.New(cfg.ProfileEncryptionKey)
	if err != nil {
		return nil, fmt.Errorf("siapkan enkripsi profil: %w", err)
	}

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
	// Cipher ikut masuk ke sini supaya enkripsi/dekripsi terjadi tepat
	// di batas database, bukan tersebar di handler atau service.
	userRepo := user.NewRepository(db, fieldCipher)
	sessionRepo := auth.NewSessionRepository(db)
	notificationRepo := notification.NewRepository(db)

	// Pengirim FCM disiapkan paling akhir karena dia bergantung pada file
	// kredensial di luar database. Kalau file belum ada, notifikasi
	// dimatikan dengan peringatan — server TIDAK ikut berhenti.
	//
	// Alasannya: login, profil, dan jadwal tetap harus bisa dipakai
	// walaupun fitur push notification belum siap.
	var notificationSender notification.Sender
	sender, err := notification.NewFCMSender(context.Background(), cfg.FirebaseCredentialsFile)
	if err != nil {
		log.Printf("[notifikasi] push notification dimatikan: %v", err)
	} else {
		notificationSender = sender
		log.Println("[notifikasi] FCM siap")
	}

	// Lapis 2: service. Menerima repository, bukan membuatnya sendiri.
	//
	// Umur token diambil dari konfigurasi (SESSION_TTL_HOURS di .env).
	// int diubah menjadi time.Duration dengan mengalikannya dengan
	// time.Hour. Di Go, `24 * time.Hour` berarti "24 jam" dan tipenya
	// benar-benar durasi waktu, bukan sekadar angka.
	authService := auth.NewService(
		userRepo,
		sessionRepo,
		db,
		time.Duration(cfg.SessionTTLHours)*time.Hour,
		cfg.GoogleClientID,
		cfg.FacebookAppID,
		cfg.FacebookAppSecret,
	)
	notificationService := notification.NewService(notificationRepo, notificationSender)

	// Lapis 3: handler. Hanya tahu soal HTTP.
	authHandler := auth.NewHandler(authService)
	profileService := profile.NewService(userRepo)
	profileHandler := profile.NewHandler(profileService)
	tunanetraService := tunanetra.NewService(userRepo)
	tunanetraHandler := tunanetra.NewHandler(tunanetraService)
	requestRepo := request.NewRepository(db)
	requestService := request.NewService(requestRepo, userRepo, notificationService)
	requestHandler := request.NewHandler(requestService)
	notificationHandler := notification.NewHandler(notificationService)
	health := system.NewHealthHandler(db)
	assistantHandler := assistant.NewHandler()

	tunanetraRepo := tunanetra.NewRepository(db)
	tunanetraSearch := tunanetra.NewSearchHandler(tunanetraRepo)
	scheduleRepo := schedule.NewRepository(db)
	scheduleHandler := schedule.NewHandler(scheduleRepo, notificationService)

	// ---------------------------------------------------------------
	// Pendaftaran endpoint
	// ---------------------------------------------------------------

	api := r.Group("/api")
	{
		// --- sudah ada, jangan diubah bentuk balasannya ---
		// Aplikasi Flutter sudah bergantung pada bentuk lama ini.
		api.GET("/hello", system.Hello)
		api.POST("/assistant/ask", assistantHandler.Handle)

		// --- M0: fondasi ---
		api.GET("/health", health.Check)

		// --- M1: auth inti ---
		api.POST("/auth/register", authHandler.Register)
		api.POST("/auth/login", authHandler.Login)
		api.POST("/auth/google", authHandler.GoogleLogin)
		api.POST("/auth/facebook", authHandler.FacebookLogin)

		// --- M2: endpoint yang butuh token ---
		// Middleware.Auth membaca header `Authorization: Bearer <token>`,
		// memeriksa tabel session, lalu mengisi `user_id` ke context.
		protected := api.Group("", middleware.Auth(db))
		{
			protected.POST("/auth/logout", authHandler.Logout)
			protected.GET("/profile", profileHandler.Get)
			protected.PUT("/profile", profileHandler.Update)

			// --- Daftar akun tunanetra asli (halaman "Tautkan Tunanetra") ---
			protected.GET("/tunanetra/accounts", tunanetraHandler.ListAccounts)

			// --- Pengajuan tautan (halaman "Terhubung") ---
			// Pendamping mengirim pengajuan (POST), melihat statusnya (GET),
			// dan bisa membatalkan/memutusnya (DELETE). Semua difilter atas
			// nama pendamping yang sedang login.
			//
			// Dua endpoint terakhir dipakai sisi tunanetra: melihat
			// permintaan yang masuk (incoming) dan menerima/menolaknya
			// (respond).
			protected.GET("/requests", requestHandler.List)
			protected.POST("/requests", requestHandler.Create)
			protected.DELETE("/requests/:id", requestHandler.Delete)
			protected.GET("/requests/incoming", requestHandler.Incoming)
			protected.PUT("/requests/:id/respond", requestHandler.Respond)

			// --- Token perangkat untuk push notification ---
			// Terlindungi token login: hanya pemilik sesi yang boleh
			// mendaftarkan/menghapus token perangkat.
			protected.POST("/device-tokens", notificationHandler.RegisterToken)
			protected.DELETE("/device-tokens", notificationHandler.DeleteToken)

			// --- Pencarian tunanetra asli dari database (halaman Tautkan) ---
			protected.GET("/tunanetra/search", tunanetraSearch.Search)

			protected.GET("/schedules", scheduleHandler.ListSchedules)
			protected.GET("/schedule-requests", scheduleHandler.ListRequests)
			protected.POST("/schedule-requests", scheduleHandler.CreateRequest)
			protected.GET("/schedule-requests/incoming", scheduleHandler.Incoming)
			protected.PUT("/schedule-requests/:id/respond", scheduleHandler.Respond)
			protected.DELETE("/schedule-requests/:id", scheduleHandler.CancelRequest)

		}
	}

	return r, nil
}
