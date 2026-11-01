// Package profile mengurus tampilan dan perubahan profil pengguna.
//
// Kenapa bukan bagian dari auth? Karena auth mengurus PROSES masuk,
// sedangkan profil mengurus DATA yang ditampilkan setelah masuk. Keduanya
// punya alasan hidup yang berbeda.
//
// Package ini tidak menulis SQL. Semua akses tabel tetap lewat
// user.Repository, karena tabel "user" dan "companion" milik fitur user.
package profile

import (
	"context"
	"errors"
	"strings"

	"alice-backend/internal/shared/validation"
	"alice-backend/internal/user"
)

// ValidationError berarti isian tidak memenuhi aturan. Pesannya sudah
// ramah-pengguna dan diteruskan apa adanya ke aplikasi.
type ValidationError struct {
	Message string
}

func (e *ValidationError) Error() string { return e.Message }

// ErrNotFound dikembalikan kalau user_id di token tidak punya baris
// di tabel "user". Ini seharusnya tidak terjadi pada token yang sah,
// tapi tetap ditangani supaya tidak menjadi panic.
var ErrNotFound = errors.New("profil tidak ditemukan")

func invalid(message string) error {
	return &ValidationError{Message: message}
}

// UpdateInput adalah data yang boleh diubah lewat halaman profil.
type UpdateInput struct {
	Name        string
	PhoneNumber string
	Address     string
}

// Service adalah logika bisnis fitur profil.
type Service struct {
	users user.Repository
}

// NewService merakit Service dengan repository pengguna.
func NewService(users user.Repository) *Service {
	return &Service{users: users}
}

// Get mengambil profil lengkap berdasarkan user_id dari token.
func (s *Service) Get(ctx context.Context, userID string) (*ProfileResponse, error) {
	p, err := s.users.FindProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	if p == nil {
		return nil, ErrNotFound
	}
	return toResponse(p), nil
}

// Update memvalidasi lalu menyimpan perubahan profil.
//
// Aturan telepon mengikuti pendaftaran: wajib untuk pendamping. Alamat
// tetap opsional. Untuk tunanetra, telepon & alamat diabaikan karena
// tabel profilnya tidak punya kolom itu.
func (s *Service) Update(ctx context.Context, userID string, in UpdateInput) (*ProfileResponse, error) {
	current, err := s.users.FindProfile(ctx, userID)
	if err != nil {
		return nil, err
	}
	if current == nil {
		return nil, ErrNotFound
	}

	name := strings.TrimSpace(in.Name)
	if name == "" {
		return nil, invalid("nama pengguna wajib diisi")
	}

	var phoneNumber, address *string
	if current.Role == user.RolePendamping {
		phone, err := validation.NormalizePhone(in.PhoneNumber)
		if err != nil {
			return nil, invalid(err.Error())
		}
		phoneNumber = &phone

		addr, err := validation.NormalizeAddress(in.Address)
		if err != nil {
			return nil, invalid(err.Error())
		}
		if addr != "" {
			address = &addr
		}
	}

	if err := s.users.UpdateProfile(ctx, userID, name, phoneNumber, address); err != nil {
		return nil, err
	}

	return s.Get(ctx, userID)
}

// toResponse mengubah struct database menjadi bentuk JSON yang aman.
//
// Field pointer (boleh NULL) diubah menjadi string kosong supaya
// aplikasi Flutter tidak perlu menangani null di setiap tempat.
func toResponse(p *user.Profile) *ProfileResponse {
	res := &ProfileResponse{
		UserID: p.UserID,
		Name:   p.Name,
		Role:   p.Role,
	}
	if p.Email != nil {
		res.Email = *p.Email
	}
	if p.PhoneNumber != nil {
		res.PhoneNumber = *p.PhoneNumber
	}
	if p.Address != nil {
		res.Address = *p.Address
	}
	return res
}
