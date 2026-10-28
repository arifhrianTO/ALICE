package tunanetra

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// List mengirim daftar tunanetra. Untuk sekarang datanya MASIH DUMMY
// (ditulis di `internal/tunanetra/data.go`), belum dari database.
//
// ⚠️ Bentuk balasannya sengaja TIDAK diubah menjadi `response.Response`.
// Aplikasi Flutter sudah memakainya dan membaca hasilnya sebagai array
// langsung:
//
//	final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
//
// Kalau dibungkus menjadi {"success": true, "data": [...]}, baris itu
// akan gagal dan halaman "tunanetra location" di aplikasi ikut rusak.
// Saat nanti data diambil dari database, bentuk luar array-nya dipertahankan.
func List(c *gin.Context) {
	c.JSON(http.StatusOK, DummyTunanetra)
}
