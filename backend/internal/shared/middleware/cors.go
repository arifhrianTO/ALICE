package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// CORS menentukan siapa yang boleh memanggil API ini dari browser.
//
// Singkatnya: aplikasi Flutter (terutama versi web) berjalan di alamat
// berbeda dari backend. Tanpa izin CORS, browser akan memblokir
// permintaannya sebelum sampai ke server, dengan pesan di konsol seperti:
//
//	Access to fetch at 'http://localhost:8080/api/...' has been blocked
//	by CORS policy
//
// Padanan Laravel: `config/cors.php` + middleware HandleCors.
//
// CATATAN PENTING soal Gin (lihat README bagian 11):
// di Gin, `return` TIDAK menghentikan rantai middleware. Harus memakai
// `c.Abort()` / `c.AbortWithStatus()`. Kalau lupa, permintaan yang
// seharusnya ditolak malah diteruskan.
func CORS() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		// Authorization wajib ada di sini: nanti token login dikirim
		// lewat header itu. Kalau tidak didaftarkan, browser memblokirnya.
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization")
		c.Header("Access-Control-Max-Age", "86400")

		// Browser mengirim OPTIONS lebih dulu ("preflight") untuk
		// menanyakan izin, sebelum mengirim permintaan sebenarnya.
		// Pertanyaan itu harus dijawab lalu dihentikan di sini.
		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		// Lanjut ke handler tujuan.
		c.Next()
	}
}
