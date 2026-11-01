package profile

import (
	"errors"
	"log"
	"net/http"

	"alice-backend/internal/shared/response"

	"github.com/gin-gonic/gin"
)

// Handler menerjemahkan HTTP menjadi panggilan Service.
//
// Sama seperti handler lain: tidak ada aturan bisnis di sini.
type Handler struct {
	svc *Service
}

// NewHandler adalah constructor.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// Get melayani `GET /api/profile`.
//
// user_id diambil dari context yang sudah diisi middleware.Auth.
func (h *Handler) Get(c *gin.Context) {
	res, err := h.svc.Get(c.Request.Context(), c.GetString("user_id"))
	if err != nil {
		writeError(c, err)
		return
	}

	c.JSON(http.StatusOK, response.OK("profil berhasil diambil", res))
}

// Update melayani `PUT /api/profile`.
func (h *Handler) Update(c *gin.Context) {
	var req UpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.Fail("format JSON tidak valid"))
		return
	}

	res, err := h.svc.Update(c.Request.Context(), c.GetString("user_id"), UpdateInput{
		Name:        req.Name,
		PhoneNumber: req.PhoneNumber,
		Address:     req.Address,
	})
	if err != nil {
		writeError(c, err)
		return
	}

	c.JSON(http.StatusOK, response.OK("profil berhasil diperbarui", res))
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
		log.Printf("[ERROR] profil gagal: %v", err)
		c.JSON(http.StatusInternalServerError, response.Fail("terjadi kesalahan pada server"))
	}
}
