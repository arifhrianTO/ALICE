package request

// CreateRequest adalah isi badan permintaan `POST /api/requests`.
//
// Pendamping yang mengirim diambil dari token (middleware.Auth), BUKAN
// dari badan permintaan — supaya seseorang tidak bisa mengirim pengajuan
// atas nama akun pendamping lain.
type CreateRequest struct {
	VisuallyImpairedID string `json:"visually_impaired_id"`
}
