package monitoring

import (
	"errors"
	"log"
	"net/http"
	"regexp"
	"strings"

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

// GET /api/monitoring/:tunanetra_id
// Data pantauan terakhir seorang tunanetra: lokasi, alamat, baterai, suhu.
func (h *Handler) GetStatus(c *gin.Context) {
	tunanetraID := c.Param("tunanetra_id")
	if !uuidPattern.MatchString(tunanetraID) {
		c.JSON(http.StatusBadRequest, response.Fail("tunanetra_id tidak valid"))
		return
	}

	status, err := h.repo.GetStatus(c.Request.Context(), c.GetString("user_id"), tunanetraID)
	switch {
	case err == nil:
		c.JSON(http.StatusOK, response.OK("data pantauan berhasil diambil", status))
	case errors.Is(err, ErrNotFound):
		c.JSON(http.StatusNotFound, response.Fail("data tunanetra tidak ditemukan atau Anda belum terhubung"))
	default:
		log.Printf("monitoring get status: %v", err)
		c.JSON(http.StatusInternalServerError, response.Fail("terjadi kesalahan pada server"))
	}
}

type updateRequest struct {
	Latitude     *float64 `json:"latitude"`
	Longitude    *float64 `json:"longitude"`
	Address      *string  `json:"address"`
	BatteryLevel *int     `json:"battery_level"`
	Temperature  *float64 `json:"temperature"`
}

const maxAddressLen = 300

// PUT /api/monitoring/me
// Aplikasi tunanetra mengirim lokasi, baterai, dan/atau suhu miliknya.
// Semua isian opsional, tetapi latitude dan longitude harus berpasangan.
func (h *Handler) UpdateMyStatus(c *gin.Context) {
	var req updateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.Fail("data tidak valid"))
		return
	}

	if (req.Latitude == nil) != (req.Longitude == nil) {
		c.JSON(http.StatusBadRequest, response.Fail("latitude dan longitude harus dikirim bersamaan"))
		return
	}
	if req.Latitude != nil && (*req.Latitude < -90 || *req.Latitude > 90) {
		c.JSON(http.StatusBadRequest, response.Fail("latitude harus antara -90 dan 90"))
		return
	}
	if req.Longitude != nil && (*req.Longitude < -180 || *req.Longitude > 180) {
		c.JSON(http.StatusBadRequest, response.Fail("longitude harus antara -180 dan 180"))
		return
	}
	if req.BatteryLevel != nil && (*req.BatteryLevel < 0 || *req.BatteryLevel > 100) {
		c.JSON(http.StatusBadRequest, response.Fail("battery_level harus antara 0 dan 100"))
		return
	}
	if req.Temperature != nil && (*req.Temperature < -50 || *req.Temperature > 100) {
		c.JSON(http.StatusBadRequest, response.Fail("temperature harus antara -50 dan 100"))
		return
	}

	// Alamat kosong dianggap tidak dikirim.
	if req.Address != nil {
		a := strings.TrimSpace(*req.Address)
		if len([]rune(a)) > maxAddressLen {
			c.JSON(http.StatusBadRequest, response.Fail("alamat terlalu panjang"))
			return
		}
		if a == "" {
			req.Address = nil
		} else {
			req.Address = &a
		}
	}

	if req.Latitude == nil && req.BatteryLevel == nil && req.Temperature == nil && req.Address == nil {
		c.JSON(http.StatusBadRequest, response.Fail("tidak ada data yang dikirim"))
		return
	}

	err := h.repo.UpdateMyStatus(c.Request.Context(), c.GetString("user_id"), UpdateInput{
		Latitude:     req.Latitude,
		Longitude:    req.Longitude,
		Address:      req.Address,
		BatteryLevel: req.BatteryLevel,
		Temperature:  req.Temperature,
	})
	switch {
	case err == nil:
		c.JSON(http.StatusOK, response.OK("data pantauan tersimpan", nil))
	case errors.Is(err, ErrNotFound):
		c.JSON(http.StatusForbidden, response.Fail("hanya akun tunanetra yang dapat mengirim data ini"))
	default:
		log.Printf("monitoring update: %v", err)
		c.JSON(http.StatusInternalServerError, response.Fail("terjadi kesalahan pada server"))
	}
}