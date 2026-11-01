// Package validation menampung aturan pemeriksaan data yang dipakai
// lebih dari satu fitur.
//
// Kenapa tidak ditaruh di dalam auth/ atau profile/ saja? Karena dua fitur
// itu sama-sama perlu memeriksa nomor telepon dan alamat. Kalau aturannya
// ditulis dua kali, cepat atau lambat keduanya berbeda — dan pengguna
// mendapat aturan berbeda tergantung halaman yang sedang dibuka.
//
// Package ini hanya berisi logika teks murni: tidak tahu HTTP, tidak tahu
// database, dan tidak mengimport fitur mana pun.
package validation

import (
	"errors"
	"regexp"
	"strings"
)

// AddressMaxLength sama dengan panjang kolom public.companion.address
// (varchar(255)). Memeriksanya di sini membuat pesan errornya ramah,
// bukan error database yang membingungkan.
const AddressMaxLength = 255

// Pesan error di bawah ini sudah ramah-pengguna, karena akan diteruskan
// apa adanya ke aplikasi Flutter.
var (
	ErrPhoneRequired = errors.New("nomor telepon wajib diisi")
	ErrPhoneInvalid  = errors.New("format nomor telepon tidak valid")
	ErrAddressLong   = errors.New("alamat maksimal 255 karakter")
)

// phonePattern menerima nomor yang sudah dibersihkan: boleh diawali "+",
// lalu 9 sampai 15 digit. Cukup longgar untuk nomor Indonesia
// (08…, 628…, +628…) tanpa memaksa satu bentuk tertentu.
var phonePattern = regexp.MustCompile(`^\+?[0-9]{9,15}$`)

// NormalizePhone membersihkan nomor telepon dari spasi, tanda hubung,
// dan tanda kurung, lalu memeriksa bentuknya.
//
// Contoh yang diterima:
//
//	"0812-3456-789"   -> "08123456789"
//	"+62 812 3456 789" -> "+628123456789"
func NormalizePhone(raw string) (string, error) {
	if strings.TrimSpace(raw) == "" {
		return "", ErrPhoneRequired
	}

	cleaned := strings.Map(func(r rune) rune {
		switch {
		case r >= '0' && r <= '9':
			return r
		case r == '+':
			return r
		default:
			return -1 // buang karakter lain
		}
	}, raw)

	if cleaned == "" || !phonePattern.MatchString(cleaned) {
		return "", ErrPhoneInvalid
	}
	return cleaned, nil
}

// NormalizeAddress merapikan spasi di awal/akhir dan memastikan panjangnya
// tidak melebihi batas kolom database.
//
// Alamat boleh kosong: pendaftaran hanya mewajibkan nomor telepon.
func NormalizeAddress(raw string) (string, error) {
	address := strings.TrimSpace(raw)
	if len(address) > AddressMaxLength {
		return "", ErrAddressLong
	}
	return address, nil
}
