package request

import "time"

// Status pengajuan. Nilai ini HARUS sama persis dengan enum
// `request_status` di PostgreSQL. Salah satu huruf saja -> PostgreSQL
// menolak operasinya.
const (
	StatusMenunggu  = "Menunggu"
	StatusTerhubung = "Terhubung"
	StatusDitolak   = "Ditolak"
)

// Request adalah satu pengajuan tautan antara pendamping dan tunanetra.
//
// Struct ini BUKAN cerminan mentah tabel `request` saja: field Name, Email
// diambil dari tabel "user" lewat JOIN, karena halaman "Terhubung" perlu
// langsung menampilkan nama & email tunanetra tanpa query tambahan.
type Request struct {
	ID                 string     `json:"id"`
	VisuallyImpairedID string     `json:"visually_impaired_id"`
	Name               string     `json:"name"`
	Email              string     `json:"email"`
	Status             string     `json:"status"`
	RequestAt          time.Time  `json:"request_at"`
	RespondedAt        *time.Time `json:"responded_at,omitempty"`
}
