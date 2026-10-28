package auth

import "time"

// Berkas ini berisi cerminan tabel database yang dimiliki fitur auth.
//
// Kenapa tabel "session" ada di sini, bukan di package user?
// Karena kepemilikan ditentukan satu pertanyaan: "kalau fitur ini
// dihapus, apakah barang ini ikut terhapus?"
//
// Tabel "session" ada HANYA karena ada fitur login. Hapus fitur auth,
// tabel itu tidak ada gunanya. Jadi dia milik auth.
//
// Bandingkan dengan tabel "user": meski dipakai auth, dia hidup terus
// walau auth dihapus. Jadi dia milik package user.

// Session adalah satu baris tabel "session": satu sesi login di satu
// perangkat.
//
// Satu pengguna boleh punya banyak baris di sini — misalnya dia login di
// HP dan di laptop sekaligus. Karena itu session_id adalah kunci utama,
// sedangkan user_id hanya indeks biasa.
type Session struct {
	SessionID string `json:"session_id"`

	// UserID menunjuk ke tabel "user". Di database ini disebut FOREIGN KEY
	// dengan ON DELETE CASCADE, artinya kalau penggunanya dihapus, semua
	// sesinya ikut terhapus otomatis.
	UserID string `json:"user_id"`

	// SessionToken adalah "karcis" yang dipegang aplikasi. String inilah
	// yang dikirim aplikasi di setiap permintaan berikutnya untuk
	// membuktikan siapa dirinya.
	//
	// Tanda `json:"-"` berarti: JANGAN pernah ikut dikirim sebagai JSON.
	// Kita mengirim token ini ke klien secara sengaja dan lewat jalur
	// khusus (lihat RegisterResponse), bukan dengan menyiarkan seluruh
	// struct Session.
	SessionToken string `json:"-"`

	// RequestAt diisi sendiri oleh database (default CURRENT_TIMESTAMP).
	RequestAt time.Time `json:"request_at"`

	// ExpiredAt adalah batas waktu berlakunya token. Lewat dari waktu ini,
	// token tidak boleh dipakai lagi.
	ExpiredAt time.Time `json:"expired_at"`
}

// IsExpired menjawab apakah sesi sudah lewat batas waktunya.
//
// Dipakai nanti saat fitur login dan "cek sesi" diimplementasikan.
func (s *Session) IsExpired() bool {
	return time.Now().After(s.ExpiredAt)
}
