// Package connection mengurus tautan antara pendamping dan tunanetra.
//
// Datanya disimpan di tabel public.request:
//
//	pendamping mengirim permintaan  -> status "Menunggu"
//	tunanetra menerima              -> status "Terhubung"
//	tunanetra menolak               -> status "Ditolak"
//
// ATURAN: SQL tabel request hanya ditulis di repository.go.
package connection

import "time"

// Nilai ini HARUS sama persis dengan enum request_status di PostgreSQL.
const (
	StatusMenunggu  = "Menunggu"
	StatusTerhubung = "Terhubung"
	StatusDitolak   = "Ditolak"
)

// Item adalah satu baris daftar koneksi.
//
// Untuk pendamping, Name/Email/UserID adalah data TUNANETRA.
// Untuk tunanetra (permintaan masuk), Name/Email/UserID adalah data PENDAMPING.
type Item struct {
	ID          string    `json:"id"` // request_id, dipakai untuk respond & hapus
	UserID      string    `json:"user_id"`
	Name        string    `json:"name"`
	Email       string    `json:"email"`
	Status      string    `json:"status"`
	RequestedAt time.Time `json:"requested_at"`
}