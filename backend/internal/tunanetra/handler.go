package tunanetra

import (
	"log"
	"net/http"

	"alice-backend/internal/shared/response"
	"alice-backend/internal/user"

	"github.com/gin-gonic/gin"
)

// Handler menerjemahkan HTTP menjadi panggilan Service.
// Sama seperti handler lain: tidak ada aturan bisnis di sini.
type Handler struct {
	svc *Service
}

// NewHandler adalah constructor.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

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

// ListAccounts melayani `GET /api/tunanetra/accounts`.
//
// Berbeda dengan List di atas, endpoint ini mengembalikan akun tunanetra
// ASLI dari database untuk halaman "Tautkan Tunanetra". Karena endpointnya
// baru dan belum ada klien lama, balasannya memakai bentuk baku
// response.Response.
func (h *Handler) ListAccounts(c *gin.Context) {
	accounts, err := h.svc.ListAccounts(c.Request.Context())
	if err != nil {
		log.Printf("[ERROR] daftar tunanetra gagal: %v", err)
		c.JSON(http.StatusInternalServerError, response.Fail("terjadi kesalahan pada server"))
		return
	}

	// Hasil kosong dikirim sebagai array `[]`, bukan `null`, supaya
	// aplikasi tidak perlu menebak bentuknya.
	if accounts == nil {
		accounts = []user.Account{}
	}

	c.JSON(http.StatusOK, response.OK("daftar tunanetra berhasil diambil", accounts))
}
