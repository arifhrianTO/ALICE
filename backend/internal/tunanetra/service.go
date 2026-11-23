package tunanetra

import (
	"context"

	"alice-backend/internal/user"
)

// Service adalah logika bisnis fitur tunanetra.
//
// Ia sengaja tidak menulis SQL sendiri. Semua akses ke tabel "user"
// tetap lewat user.Repository, karena tabel itu milik fitur user.
// Padanan pola ini sudah dipakai fitur profile.
type Service struct {
	users user.Repository
}

// NewService merakit Service dengan repository pengguna.
func NewService(users user.Repository) *Service {
	return &Service{users: users}
}

// ListAccounts mengembalikan daftar akun pengguna tunanetra yang
// benar-benar terdaftar di aplikasi, diurutkan menurut nama.
//
// Hanya peran "tunanetra" yang diambil; pendamping tidak ikut.
func (s *Service) ListAccounts(ctx context.Context) ([]user.Account, error) {
	return s.users.ListAccountsByRole(ctx, user.RoleTunanetra)
}
