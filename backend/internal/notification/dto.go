package notification

import "time"

// RegisterTokenRequest adalah isi badan permintaan POST /api/device-tokens.
//
// Token dikirim aplikasi Flutter setelah Firebase memberikannya. Platform
// dikirim terpisah karena backend perlu tahu harus memakai format payload
// APNs (iOS) atau Android.
type RegisterTokenRequest struct {
	Token    string `json:"token"`
	Platform string `json:"platform"`
}

// DeviceTokenResponse adalah bentuk aman data token yang dikirim balik.
//
// Token perangkat sendiri TIDAK dikembalikan. Klien sudah tahu tokennya;
// mengirimkannya balik hanya menambah jalan bocor lewat log.
type DeviceTokenResponse struct {
	TokenID  string    `json:"token_id"`
	Platform string    `json:"platform"`
	UploadAt time.Time `json:"upload_at"`
}
