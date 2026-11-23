// Package schedule mengurus jadwal tunanetra dan pengajuan perubahannya.
//
// Alurnya:
//
//	pendamping mengajukan Tambah / Ubah / Hapus
//	  -> tersimpan di schedule_request dengan status "Menunggu"
//	  -> tabel schedule BELUM berubah
//	tunanetra menerima
//	  -> perubahan diterapkan ke tabel schedule (dalam satu transaksi)
//	  -> status pengajuan menjadi "Disetujui"
//	tunanetra menolak
//	  -> tabel schedule tidak berubah, status pengajuan menjadi "Ditolak"
//
// ATURAN: SQL tabel schedule dan schedule_request hanya ditulis di repository.go.
package schedule

// Nilai ini HARUS sama persis dengan enum schedule_action di PostgreSQL.
const (
	ActionTambah = "Tambah"
	ActionUbah   = "Ubah"
	ActionHapus  = "Hapus"
)

// Nilai ini HARUS sama persis dengan enum submission_status di PostgreSQL.
const (
	StatusMenunggu  = "Menunggu"
	StatusDisetujui = "Disetujui"
	StatusDitolak   = "Ditolak"
)

// Nilai ini HARUS sama persis dengan enum repeat_type di PostgreSQL.
const (
	RepeatNone   = "Tidak berulang"
	RepeatDaily  = "Setiap hari"
	RepeatWeekly = "Setiap minggu"
)

// Schedule adalah satu jadwal yang sudah berlaku (tabel schedule).
type Schedule struct {
	ID              string  `json:"id"`
	TunanetraID     string  `json:"tunanetra_id"`
	Title           string  `json:"title"`
	RepeatType      string  `json:"repeat_type"`      // Tidak berulang / Setiap hari / Setiap minggu
	Time            string  `json:"time"`             // "HH:MM"
	Day             *string `json:"day"`              // Senin..Minggu, boleh null
	StartDate       *string `json:"start_date"`       // "YYYY-MM-DD", boleh null (data lama)
	ReminderMinutes int     `json:"reminder_minutes"` // default 10
}

// Request adalah satu pengajuan dari pendamping (tabel schedule_request).
//
// Title/RepeatType/Time/Day/StartDate/ReminderMinutes berisi isi jadwal
// SETELAH perubahan. Untuk aksi "Hapus", isinya salinan jadwal yang akan
// dihapus, supaya riwayatnya tetap terbaca walaupun jadwal aslinya sudah hilang.
type Request struct {
	ID              string  `json:"id"`
	TunanetraID     string  `json:"tunanetra_id"`
	TunanetraName   string  `json:"tunanetra_name"`
	CompanionID     string  `json:"companion_id"`
	CompanionName   string  `json:"companion_name"`
	ScheduleID      *string `json:"schedule_id"`
	Action          string  `json:"action"`
	Status          string  `json:"status"`
	Title           *string `json:"title"`
	RepeatType      *string `json:"repeat_type"`
	Time            *string `json:"time"`
	Day             *string `json:"day"`
	StartDate       *string `json:"start_date"`
	ReminderMinutes *int    `json:"reminder_minutes"`
}