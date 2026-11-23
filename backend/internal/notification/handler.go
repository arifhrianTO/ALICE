package notification

import (
	"errors"
	"log"
	"net/http"

	"alice-backend/internal/shared/response"

	"github.com/gin-gonic/gin"
)

// Handler menerjemahkan HTTP menjadi panggilan Service.
type Handler struct {
	svc *Service
}

// NewHandler adalah constructor.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterToken melayani `POST /api/device-tokens`.
//
// user_id diambil dari context yang sudah diisi middleware.Auth, BUKAN
// dari badan permintaan. Kalau diambil dari badan permintaan, siapa pun
// bisa mendaftarkan token perangkatnya atas nama akun orang lain.
func (h *Handler) RegisterToken(c *gin.Context) {
	var req RegisterTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.Fail("format JSON tidak valid"))
		return
	}

	saved, err := h.svc.RegisterToken(c.Request.Context(), c.GetString("user_id"), RegisterTokenInput{
		Token:    req.Token,
		Platform: req.Platform,
	})
	if err != nil {
		writeError(c, err)
		return
	}

	c.JSON(http.StatusOK, response.OK("token perangkat tersimpan", DeviceTokenResponse{
		TokenID:  saved.TokenID,
		Platform: saved.Platform,
		UploadAt: saved.UploadAt,
	}))
}

// DeleteToken melayani `DELETE /api/device-tokens`.
func (h *Handler) DeleteToken(c *gin.Context) {
	var req RegisterTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.Fail("format JSON tidak valid"))
		return
	}

	if err := h.svc.DeleteToken(c.Request.Context(), req.Token); err != nil {
		writeError(c, err)
		return
	}

	c.JSON(http.StatusOK, response.OK("token perangkat dihapus", nil))
}

// writeError memilih kode status HTTP yang pantas.
func writeError(c *gin.Context, err error) {
	var ve *ValidationError

	switch {
	case errors.As(err, &ve):
		c.JSON(http.StatusBadRequest, response.Fail(ve.Message))

	default:
		log.Printf("[ERROR] notifikasi gagal: %v", err)
		c.JSON(http.StatusInternalServerError, response.Fail("terjadi kesalahan pada server"))
	}
}
