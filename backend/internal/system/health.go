package system

import (
	"context"
	"net/http"
	"time"

	"alice-backend/internal/shared/response"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// HealthHandler melayani `GET /api/health`.
//
// Bedanya dengan `/api/hello`: endpoint ini benar-benar MENYENTUH database.
// Kalau database mati, dia menjawab 503 (Service Unavailable), bukan 200.
// Jadi hasilnya bisa dipercaya oleh pemantau (monitoring) atau load balancer.
type HealthHandler struct {
	db *pgxpool.Pool
}

// NewHealthHandler adalah constructor.
//
// Kenapa tidak langsung memakai variabel global? Supaya bisa diuji: saat
// menulis test, kita bisa menyuntikkan database tiruan. Ini pola yang sama
// dengan "dependency injection" di Laravel.
func NewHealthHandler(db *pgxpool.Pool) *HealthHandler {
	return &HealthHandler{db: db}
}

// Check menjawab status server + database.
func (h *HealthHandler) Check(c *gin.Context) {
	// Batas waktu 3 detik. Tanpa ini, kalau database menggantung,
	// permintaan ikut menggantung dan menumpuk.
	//
	// `c.Request.Context()` ikut batal kalau pengguna menutup koneksi,
	// jadi pekerjaan yang sia-sia langsung berhenti.
	ctx, cancel := context.WithTimeout(c.Request.Context(), 3*time.Second)
	defer cancel()

	if err := h.db.Ping(ctx); err != nil {
		c.JSON(http.StatusServiceUnavailable, response.Fail("database tidak bisa dihubungi"))
		return
	}

	c.JSON(http.StatusOK, response.OK("server dan database sehat", gin.H{
		"status":   "ok",
		"database": "connected",
	}))
}
