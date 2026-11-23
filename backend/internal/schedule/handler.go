package schedule

import (
	"errors"
	"log"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"alice-backend/internal/shared/response"
)

var (
	uuidPattern = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)
	timePattern = regexp.MustCompile(`^([01][0-9]|2[0-3]):[0-5][0-9]$`)

	// Harus sama persis dengan enum di PostgreSQL.
	validActions = map[string]bool{ActionTambah: true, ActionUbah: true, ActionHapus: true}
	validRepeats = map[string]bool{RepeatNone: true, RepeatDaily: true, RepeatWeekly: true}
	validDays    = map[string]bool{"Senin": true, "Selasa": true, "Rabu": true, "Kamis": true, "Jumat": true, "Sabtu": true, "Minggu": true}

	// Urutan sesuai time.Weekday: Minggu = 0.
	dayNames = [7]string{"Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"}
)

const (
	maxTitleLen        = 100
	maxReminderMinutes = 1440 // 24 jam, aman untuk kolom smallint
	dateLayout         = "2006-01-02"
)

type Handler struct {
	repo Repository
}

func NewHandler(repo Repository) *Handler {
	return &Handler{repo: repo}
}

func serverError(c *gin.Context, where string, err error) {
	log.Printf("schedule %s: %v", where, err)
	c.JSON(http.StatusInternalServerError, response.Fail("terjadi kesalahan pada server"))
}

// GET /api/schedules?tunanetra_id=<user_id>
// Tanpa tunanetra_id, yang dipakai adalah user yang sedang login
// (berguna untuk aplikasi tunanetra).
func (h *Handler) ListSchedules(c *gin.Context) {
	userID := c.GetString("user_id")
	tunanetraID := strings.TrimSpace(c.Query("tunanetra_id"))
	if tunanetraID == "" {
		tunanetraID = userID
	} else if !uuidPattern.MatchString(tunanetraID) {
		c.JSON(http.StatusBadRequest, response.Fail("tunanetra_id tidak valid"))
		return
	}

	items, err := h.repo.ListSchedules(c.Request.Context(), userID, tunanetraID)
	if err != nil {
		serverError(c, "list schedules", err)
		return
	}
	c.JSON(http.StatusOK, response.OK("daftar jadwal berhasil diambil", items))
}

// GET /api/schedule-requests?tunanetra_id=<user_id>
// Riwayat pengajuan milik pendamping yang sedang login (semua status).
func (h *Handler) ListRequests(c *gin.Context) {
	var tunanetraID *string
	if q := strings.TrimSpace(c.Query("tunanetra_id")); q != "" {
		if !uuidPattern.MatchString(q) {
			c.JSON(http.StatusBadRequest, response.Fail("tunanetra_id tidak valid"))
			return
		}
		tunanetraID = &q
	}

	items, err := h.repo.ListRequests(c.Request.Context(), c.GetString("user_id"), tunanetraID)
	if err != nil {
		serverError(c, "list requests", err)
		return
	}
	c.JSON(http.StatusOK, response.OK("daftar pengajuan berhasil diambil", items))
}

// GET /api/schedule-requests/incoming
// Pengajuan yang menunggu jawaban tunanetra yang sedang login.
func (h *Handler) Incoming(c *gin.Context) {
	items, err := h.repo.ListIncoming(c.Request.Context(), c.GetString("user_id"))
	if err != nil {
		serverError(c, "incoming", err)
		return
	}
	c.JSON(http.StatusOK, response.OK("pengajuan masuk berhasil diambil", items))
}

type createRequest struct {
	TunanetraID     string  `json:"tunanetra_id" binding:"required"`
	Action          string  `json:"action" binding:"required"` // Tambah / Ubah / Hapus
	ScheduleID      *string `json:"schedule_id"`               // wajib untuk Ubah & Hapus
	Title           *string `json:"title"`
	RepeatType      *string `json:"repeat_type"`
	Time            *string `json:"time"`             // "HH:MM"
	Day             *string `json:"day"`              // boleh kosong kalau start_date diisi
	StartDate       *string `json:"start_date"`       // "YYYY-MM-DD"
	ReminderMinutes *int    `json:"reminder_minutes"` // 0..1440
}

// POST /api/schedule-requests
// Pendamping mengajukan tambah, ubah, atau hapus jadwal.
func (h *Handler) CreateRequest(c *gin.Context) {
	var req createRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.Fail("data pengajuan tidak lengkap"))
		return
	}

	if msg := validateCreate(&req); msg != "" {
		c.JSON(http.StatusBadRequest, response.Fail(msg))
		return
	}

	id, err := h.repo.CreateRequest(c.Request.Context(), CreateInput{
		CompanionID:     c.GetString("user_id"),
		TunanetraID:     req.TunanetraID,
		Action:          req.Action,
		ScheduleID:      req.ScheduleID,
		Title:           req.Title,
		RepeatType:      req.RepeatType,
		Time:            req.Time,
		Day:             req.Day,
		StartDate:       req.StartDate,
		ReminderMinutes: req.ReminderMinutes,
	})
	switch {
	case err == nil:
		c.JSON(http.StatusCreated, response.OK("pengajuan terkirim, menunggu persetujuan", gin.H{"id": id}))
	case errors.Is(err, ErrNotConnected):
		c.JSON(http.StatusForbidden, response.Fail("Anda belum terhubung dengan tunanetra ini"))
	case errors.Is(err, ErrScheduleNotFound):
		c.JSON(http.StatusNotFound, response.Fail("jadwal tidak ditemukan"))
	case errors.Is(err, ErrPendingExists):
		c.JSON(http.StatusConflict, response.Fail("jadwal ini masih punya pengajuan yang menunggu"))
	default:
		serverError(c, "create request", err)
	}
}

// validateCreate mengembalikan pesan error, atau "" kalau semuanya valid.
// Nilai kosong ("") dianggap tidak diisi. Fungsi ini juga melengkapi Day
// dari StartDate kalau Day tidak dikirim.
func validateCreate(req *createRequest) string {
	if !uuidPattern.MatchString(req.TunanetraID) {
		return "tunanetra_id tidak valid"
	}
	if !validActions[req.Action] {
		return "action harus Tambah, Ubah, atau Hapus"
	}

	req.Title = trimmedOrNil(req.Title)
	req.RepeatType = trimmedOrNil(req.RepeatType)
	req.Time = trimmedOrNil(req.Time)
	req.Day = trimmedOrNil(req.Day)
	req.StartDate = trimmedOrNil(req.StartDate)

	if req.Title != nil && len([]rune(*req.Title)) > maxTitleLen {
		return "judul maksimal 100 karakter"
	}
	if req.RepeatType != nil && !validRepeats[*req.RepeatType] {
		return "repeat_type tidak valid"
	}
	if req.Time != nil && !timePattern.MatchString(*req.Time) {
		return "time harus berformat HH:MM"
	}
	if req.Day != nil && !validDays[*req.Day] {
		return "day tidak valid"
	}
	if req.ReminderMinutes != nil && (*req.ReminderMinutes < 0 || *req.ReminderMinutes > maxReminderMinutes) {
		return "reminder_minutes harus antara 0 dan 1440"
	}

	if req.StartDate != nil {
		d, err := time.Parse(dateLayout, *req.StartDate)
		if err != nil {
			return "start_date harus berformat YYYY-MM-DD"
		}
		// Hari selalu mengikuti tanggal mulai supaya keduanya tidak bertentangan.
		day := dayNames[d.Weekday()]
		req.Day = &day
	}

	switch req.Action {
	case ActionTambah:
		if req.Title == nil {
			return "judul jadwal wajib diisi"
		}
		if req.Time == nil {
			return "jam jadwal wajib diisi"
		}
		if req.RepeatType != nil && *req.RepeatType == RepeatNone && req.StartDate == nil {
			return "tanggal wajib diisi untuk jadwal yang tidak berulang"
		}
		if req.RepeatType != nil && *req.RepeatType == RepeatWeekly && req.Day == nil {
			return "hari atau tanggal wajib diisi untuk jadwal mingguan"
		}
	case ActionUbah, ActionHapus:
		if req.ScheduleID == nil || !uuidPattern.MatchString(*req.ScheduleID) {
			return "schedule_id tidak valid"
		}
	}
	return ""
}

func trimmedOrNil(s *string) *string {
	if s == nil {
		return nil
	}
	t := strings.TrimSpace(*s)
	if t == "" {
		return nil
	}
	return &t
}

type respondRequest struct {
	Accept *bool `json:"accept" binding:"required"`
}

// PUT /api/schedule-requests/:id/respond   body: {"accept": true}
// Tunanetra menerima (true) atau menolak (false) pengajuan.
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
		msg := "pengajuan ditolak"
		if *req.Accept {
			msg = "pengajuan disetujui"
		}
		c.JSON(http.StatusOK, response.OK(msg, nil))
	case errors.Is(err, ErrRequestNotFound):
		c.JSON(http.StatusNotFound, response.Fail("pengajuan tidak ditemukan"))
	case errors.Is(err, ErrScheduleGone):
		c.JSON(http.StatusConflict, response.Fail("jadwal sudah tidak ada, pengajuan ditolak otomatis"))
	default:
		serverError(c, "respond", err)
	}
}

// DELETE /api/schedule-requests/:id
// Pendamping membatalkan pengajuan yang masih Menunggu.
func (h *Handler) CancelRequest(c *gin.Context) {
	id := c.Param("id")
	if !uuidPattern.MatchString(id) {
		c.JSON(http.StatusBadRequest, response.Fail("id tidak valid"))
		return
	}

	err := h.repo.CancelRequest(c.Request.Context(), id, c.GetString("user_id"))
	switch {
	case err == nil:
		c.JSON(http.StatusOK, response.OK("pengajuan dibatalkan", nil))
	case errors.Is(err, ErrRequestNotFound):
		c.JSON(http.StatusNotFound, response.Fail("pengajuan tidak ditemukan atau sudah dijawab"))
	default:
		serverError(c, "cancel request", err)
	}
}