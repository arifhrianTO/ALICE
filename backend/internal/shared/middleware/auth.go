package middleware

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
)

// ErrNotImplemented dikembalikan oleh fungsi kerangka di package ini.
var ErrNotImplemented = errors.New("middleware: belum diimplementasikan")

// Auth adalah satpam untuk endpoint yang butuh login.
//
// Padanan Laravel: middleware `auth:sanctum`.
//
// Status: KERANGKA (M2). Belum dipakai di `routes.go`.
//
// Rencana cara kerjanya:
//
//  1. Ambil header:      Authorization: Bearer a1b2c3d4...
//  2. Pisahkan kata "Bearer" dari tokennya.
//  3. Cari token itu di tabel `session` yang belum kedaluwarsa.
//  4. Kalau tidak ada / kedaluwarsa -> tolak dengan 401.
//  5. Kalau ada -> simpan user_id ke context, lalu lanjutkan:
//     c.Set("user_id", session.UserID)
//     c.Next()
//
// Kenapa token disimpan di tabel `session`, bukan JWT?
// Karena token di database bisa DICABUT seketika (logout, akun diblokir).
// JWT tidak bisa dicabut tanpa daftar hitam tambahan.
func Auth() gin.HandlerFunc {
	return func(c *gin.Context) {
		// TODO (M2): ganti isi fungsi ini dengan langkah 1-5 di atas.
		//
		// Sementara ini selalu menolak, supaya tidak ada endpoint yang
		// tanpa sengaja dianggap "sudah terlindungi" padahal belum.
		c.AbortWithStatusJSON(http.StatusNotImplemented, gin.H{
			"success": false,
			"message": "middleware auth belum diimplementasikan",
		})
	}
}
