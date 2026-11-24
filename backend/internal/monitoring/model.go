package monitoring

// Status adalah data pantauan terakhir seorang tunanetra
// (tabel visually_impaired). Kolom yang belum pernah diisi bernilai null.
type Status struct {
	TunanetraID  string   `json:"tunanetra_id"`
	Latitude     *float64 `json:"latitude"`
	Longitude    *float64 `json:"longitude"`
	Address      *string  `json:"address"`
	BatteryLevel *int     `json:"battery_level"` // 0..100
	Temperature  *float64 `json:"temperature"`   // derajat Celsius
	LastSeenAt   *string  `json:"last_seen_at"`  // "YYYY-MM-DDTHH:MM:SS"
}

// UpdateInput adalah data yang dikirim aplikasi tunanetra tentang dirinya.
// Isian nil tidak mengubah nilai yang sudah ada.
// Latitude dan Longitude selalu dikirim berpasangan.
type UpdateInput struct {
	Latitude     *float64
	Longitude    *float64
	Address      *string
	BatteryLevel *int
	Temperature  *float64
}