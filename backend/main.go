
package main

import (
	"encoding/json"
	"log"
	"net/http"
)

type InfoResponse struct {
	Message string `json:"message"`
	App     string `json:"app"`
}

func main() {
	http.HandleFunc("/api/hello", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		if r.Method != http.MethodGet {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(InfoResponse{
			Message: "Backend berhasil terhubung!",
			App:     "ALICE",
		})
	})

	log.Println("Server berjalan di http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
