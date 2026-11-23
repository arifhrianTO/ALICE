package request

import (
	"context"
	"strings"

	"alice-backend/internal/user"
)

// ValidationError berarti isian tidak memenuhi aturan. Pesannya sudah
// ramah-pengguna dan diteruskan apa adanya ke aplikasi.
type ValidationError struct {
	Message string
}

func (e *ValidationError) Error() string { return e.Message }

func invalid(message string) error { return &ValidationError{Message: message} }

// Service adalah logika bisnis fitur pengajuan tautan.
//
// Ia tidak menulis SQL sendiri. Tabel `request` diakses lewat Repository,
// sedangkan pengecekan akun tunanetra memakai user.Repository karena
// tabel "user" milik fitur user.
type Service struct {
	repo  Repository
	users user.Repository
}

// NewService merakit Service dengan kedua repository di atas.
func NewService(repo Repository, users user.Repository) *Service {
	return &Service{repo: repo, users: users}
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

	return s.repo.Create(ctx, companionID, viID)
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
