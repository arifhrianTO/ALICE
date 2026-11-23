package request

import (
	"errors"
	"log"
	"net/http"
	"regexp"

	"alice-backend/internal/shared/response"

	"github.com/gin-gonic/gin"
)

// uuidPattern dipakai untuk menolak lebih awal id yang jelas bukan UUID,
// supaya query database tidak perlu dijalankan untuk masukan yang salah.
var uuidPattern = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

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

// Incoming melayani `GET /api/requests/incoming`.
//
// Mengembalikan pengajuan tautan yang masih "Menunggu" untuk tunanetra
// yang sedang login — sumber data bagi sisi tunanetra untuk memutuskan
// menerima atau menolak.
func (h *Handler) Incoming(c *gin.Context) {
	items, err := h.svc.ListIncoming(c.Request.Context(), c.GetString("user_id"))
	if err != nil {
		writeError(c, err)
		return
	}

	c.JSON(http.StatusOK, response.OK("permintaan masuk berhasil diambil", items))
}

// respondRequest adalah isi badan `PUT /api/requests/:id/respond`.
//
// Accept memakai pointer supaya nilai `false` (menolak) tetap terbedakan
// dari "field tidak dikirim".
type respondRequest struct {
	Accept *bool `json:"accept" binding:"required"`
}

// Respond melayani `PUT /api/requests/:id/respond`.
//
// Tunanetra menerima (accept true) atau menolak (accept false) pengajuan.
func (h *Handler) Respond(c *gin.Context) {
	id := c.Param("id")
	var req respondRequest
	if !uuidPattern.MatchString(id) || c.ShouldBindJSON(&req) != nil || req.Accept == nil {
		c.JSON(http.StatusBadRequest, response.Fail("permintaan tidak valid"))
		return
	}

	if err := h.svc.Respond(c.Request.Context(), c.GetString("user_id"), id, *req.Accept); err != nil {
		writeError(c, err)
		return
	}

	msg := "permintaan ditolak"
	if *req.Accept {
		msg = "permintaan diterima"
	}
	c.JSON(http.StatusOK, response.OK(msg, nil))
}

// writeError memilih kode status HTTP yang pantas.
func writeError(c *gin.Context, err error) {
	var ve *ValidationError

	switch {
	case errors.As(err, &ve):
		c.JSON(http.StatusBadRequest, response.Fail(ve.Message))

	case errors.Is(err, ErrNotFound):
		c.JSON(http.StatusNotFound, response.Fail("pengajuan tidak ditemukan"))

	default:
		log.Printf("[ERROR] pengajuan gagal: %v", err)
		c.JSON(http.StatusInternalServerError, response.Fail("terjadi kesalahan pada server"))
	}
}
