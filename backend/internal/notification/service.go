package notification

import (
	"context"
	"errors"
	"fmt"
	"log"
	"strings"
)

// ValidationError berarti isian tidak memenuhi aturan. Pesannya sudah
// ramah-pengguna dan diteruskan apa adanya ke aplikasi.
type ValidationError struct {
	Message string
}

func (e *ValidationError) Error() string { return e.Message }

func invalid(message string) error { return &ValidationError{Message: message} }

// maxTokenLength sama dengan lebar kolom "token" di database
// (VARCHAR(255)). Diperiksa di sini supaya pengguna mendapat pesan yang
// jelas, bukan error database yang membingungkan.
const maxTokenLength = 255

// Service adalah logika bisnis notifikasi.
//
// sender boleh nil. Artinya fitur pengiriman sedang dimatikan (misalnya
// kredensial Firebase belum dipasang), tetapi pendaftaran token tetap
// berjalan supaya aplikasi tidak error.
type Service struct {
	repo   Repository
	sender Sender
}

// NewService merakit Service.
func NewService(repo Repository, sender Sender) *Service {
	return &Service{repo: repo, sender: sender}
}

// RegisterTokenInput adalah data pendaftaran token perangkat.
type RegisterTokenInput struct {
	Token    string
	Platform string
}

// RegisterToken menyimpan token perangkat milik pengguna yang sedang login.
//
// Token yang sama boleh dikirim berkali-kali (setiap aplikasi dibuka).
// Upsert membuat baris lama diperbarui, bukan menumpuk duplikat.
func (s *Service) RegisterToken(ctx context.Context, userID string, in RegisterTokenInput) (*DeviceToken, error) {
	token := strings.TrimSpace(in.Token)
	platform := strings.ToLower(strings.TrimSpace(in.Platform))

	switch {
	case userID == "":
		return nil, errors.New("user_id kosong")
	case token == "":
		return nil, invalid("token perangkat wajib diisi")
	case len(token) > maxTokenLength:
		return nil, invalid(fmt.Sprintf("token perangkat maksimal %d karakter", maxTokenLength))
	case platform != PlatformAndroid && platform != PlatformIOS:
		return nil, invalid(`platform harus "android" atau "ios"`)
	}

	return s.repo.Upsert(ctx, userID, token, platform)
}

// DeleteToken membuang satu token perangkat.
//
// Dipanggil saat pengguna logout supaya perangkat yang sama tidak lagi
// menerima notifikasi atas nama akun yang sudah keluar.
func (s *Service) DeleteToken(ctx context.Context, token string) error {
	token = strings.TrimSpace(token)
	if token == "" {
		return invalid("token perangkat wajib diisi")
	}
	return s.repo.Delete(ctx, token)
}

// NotifyUser mengirim notifikasi ke SEMUA perangkat milik satu pengguna.
//
// Kalau pengiriman ke salah satu perangkat gagal, perangkat lain tetap
// dicoba. Token yang dinyatakan mati oleh FCM langsung dihapus dari
// database agar tidak dicoba lagi di masa depan.
func (s *Service) NotifyUser(ctx context.Context, userID, title, body string, data map[string]string) error {
	if s.sender == nil {
		log.Printf("[notifikasi] pengirim belum aktif, pesan untuk %s dilewati", userID)
		return nil
	}

	tokens, err := s.repo.ListByUser(ctx, userID)
	if err != nil {
		return err
	}

	var failures []error
	for _, t := range tokens {
		if err := s.sender.Send(ctx, t.Token, title, body, data); err != nil {
			if IsUnregistered(err) {
				log.Printf("[notifikasi] token mati dihapus: %s", t.TokenID)
				_ = s.repo.Delete(ctx, t.Token)
				continue
			}
			failures = append(failures, fmt.Errorf("token %s: %w", t.TokenID, err))
		}
	}

	return errors.Join(failures...)
}
