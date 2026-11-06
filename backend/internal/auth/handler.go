package auth

import (
	"errors"
	"log"
	"net/http"

	"alice-backend/internal/shared/response"

	"github.com/gin-gonic/gin"
)

// Handler menerjemahkan bahasa HTTP menjadi panggilan ke Service.
//
// Dia sengaja TIDAK berisi aturan bisnis sama sekali. Tugasnya hanya tiga:
//  1. membaca badan permintaan
//  2. memanggil service
//  3. memilih kode status yang pantas, lalu menyusun balasan
//
// Kalau di sini kamu menemukan pemeriksaan seperti "password minimal 6
// karakter", berarti ada yang salah tempat — itu tugasnya service.
type Handler struct {
	svc *Service
}

// NewHandler adalah constructor.
//
// Dia menerima *Service, bukan membuatnya sendiri. Artinya Handler tidak
// tahu bagaimana Service dirakit, dan tidak peduli. Penyambungannya
// dilakukan sekali di internal/server/routes.go.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// Register melayani `POST /api/auth/register`.
func (h *Handler) Register(c *gin.Context) {
	var req RegisterRequest

	// ShouldBindJSON membaca badan permintaan dan mengisinya ke struct.
	//
	// Tanda `&` (alamat) dipakai karena fungsi ini perlu MENGISI struct
	// yang kita sediakan. Kalau dikirim tanpa `&`, Go mengirim salinannya,
	// dan struct asli kita tetap kosong.
	//
	// Awalannya "Should" berarti: kalau gagal, cukup kembalikan error.
	// Ada juga versi "Must" yang langsung membalas 400 sendiri — kita
	// tidak memakainya supaya bentuk balasan tetap seragam di tangan kita.
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.Fail("format JSON tidak valid"))
		return
	}

	res, err := h.svc.Register(c.Request.Context(), RegisterInput{
		Name:        req.Name,
		Email:       req.Email,
		Password:    req.Password,
		Role:        req.Role,
		PhoneNumber: req.PhoneNumber,
		Address:     req.Address,
	})
	if err != nil {
		writeError(c, err)
		return
	}

	// Keluarkan email dari pointer-nya dengan aman.
	// Field Email bertipe *string karena boleh NULL di database, sedangkan
	// UserResponse.Email bertipe string biasa. Membaca *u.Email pada
	// pointer yang nil akan membuat aplikasi panic, jadi diperiksa dulu.
	email := ""
	if res.User.Email != nil {
		email = *res.User.Email
	}

	// 201 Created, bukan 200 OK. Artinya: "permintaanmu berhasil DAN
	// sebuah data baru lahir karenanya." Ini beda makna yang berguna
	// bagi klien dan bagi alat pemantau.
	c.JSON(http.StatusCreated, response.OK("registrasi berhasil", RegisterResponse{
		User: UserResponse{
			UserID:      res.User.UserID,
			Name:        res.User.Name,
			Email:       email,
			Role:        res.User.Role,
			PhoneNumber: res.User.PhoneNumber,
			Address:     res.User.Address,
		},
		Token:     res.Token,
		ExpiredAt: res.ExpiredAt,
	}))
}

// Login melayani `POST /api/auth/login`.
func (h *Handler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.Fail("format JSON tidak valid"))
		return
	}

	res, err := h.svc.Login(c.Request.Context(), LoginInput{
		Email:    req.Email,
		Password: req.Password,
	})
	if err != nil {
		writeError(c, err)
		return
	}

	email := ""
	if res.User.Email != nil {
		email = *res.User.Email
	}

	c.JSON(http.StatusOK, response.OK("login berhasil", LoginResponse{
		User: UserResponse{
			UserID:      res.User.UserID,
			Name:        res.User.Name,
			Email:       email,
			Role:        res.User.Role,
			PhoneNumber: res.User.PhoneNumber,
			Address:     res.User.Address,
		},
		Token:     res.Token,
		ExpiredAt: res.ExpiredAt,
	}))
}

// GoogleLogin melayani `POST /api/auth/google`.
func (h *Handler) GoogleLogin(c *gin.Context) {
	var req GoogleLoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.Fail("format JSON tidak valid"))
		return
	}

	res, err := h.svc.LoginWithGoogle(c.Request.Context(), req.IDToken, req.Role)
	if err != nil {
		writeError(c, err)
		return
	}

	email := ""
	if res.User.Email != nil {
		email = *res.User.Email
	}

	c.JSON(http.StatusOK, response.OK("login berhasil", LoginResponse{
		User: UserResponse{
			UserID:      res.User.UserID,
			Name:        res.User.Name,
			Email:       email,
			Role:        res.User.Role,
			PhoneNumber: res.User.PhoneNumber,
			Address:     res.User.Address,
		},
		Token:     res.Token,
		ExpiredAt: res.ExpiredAt,
	}))
}

// writeError memilih kode status HTTP yang pantas untuk tiap jenis error.
//
// Ini satu-satunya tempat di package ini yang tahu soal kode status.
// Kalau aturannya berubah, cukup diubah di sini.
//
// Peta keputusannya:
//
//	400 Bad Request  -> permintaan salah, dan pengguna BISA memperbaikinya
//	409 Conflict     -> permintaan benar, tapi bentrok dengan data yang ada
//	500 Server Error -> kesalahan di sisi kita, pengguna tidak bisa apa-apa
//
// Perbedaan 400 dan 409 sering diabaikan, padahal berguna: yang pertama
// berarti "perbaiki isianmu", yang kedua berarti "email ini sudah dipakai,
// coba yang lain atau langsung masuk".
func writeError(c *gin.Context, err error) {
	var ve *ValidationError

	switch {
	case errors.As(err, &ve):
		// errors.As (bukan errors.Is) dipakai karena yang dicari adalah
		// JENIS error, lalu kita perlu membaca isinya (pesannya).
		c.JSON(http.StatusBadRequest, response.Fail(ve.Message))

	case errors.Is(err, ErrEmailTaken):
		c.JSON(http.StatusConflict, response.Fail(err.Error()))

	case errors.Is(err, ErrInvalidCredentials):
		c.JSON(http.StatusUnauthorized, response.Fail(err.Error()))

	case errors.Is(err, ErrProviderMismatch):
		c.JSON(http.StatusConflict, response.Fail(err.Error()))

	default:
		// Kesalahan tak terduga: catat selengkapnya di log server, tapi
		// kirim pesan umum ke klien.
		//
		// Kenapa tidak mengirim err.Error() saja? Karena pesan itu bisa
		// berisi nama tabel, nama kolom, atau alamat database. Detail
		// seperti itu membantu penyerang memetakan sistem kita, dan tidak
		// berguna sama sekali bagi pengguna.
		log.Printf("[ERROR] register gagal: %v", err)
		c.JSON(http.StatusInternalServerError, response.Fail("terjadi kesalahan pada server"))
	}
}
