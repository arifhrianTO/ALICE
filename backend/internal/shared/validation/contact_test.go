package validation_test

import (
	"errors"
	"strings"
	"testing"

	"alice-backend/internal/shared/validation"
)

func TestNormalizePhone(t *testing.T) {
	valid := []struct {
		raw  string
		want string
	}{
		{"08123456789", "08123456789"},
		{"0812-3456-789", "08123456789"},
		{"+62 812 3456 789", "+628123456789"},
		{"628123456789", "628123456789"},
	}

	for _, c := range valid {
		got, err := validation.NormalizePhone(c.raw)
		if err != nil {
			t.Errorf("NormalizePhone(%q) error: %v", c.raw, err)
			continue
		}
		if got != c.want {
			t.Errorf("NormalizePhone(%q) = %q, want %q", c.raw, got, c.want)
		}
	}

	invalid := []struct {
		raw  string
		want error
	}{
		{"", validation.ErrPhoneRequired},
		{"   ", validation.ErrPhoneRequired},
		{"abc", validation.ErrPhoneInvalid},
		{"0812", validation.ErrPhoneInvalid},
		{"+62++812", validation.ErrPhoneInvalid},
	}

	for _, c := range invalid {
		_, err := validation.NormalizePhone(c.raw)
		if !errors.Is(err, c.want) {
			t.Errorf("NormalizePhone(%q) error = %v, want %v", c.raw, err, c.want)
		}
	}
}

func TestNormalizeAddress(t *testing.T) {
	got, err := validation.NormalizeAddress("  Jl. Ahmad Yani  ")
	if err != nil {
		t.Fatalf("alamat valid ditolak: %v", err)
	}
	if got != "Jl. Ahmad Yani" {
		t.Errorf("NormalizeAddress = %q, want %q", got, "Jl. Ahmad Yani")
	}

	// Alamat boleh kosong.
	if got, err := validation.NormalizeAddress("   "); err != nil || got != "" {
		t.Errorf("alamat kosong = (%q, %v), want (\"\", nil)", got, err)
	}

	tooLong := strings.Repeat("a", validation.AddressMaxLength+1)
	if _, err := validation.NormalizeAddress(tooLong); !errors.Is(err, validation.ErrAddressLong) {
		t.Errorf("alamat kepanjangan error = %v, want %v", err, validation.ErrAddressLong)
	}
}
