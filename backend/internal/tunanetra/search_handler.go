package tunanetra

import (
	"log"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"alice-backend/internal/shared/response"
)

type SearchHandler struct {
	repo Repository
}

func NewSearchHandler(repo Repository) *SearchHandler {
	return &SearchHandler{repo: repo}
}

// GET /api/tunanetra/search?q=budi
func (h *SearchHandler) Search(c *gin.Context) {
	keyword := strings.TrimSpace(c.Query("q"))

	list, err := h.repo.Search(c.Request.Context(), keyword, 50)
	if err != nil {
		log.Printf("tunanetra search: %v", err)
		c.JSON(http.StatusInternalServerError, response.Fail("terjadi kesalahan pada server"))
		return
	}
	c.JSON(http.StatusOK, response.OK("daftar tunanetra berhasil diambil", list))
}