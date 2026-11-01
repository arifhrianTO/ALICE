package profile

// Berkas ini berisi bentuk data yang melintasi jaringan (JSON) untuk
// fitur profil.
//
// Sama seperti di auth/dto.go: struct ini SENGAJA dipisah dari struct
// database. Yang dikirim ke klien hanya field yang aman dan memang
// dibutuhkan halaman profil.

// ProfileResponse adalah isi field `data` pada GET/PUT /api/profile.
type ProfileResponse struct {
	UserID      string `json:"user_id"`
	Name        string `json:"name"`
	Email       string `json:"email"`
	Role        string `json:"role"`
	PhoneNumber string `json:"phone_number"`
	Address     string `json:"address"`
}

// UpdateRequest adalah badan permintaan PUT /api/profile.
//
// Email dan role tidak ada di sini dengan sengaja: keduanya bukan hal
// yang boleh diubah lewat halaman profil.
type UpdateRequest struct {
	Name        string `json:"name"`
	PhoneNumber string `json:"phone_number"`
	Address     string `json:"address"`
}
