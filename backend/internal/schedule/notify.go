package schedule

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"
)

// Notifier mengirim satu push ke semua perangkat milik satu pengguna.
// notification.Service sudah memenuhi interface ini apa adanya.
type Notifier interface {
	NotifyUser(ctx context.Context, userID, title, body string, data map[string]string) error
}

// NotifyInfo adalah bahan untuk menyusun teks push sebuah pengajuan.
type NotifyInfo struct {
	TunanetraID   string
	CompanionName string
	Action        string
	Title         string
	RepeatType    string
	Time          string
	Day           string
	StartDate     string
}

var monthNames = [13]string{"", "Januari", "Februari", "Maret", "April", "Mei", "Juni",
	"Juli", "Agustus", "September", "Oktober", "November", "Desember"}

func speakDate(iso string) string {
	d, err := time.Parse(dateLayout, iso)
	if err != nil {
		return ""
	}
	return fmt.Sprintf("%d %s %d", d.Day(), monthNames[d.Month()], d.Year())
}

func describeRepeat(in *NotifyInfo) string {
	switch in.RepeatType {
	case RepeatDaily:
		return "setiap hari"
	case RepeatWeekly:
		if in.Day != "" {
			return "setiap hari " + in.Day
		}
		return "setiap minggu"
	default:
		if d := speakDate(in.StartDate); d != "" {
			return "sekali saja pada " + d
		}
		return "sekali saja"
	}
}

// buildNotifyBody menyusun isi push sesuai aksi pendamping.
func buildNotifyBody(in *NotifyInfo) string {
	name := strings.TrimSpace(in.CompanionName)
	if name == "" {
		name = "Seorang pendamping"
	}
	title := in.Title
	if title == "" {
		title = "tanpa judul"
	}
	clock := strings.Replace(in.Time, ":", ".", 1)

	switch in.Action {
	case ActionUbah:
		return fmt.Sprintf("%s ingin mengubah jadwal menjadi %s pukul %s, %s.",
			name, title, clock, describeRepeat(in))
	case ActionHapus:
		return fmt.Sprintf("%s ingin menghapus jadwal %s pukul %s, %s.",
			name, title, clock, describeRepeat(in))
	default:
		return fmt.Sprintf("%s ingin menambah jadwal %s pukul %s, %s.",
			name, title, clock, describeRepeat(in))
	}
}

// notifyNewRequest mengirim push di goroutine terpisah, tanpa pembatalan
// dari context HTTP. Kegagalan hanya dicatat: pengajuan sudah tersimpan.
func (h *Handler) notifyNewRequest(ctx context.Context, requestID string) {
	if h.notifier == nil {
		return
	}
	base := context.WithoutCancel(ctx)
	go func() {
		sendCtx, cancel := context.WithTimeout(base, 10*time.Second)
		defer cancel()

		info, err := h.repo.NotifyInfo(sendCtx, requestID)
		if err != nil {
			log.Printf("[jadwal] gagal menyusun notifikasi %s: %v", requestID, err)
			return
		}
		data := map[string]string{
			"type":       "schedule_request",
			"request_id": requestID,
		}
		if err := h.notifier.NotifyUser(sendCtx, info.TunanetraID,
			"Pengajuan Jadwal Baru", buildNotifyBody(info), data); err != nil {
			log.Printf("[jadwal] gagal mengirim notifikasi ke %s: %v", info.TunanetraID, err)
		}
	}()
}