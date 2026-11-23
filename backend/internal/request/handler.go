package request

import (
	"errors"
	"log"
	"net/http"

	"alice-backend/internal/shared/response"

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

// List melayani `GET /api/requests`.
//
// Mengembalikan daftar pengajuan tautan milik pendamping yang sedang
// login, lengkap dengan statusnya. Inilah sumber data halaman "Terhubung".
func (h *Handler) List(c *gin.Context) {
	items, err := h.svc.List(c.Request.Context(), c.GetString("user_id"))
	if err != nil {
		writeError(c, err)
		return
	}

	c.JSON(http.StatusOK, response.OK("daftar pengajuan berhasil diambil", items))
}

// Create melayani `POST /api/requests`.
//
// Mengirim pengajuan tautan baru (berstatus "Menunggu") ke satu tunanetra.
func (h *Handler) Create(c *gin.Context) {
	var req CreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.Fail("format JSON tidak valid"))
		return
	}

	item, err := h.svc.Create(c.Request.Context(), c.GetString("user_id"), req.VisuallyImpairedID)
	if err != nil {
		writeError(c, err)
		return
	}

	c.JSON(http.StatusCreated, response.OK("pengajuan tautan berhasil dikirim", item))
}

// Delete melayani `DELETE /api/requests/:id`.
//
// Dipakai untuk membatalkan pengajuan ("Menunggu") sekaligus memutus
// tautan ("Terhubung").
func (h *Handler) Delete(c *gin.Context) {
	if err := h.svc.Delete(c.Request.Context(), c.GetString("user_id"), c.Param("id")); err != nil {
		writeError(c, err)
		return
	}

	c.JSON(http.StatusOK, response.OK("pengajuan tautan dihapus", nil))
}

// writeError memilih kode status HTTP yang pantas.
func writeError(c *gin.Context, err error) {
	var ve *ValidationError

	switch {
	case errors.As(err, &ve):
		c.JSON(http.StatusBadRequest, response.Fail(ve.Message))

	case errors.Is(err, ErrNotFound):
		c.JSON(http.StatusNotFound, response.Fail(err.Error()))

	default:
		log.Printf("[ERROR] pengajuan gagal: %v", err)
		c.JSON(http.StatusInternalServerError, response.Fail("terjadi kesalahan pada server"))
	}
}
