package connection

import (
	"errors"
	"log"
	"net/http"
	"regexp"

	"github.com/gin-gonic/gin"

	"alice-backend/internal/shared/response"
)

var uuidPattern = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

type Handler struct {
	repo Repository
}

func NewHandler(repo Repository) *Handler {
	return &Handler{repo: repo}
}

func serverError(c *gin.Context, where string, err error) {
	log.Printf("connection %s: %v", where, err)
	c.JSON(http.StatusInternalServerError, response.Fail("terjadi kesalahan pada server"))
}

// GET /api/connections
// Daftar koneksi milik pendamping yang sedang login (semua status).
func (h *Handler) List(c *gin.Context) {
	userID := c.GetString("user_id")

	items, err := h.repo.ListByCompanion(c.Request.Context(), userID)
	if err != nil {
		serverError(c, "list", err)
		return
	}
	c.JSON(http.StatusOK, response.OK("daftar koneksi berhasil diambil", items))
}

// GET /api/connections/incoming
// Permintaan masuk (status Menunggu) untuk tunanetra yang sedang login.
func (h *Handler) Incoming(c *gin.Context) {
	userID := c.GetString("user_id")

	items, err := h.repo.ListIncoming(c.Request.Context(), userID)
	if err != nil {
		serverError(c, "incoming", err)
		return
	}
	c.JSON(http.StatusOK, response.OK("permintaan masuk berhasil diambil", items))
}

type createRequest struct {
	TunanetraID string `json:"tunanetra_id" binding:"required"`
}

// POST /api/connections   body: {"tunanetra_id": "<user_id>"}
// Pendamping mengirim permintaan tautan ke tunanetra.
func (h *Handler) Create(c *gin.Context) {
	var req createRequest
	if err := c.ShouldBindJSON(&req); err != nil || !uuidPattern.MatchString(req.TunanetraID) {
		c.JSON(http.StatusBadRequest, response.Fail("tunanetra_id tidak valid"))
		return
	}

	err := h.repo.Create(c.Request.Context(), c.GetString("user_id"), req.TunanetraID)
	switch {
	case err == nil:
		c.JSON(http.StatusCreated, response.OK("permintaan tautan terkirim", nil))
	case errors.Is(err, ErrAlreadyRequested):
		c.JSON(http.StatusConflict, response.Fail("permintaan tautan sudah ada"))
	case errors.Is(err, ErrTargetNotFound):
		c.JSON(http.StatusNotFound, response.Fail("tunanetra tidak ditemukan"))
	default:
		serverError(c, "create", err)
	}
}

type respondRequest struct {
	Accept *bool `json:"accept" binding:"required"`
}

// PUT /api/connections/:id/respond   body: {"accept": true}
// Tunanetra menerima (true) atau menolak (false) permintaan.
func (h *Handler) Respond(c *gin.Context) {
	id := c.Param("id")
	var req respondRequest
	if !uuidPattern.MatchString(id) || c.ShouldBindJSON(&req) != nil || req.Accept == nil {
		c.JSON(http.StatusBadRequest, response.Fail("permintaan tidak valid"))
		return
	}

	err := h.repo.Respond(c.Request.Context(), id, c.GetString("user_id"), *req.Accept)
	switch {
	case err == nil:
		msg := "permintaan ditolak"
		if *req.Accept {
			msg = "permintaan diterima"
		}
		c.JSON(http.StatusOK, response.OK(msg, nil))
	case errors.Is(err, ErrRequestNotFound):
		c.JSON(http.StatusNotFound, response.Fail("permintaan tidak ditemukan"))
	default:
		serverError(c, "respond", err)
	}
}

// DELETE /api/connections/:id
// Memutus tautan (status Terhubung) atau membatalkan permintaan (Menunggu).
func (h *Handler) Delete(c *gin.Context) {
	id := c.Param("id")
	if !uuidPattern.MatchString(id) {
		c.JSON(http.StatusBadRequest, response.Fail("id tidak valid"))
		return
	}

	err := h.repo.Delete(c.Request.Context(), id, c.GetString("user_id"))
	switch {
	case err == nil:
		c.JSON(http.StatusOK, response.OK("tautan dihapus", nil))
	case errors.Is(err, ErrRequestNotFound):
		c.JSON(http.StatusNotFound, response.Fail("koneksi tidak ditemukan"))
	default:
		serverError(c, "delete", err)
	}
}
