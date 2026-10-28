package response

// File ini menentukan BENTUK BALASAN API.
//
// Padanan Laravel: `response()->json([...])`.
//
// Kenapa perlu diseragamkan? Karena kalau setiap handler menyusun JSON
// sendiri-sendiri, aplikasi Flutter harus menebak-nebak bentuk balasan
// di tiap endpoint. Dengan satu bentuk baku, pekerjaan di sisi aplikasi
// jadi jauh lebih sederhana.

// Response adalah bentuk baku balasan untuk endpoint BARU.
//
// Contoh hasil JSON:
//
//	{ "success": true,  "message": "berhasil", "data": { ... } }
//	{ "success": false, "message": "email sudah dipakai" }
//
// Field yang kosong tidak ikut dikirim, berkat `omitempty`.
type Response struct {
	Success bool   `json:"success"`
	Message string `json:"message,omitempty"`
	Data    any    `json:"data,omitempty"`
}

// OK membuat balasan berhasil.
func OK(message string, data any) Response {
	return Response{Success: true, Message: message, Data: data}
}

// Fail membuat balasan gagal. Dipakai untuk 4xx dan 5xx.
func Fail(message string) Response {
	return Response{Success: false, Message: message}
}

// InfoResponse adalah bentuk LAMA yang masih dipakai `GET /api/hello`.
//
// Sengaja TIDAK diubah menjadi `Response`, karena endpoint itu sudah
// dipakai. Aturan penting: jangan mengubah bentuk balasan yang sudah
// ada kliennya — nanti aplikasi yang sedang jalan ikut rusak.
type InfoResponse struct {
	Message string `json:"message"`
	App     string `json:"app"`
}
