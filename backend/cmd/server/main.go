package main

import (
	"log"
	"net/http"

	"alice-backend/internal/handlers"
	"alice-backend/internal/middleware"
)

func main() {
	mux := http.NewServeMux()

	mux.HandleFunc("/api/hello", middleware.EnableCORS(handlers.HelloHandler))
	mux.HandleFunc("/api/tunanetra", middleware.EnableCORS(handlers.TunanetraHandler))

	log.Println("Server berjalan di http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", mux))
}
