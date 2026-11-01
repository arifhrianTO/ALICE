// Package crypto menangani enkripsi data sensitif di tingkat aplikasi.
//
// Kenapa di aplikasi, bukan di database? Karena tujuannya: kalau seseorang
// hanya memegang salinan database (dump/backup), dia TIDAK bisa membaca
// isinya. Kalau enkripsi dilakukan database, kuncinya juga harus ada di
// database — dan salinan itu ikut membawa kuncinya.
//
// Di sini kunci hanya hidup di environment aplikasi (PROFILE_ENCRYPTION_KEY).
// Database cuma menyimpan teks acak yang sudah terkunci.
//
// Algoritma: AES-256-GCM.
//   - AES-256  : enkripsi dengan kunci 32 byte.
//   - GCM      : sekaligus memberi jaminan keaslian (authenticated encryption),
//     jadi data yang diubah diam-diam akan ditolak saat dibuka.
package crypto

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"strings"
)

const (
	// KeySize adalah panjang kunci AES-256 dalam byte.
	KeySize = 32

	// nonceSize adalah panjang nonce GCM yang disarankan (12 byte).
	nonceSize = 12

	// versionPrefix menandai format ciphertext. Awalan ini penting untuk
	// dua hal: membedakan ciphertext dari data lama yang masih plaintext,
	// dan menyiapkan jalan untuk rotasi kunci di masa depan (v2: dst).
	versionPrefix = "v1:"
)

// Error yang bisa dikenali lapisan di atasnya.
var (
	ErrInvalidKey    = errors.New("kunci enkripsi harus 32 byte")
	ErrInvalidFormat = errors.New("format ciphertext tidak dikenal")
	ErrDecrypt       = errors.New("gagal mendekripsi data")
)

// Cipher adalah alat enkripsi/dekripsi yang siap dipakai.
//
// Struct ini aman dipakai bersamaan oleh banyak request: cipher.AEAD
// bersifat read-only setelah dibuat.
type Cipher struct {
	aead cipher.AEAD
}

// New membuat Cipher dari kunci mentah 32 byte.
func New(key []byte) (*Cipher, error) {
	if len(key) != KeySize {
		return nil, ErrInvalidKey
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("buat cipher AES: %w", err)
	}

	aead, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("buat mode GCM: %w", err)
	}

	return &Cipher{aead: aead}, nil
}

// NewFromBase64 membuat Cipher dari kunci berformat base64.
//
// Format ini dipilih karena nyaman disimpan di .env:
//
//	openssl rand -base64 32
func NewFromBase64(encoded string) (*Cipher, error) {
	key, err := base64.StdEncoding.DecodeString(strings.TrimSpace(encoded))
	if err != nil {
		return nil, fmt.Errorf("kunci bukan base64 yang valid: %w", err)
	}
	return New(key)
}

// Encrypt mengubah plaintext menjadi ciphertext berformat "v1:<base64>".
//
// aad (Additional Authenticated Data) adalah data yang TIDAK dirahasiakan,
// tapi ikut dihitung saat enkripsi. Kalau nilainya berbeda saat dekripsi,
// prosesnya gagal. Di fitur profil, aad berisi user_id + nama kolom, supaya
// ciphertext nomor telepon tidak bisa ditukar ke baris pengguna lain.
func (c *Cipher) Encrypt(plaintext, aad string) (string, error) {
	nonce := make([]byte, nonceSize)
	if _, err := rand.Read(nonce); err != nil {
		return "", fmt.Errorf("buat nonce acak: %w", err)
	}

	sealed := c.aead.Seal(nil, nonce, []byte(plaintext), []byte(aad))

	// Simpan nonce di depan ciphertext. Nonce tidak perlu dirahasiakan,
	// tapi harus unik untuk setiap enkripsi dengan kunci yang sama.
	payload := make([]byte, 0, nonceSize+len(sealed))
	payload = append(payload, nonce...)
	payload = append(payload, sealed...)

	return versionPrefix + base64.StdEncoding.EncodeToString(payload), nil
}

// IsEncrypted menjawab apakah sebuah nilai sudah berbentuk ciphertext
// keluaran Encrypt. Dipakai alat migrasi untuk melewati baris yang sudah
// terenkripsi, supaya perintahnya aman dijalankan berulang kali.
func IsEncrypted(value string) bool {
	return strings.HasPrefix(value, versionPrefix)
}

// Decrypt membuka ciphertext hasil Encrypt.
//
// Nilai yang TIDAK berawalan "v1:" dianggap data lama yang masih plaintext
// dan dikembalikan apa adanya. Ini penting supaya baris yang tersimpan
// sebelum fitur enkripsi dipasang tetap bisa dibaca. Begitu pemiliknya
// menyimpan ulang profil, nilainya akan berubah menjadi ciphertext.
func (c *Cipher) Decrypt(encoded, aad string) (string, error) {
	if !strings.HasPrefix(encoded, versionPrefix) {
		return encoded, nil
	}

	payload, err := base64.StdEncoding.DecodeString(
		strings.TrimPrefix(encoded, versionPrefix),
	)
	if err != nil {
		return "", ErrInvalidFormat
	}
	if len(payload) < nonceSize {
		return "", ErrInvalidFormat
	}

	nonce := payload[:nonceSize]
	ciphertext := payload[nonceSize:]

	plaintext, err := c.aead.Open(nil, nonce, ciphertext, []byte(aad))
	if err != nil {

		return "", ErrDecrypt
	}

	return string(plaintext), nil
}
