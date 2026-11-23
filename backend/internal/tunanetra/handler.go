package tunanetra

import (
	"log"
	"net/http"

	"alice-backend/internal/shared/response"
	"alice-backend/internal/user"

	"github.com/gin-gonic/gin"
)

// Handler menerjemahkan HTTP menjadi panggilan Service.
// Sama seperti handler lain: tidak ada aturan bisnis di sini.
type Handler struct {
	svc *Service
}

// NewHandler adalah constructor.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// ListAccounts melayani `GET /api/tunanetra/accounts`.
//
// Endpoint ini mengembalikan akun tunanetra ASLI dari database untuk halaman
// "Tautkan Tunanetra". Balasannya memakai bentuk baku response.Response.
func (h *Handler) ListAccounts(c *gin.Context) {
	accounts, err := h.svc.ListAccounts(c.Request.Context())
	if err != nil {
		log.Printf("[ERROR] daftar tunanetra gagal: %v", err)
		c.JSON(http.StatusInternalServerError, response.Fail("terjadi kesalahan pada server"))
		return
	}

	// Hasil kosong dikirim sebagai array `[]`, bukan `null`, supaya
	// aplikasi tidak perlu menebak bentuknya.
	if accounts == nil {
		accounts = []user.Account{}
	}

	c.JSON(http.StatusOK, response.OK("daftar tunanetra berhasil diambil", accounts))
}
