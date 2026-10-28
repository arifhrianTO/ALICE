package system

import (
	"net/http"

	"alice-backend/internal/shared/response"

	"github.com/gin-gonic/gin"
)

// Hello adalah uji cepat: kalau ini menjawab, server hidup.
//
// Perhatikan: pengecekan method (`if r.Method != GET`) yang dulu ada
// sekarang HILANG. Itu bukan kelalaian. Di Gin, method ditentukan saat
// pendaftaran route:
//
//	api.GET("/hello", system.Hello)
//
// Artinya `POST /api/hello` otomatis ditolak router (405 Method Not
// Allowed), sebelum handler ini dipanggil. Jadi pengecekan manual tidak
// diperlukan lagi.
func Hello(c *gin.Context) {
	c.JSON(http.StatusOK, response.InfoResponse{
		Message: "Backend berhasil terhubung!",
		App:     "ALICE",
	})
}
