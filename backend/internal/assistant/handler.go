package assistant

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

func (h *Handler) Handle(c *gin.Context) {
	var req AskRequest
	if err := c.ShouldBindJSON(&req); err != nil || strings.TrimSpace(req.Question) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Pertanyaan wajib diisi."})
		return
	}
	answer, err := h.Ask(c.Request.Context(), req)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"success": false, "message": "Maaf, informasi cuaca sedang tidak tersedia. Silakan coba lagi."})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": answer})
}
