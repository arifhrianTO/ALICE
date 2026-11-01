package auth

import "time"

// Berkas ini berisi BENTUK DATA yang melintasi jaringan (JSON).
//
// Kenapa dipisah dari struct model di model.go?
//
// Karena keduanya memang berbeda, dan menyatukannya berbahaya. Contoh
// nyata di fitur ini:
//
//	user.User.Password   -> berisi HASH bcrypt  (rahasia)
//	RegisterRequest.Password -> berisi password ASLI dari pengguna
//
// Namanya sama, artinya jauh berbeda. Kalau keduanya memakai satu struct
// yang sama, cepat atau lambat hash password akan ikut terkirim ke klien,
// atau password asli ikut tersimpan ke database. Dua-duanya serius.
//
// Istilah lain untuk berkas seperti ini: DTO (Data Transfer Object).
// Padanan Laravel: Form Request + API Resource.

// RegisterRequest adalah isi badan permintaan POST /api/auth/register.
//
// Tag `json:"..."` memberi tahu encoder JSON nama yang dipakai di jaringan.
// Nama field Go (huruf besar) tidak pernah terlihat oleh klien.
// Tanpa tag ini, Go akan memakai nama field apa adanya dan klien harus
// menulis "Name", "Email" — huruf besar semua, tidak lazim untuk JSON.
type RegisterRequest struct {
	Name        string `json:"name"`
	Email       string `json:"email"`
	Password    string `json:"password"`
	Role        string `json:"role"`
	PhoneNumber string `json:"phone_number"`
	Address     string `json:"address"`
}

// UserResponse adalah data pengguna yang AMAN dikirim ke klien.
//
// Password tidak ada di daftar ini — dan itu disengaja, bukan kelalaian.
// Karena bentuknya struct terpisah, satu-satunya cara password bisa bocor
// adalah kalau ada yang menambahkannya ke sini dengan sadar. Jauh lebih
// aman daripada menyerahkan struct User mentah-mentah lalu berharap tag
// `json:"-"` tidak pernah terhapus.
type UserResponse struct {
	UserID string `json:"user_id"`
	Name   string `json:"name"`
	Email  string `json:"email"`
	Role   string `json:"role"`
}

// RegisterResponse adalah isi field `data` saat pendaftaran berhasil.
//
// Token ikut dikirim di sini karena tombol di aplikasi berbunyi
// "Daftar & Masuk": setelah mendaftar, pengguna langsung dianggap masuk
// dan tidak perlu mengetik ulang email beserta passwordnya.
type RegisterResponse struct {
	User      UserResponse `json:"user"`
	Token     string       `json:"token"`
	ExpiredAt time.Time    `json:"expired_at"`
}

// LoginRequest adalah isi badan permintaan POST /api/auth/login.
type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// LoginResponse bentuk balasan sama dengan register: kembalikan user + token.
type LoginResponse = RegisterResponse
