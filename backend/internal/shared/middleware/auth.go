package middleware

import (
	"errors"
	"net/http"
	"strings"

	"alice-backend/internal/shared/response"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Auth memverifikasi token sesi dari header Authorization Bearer.
func Auth(db *pgxpool.Pool) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, response.Fail("token autentikasi tidak ditemukan"))
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, response.Fail("format Authorization harus Bearer <token>"))
			return
		}

		token := strings.TrimSpace(parts[1])
		if token == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, response.Fail("token tidak boleh kosong"))
			return
		}

		const query = `
			SELECT user_id
			FROM "session"
			WHERE session_token = $1 AND expired_at > CURRENT_TIMESTAMP`

		var userID string
		err := db.QueryRow(c.Request.Context(), query, token).Scan(&userID)
		if errors.Is(err, pgx.ErrNoRows) {
			c.AbortWithStatusJSON(http.StatusUnauthorized, response.Fail("sesi tidak valid atau sudah kedaluwarsa"))
			return
		}
		if err != nil {
			// Gangguan database bukan salah token; jangan dilaporkan 401.
			c.AbortWithStatusJSON(http.StatusInternalServerError, response.Fail("terjadi kesalahan pada server"))
			return
		}

		c.Set("user_id", userID)
		c.Next()
	}
}
