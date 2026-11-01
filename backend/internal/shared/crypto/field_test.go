package crypto_test

import (
	"errors"
	"strings"
	"testing"

	"alice-backend/internal/shared/crypto"
)

func newTestCipher(t *testing.T) *crypto.Cipher {
	t.Helper()

	// Kunci tetap untuk pengujian; jangan dipakai di aplikasi sungguhan.
	key := []byte("0123456789abcdef0123456789abcdef")
	c, err := crypto.New(key)
	if err != nil {
		t.Fatalf("buat cipher: %v", err)
	}
	return c
}

func TestEncryptDecryptRoundTrip(t *testing.T) {
	c := newTestCipher(t)
	const aad = "user-1:phone_number"

	encrypted, err := c.Encrypt("08123456789", aad)
	if err != nil {
		t.Fatalf("enkripsi: %v", err)
	}
	if !strings.HasPrefix(encrypted, "v1:") {
		t.Fatalf("ciphertext tidak berawalan v1: %q", encrypted)
	}
	if strings.Contains(encrypted, "08123456789") {
		t.Fatal("ciphertext masih memuat plaintext")
	}

	decrypted, err := c.Decrypt(encrypted, aad)
	if err != nil {
		t.Fatalf("dekripsi: %v", err)
	}
	if decrypted != "08123456789" {
		t.Fatalf("hasil dekripsi = %q", decrypted)
	}
}

func TestEncryptDifferentNonce(t *testing.T) {
	c := newTestCipher(t)

	a, _ := c.Encrypt("sama", "aad")
	b, _ := c.Encrypt("sama", "aad")
	if a == b {
		t.Fatal("dua enkripsi dengan plaintext sama menghasilkan ciphertext identik")
	}
}

func TestDecryptWrongAAD(t *testing.T) {
	c := newTestCipher(t)

	encrypted, _ := c.Encrypt("rahasia", "user-1:phone_number")
	if _, err := c.Decrypt(encrypted, "user-2:phone_number"); !errors.Is(err, crypto.ErrDecrypt) {
		t.Fatalf("AAD salah harus ErrDecrypt, dapat %v", err)
	}
}

func TestDecryptTampered(t *testing.T) {
	c := newTestCipher(t)

	encrypted, _ := c.Encrypt("rahasia", "aad")
	// Ubah satu karakter base64 di bagian akhir.
	last := encrypted[len(encrypted)-1]
	replacement := byte('A')
	if last == 'A' {
		replacement = 'B'
	}
	tampered := encrypted[:len(encrypted)-1] + string(replacement)

	if _, err := c.Decrypt(tampered, "aad"); !errors.Is(err, crypto.ErrDecrypt) {
		t.Fatalf("data yang diubah harus ditolak, dapat %v", err)
	}
}

func TestDecryptWrongKey(t *testing.T) {
	c1 := newTestCipher(t)
	c2, err := crypto.New([]byte("abcdef0123456789abcdef0123456789"))
	if err != nil {
		t.Fatalf("buat cipher kedua: %v", err)
	}

	encrypted, _ := c1.Encrypt("rahasia", "aad")
	if _, err := c2.Decrypt(encrypted, "aad"); !errors.Is(err, crypto.ErrDecrypt) {
		t.Fatalf("kunci salah harus ErrDecrypt, dapat %v", err)
	}
}

func TestDecryptLegacyPlaintext(t *testing.T) {
	c := newTestCipher(t)

	// Data lama sebelum fitur enkripsi: tanpa awalan v1:.
	got, err := c.Decrypt("0895603662530", "aad")
	if err != nil {
		t.Fatalf("plaintext lama seharusnya diterima: %v", err)
	}
	if got != "0895603662530" {
		t.Fatalf("hasil = %q", got)
	}
}

func TestInvalidKeyLength(t *testing.T) {
	if _, err := crypto.New([]byte("terlalu-pendek")); !errors.Is(err, crypto.ErrInvalidKey) {
		t.Fatalf("kunci pendek harus ErrInvalidKey, dapat %v", err)
	}
}
