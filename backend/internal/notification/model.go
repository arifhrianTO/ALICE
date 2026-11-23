// Package notification mengurus pengiriman push notification ke perangkat
// pengguna lewat Firebase Cloud Messaging (FCM).
//
// Kepemilikan tabel "device_token" ada di sini: tabel itu hanya hidup
// karena ada fitur notifikasi. Kalau fitur ini dihapus, token perangkat
// tidak ada gunanya.
package notification

import "time"

// Platform adalah nilai enum "device_platform" di PostgreSQL.
const (
	PlatformAndroid = "android"
	PlatformIOS     = "ios"
)

// DeviceToken adalah satu baris tabel "device_token": alamat kirim push
// notification milik satu perangkat.
//
// Satu pengguna boleh punya banyak baris — misalnya HP Android dan iPad.
// Karena itu kunci utamanya token_id, bukan user_id.
type DeviceToken struct {
	TokenID  string    `json:"token_id"`
	UserID   string    `json:"user_id"`
	Token    string    `json:"token"`
	Platform string    `json:"platform"`
	UploadAt time.Time `json:"upload_at"`
}
