package request

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"

	"alice-backend/internal/user"
)

// ValidationError berarti isian tidak memenuhi aturan. Pesannya sudah
// ramah-pengguna dan diteruskan apa adanya ke aplikasi.
type ValidationError struct {
	Message string
}

func (e *ValidationError) Error() string { return e.Message }

func invalid(message string) error { return &ValidationError{Message: message} }

// Notifier mengirim satu push notification ke semua perangkat milik satu
// pengguna.
//
// Dibuat sebagai interface supaya package request tidak perlu tahu soal FCM
// maupun tabel "device_token" — cukup tahu bahwa "seseorang bisa diberi
// tahu". notification.Service sudah memenuhi interface ini apa adanya.
type Notifier interface {
	NotifyUser(ctx context.Context, userID, title, body string, data map[string]string) error
}

// Service adalah logika bisnis fitur pengajuan tautan.
//
// Ia tidak menulis SQL sendiri. Tabel `request` diakses lewat Repository,
// sedangkan pengecekan akun tunanetra memakai user.Repository karena
// tabel "user" milik fitur user. notifier boleh nil (fitur notifikasi mati).
type Service struct {
	repo     Repository
	users    user.Repository
	notifier Notifier
}

// NewService merakit Service dengan kedua repository dan pengirim
// notifikasi di atas.
func NewService(repo Repository, users user.Repository, notifier Notifier) *Service {
	return &Service{repo: repo, users: users, notifier: notifier}
}

// List mengembalikan semua pengajuan milik pendamping yang sedang login.
//
// Hasil kosong dikembalikan sebagai slice kosong (bukan nil) supaya
// aplikasi selalu menerima array `[]`, tidak perlu menebak bentuknya.
func (s *Service) List(ctx context.Context, companionID string) ([]Request, error) {
	items, err := s.repo.ListByCompanion(ctx, companionID)
	if err != nil {
		return nil, err
	}
	if items == nil {
		items = []Request{}
	}
	return items, nil
}

// Create mengirim pengajuan tautan dari pendamping ke satu tunanetra.
//
// Sebelum menyimpan, dipastikan dulu bahwa target benar-benar ada dan
// berperan "tunanetra" — supaya pendamping tidak bisa menautkan ke akun
// pendamping lain atau ke dirinya sendiri.
func (s *Service) Create(ctx context.Context, companionID, visuallyImpairedID string) (*Request, error) {
	viID := strings.TrimSpace(visuallyImpairedID)
	switch {
	case viID == "":
		return nil, invalid("tunanetra wajib dipilih")
	case viID == companionID:
		return nil, invalid("tidak bisa menautkan ke akun sendiri")
	}

	target, err := s.users.FindProfile(ctx, viID)
	if err != nil {
		return nil, err
	}
	if target == nil || target.Role != user.RoleTunanetra {
		return nil, invalid("akun tunanetra tidak ditemukan")
	}

	created, err := s.repo.Create(ctx, companionID, viID)
	if err != nil {
		return nil, err
	}

	// Data sudah aman tersimpan. Pemberitahuan ke tunanetra dijalankan di
	// latar belakang supaya balasan ke pendamping tidak menunggu FCM.
	s.notifyNewRequest(ctx, companionID, viID, created.ID)

	return created, nil
}

// notifyNewRequest memberi tahu tunanetra bahwa ada pengajuan tautan baru.
//
// Dijalankan di goroutine terpisah dengan context TANPA pembatalan:
//   - pengajuan tidak ikut lambat/gagal kalau FCM bermasalah;
//   - context permintaan HTTP dibuang (WithoutCancel) supaya pengiriman
//     tetap jalan walau handler sudah selesai membalas ke aplikasi.
//
// Kegagalan pengiriman hanya dicatat ke log — data pengajuan tetap ada dan
// tunanetra tetap bisa melihatnya lewat pemeriksaan berkala di aplikasi.
func (s *Service) notifyNewRequest(ctx context.Context, companionID, tunanetraID, requestID string) {
	if s.notifier == nil {
		return
	}

	base := context.WithoutCancel(ctx)
	go func() {
		sendCtx, cancel := context.WithTimeout(base, 10*time.Second)
		defer cancel()

		body := fmt.Sprintf(
			"%s ingin menautkan akun dengan Anda.",
			s.companionName(sendCtx, companionID),
		)
		data := map[string]string{
			"type":       "connection_request",
			"request_id": requestID,
		}
		if err := s.notifier.NotifyUser(sendCtx, tunanetraID, "Permintaan Tautan Baru", body, data); err != nil {
			log.Printf("[permintaan] gagal mengirim notifikasi ke %s: %v", tunanetraID, err)
		}
	}()
}

// companionName mengambil nama pendamping pengaju. Kalau gagal atau kosong,
// dipakai sebutan umum supaya isi notifikasi tidak pernah kosong.
func (s *Service) companionName(ctx context.Context, companionID string) string {
	const fallback = "Seorang pendamping"
	if s.users == nil {
		return fallback
	}
	profile, err := s.users.FindProfile(ctx, companionID)
	if err != nil || profile == nil {
		return fallback
	}
	if name := strings.TrimSpace(profile.Name); name != "" {
		return name
	}
	return fallback
}

// Delete membuang satu pengajuan milik pendamping.
//
// Dipakai untuk DUA hal: membatalkan pengajuan yang masih "Menunggu",
// dan memutus tautan yang sudah "Terhubung". Keduanya sama-sama menghapus
// baris, karena statusnya melekat pada baris itu.
func (s *Service) Delete(ctx context.Context, companionID, requestID string) error {
	id := strings.TrimSpace(requestID)
	if id == "" {
		return invalid("pengajuan tidak valid")
	}
	return s.repo.Delete(ctx, companionID, id)
}

// ListIncoming mengembalikan pengajuan tautan yang masih "Menunggu" untuk
// tunanetra yang sedang login, lengkap dengan data pendamping pengaju.
//
// Hasil kosong dikembalikan sebagai slice kosong (bukan nil) supaya
// aplikasi selalu menerima array `[]`.
func (s *Service) ListIncoming(ctx context.Context, tunanetraID string) ([]IncomingRequest, error) {
	items, err := s.repo.ListIncoming(ctx, tunanetraID)
	if err != nil {
		return nil, err
	}
	if items == nil {
		items = []IncomingRequest{}
	}
	return items, nil
}

// Respond menjawab pengajuan tautan: true menjadi "Terhubung", false
// menjadi "Ditolak". Hanya pengajuan milik tunanetra tersebut dan yang
// masih "Menunggu" yang dapat dijawab.
func (s *Service) Respond(ctx context.Context, tunanetraID, requestID string, accept bool) error {
	id := strings.TrimSpace(requestID)
	if id == "" {
		return invalid("pengajuan tidak valid")
	}
	return s.repo.Respond(ctx, id, tunanetraID, accept)
}
