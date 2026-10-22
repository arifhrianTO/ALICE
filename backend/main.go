
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

type Tunanetra struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Email       string  `json:"email"`
	Latitude    float64 `json:"latitude"`
	Longitude   float64 `json:"longitude"`
	Address     string  `json:"address"`
	Battery     string  `json:"battery"`
	Temperature string  `json:"temperature"`
}

var dummyTunanetra = []Tunanetra{
	{
		ID:          "tn-1",
		Name:        "Budi Santoso",
		Email:       "BudiSantoso@gmail.com",
		Latitude:    1.1301,
		Longitude:   104.0529,
		Address:     "Jl. Ahmad Yani, Tlk. Tering, Kec. Batam Kota, Kota Batam, Kepulauan Riau 29461",
		Battery:     "89%",
		Temperature: "35°C",
	},
	{
		ID:          "tn-2",
		Name:        "Siti Rahma",
		Email:       "SitiRahma@gmail.com",
		Latitude:    1.1278,
		Longitude:   104.0535,
		Address:     "Engku Putri, Tlk. Tering, Kec. Batam Kota, Kota Batam, Kepulauan Riau 29464",
		Battery:     "94%",
		Temperature: "36°C",
	},
}

func enableCORS(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next(w, r)
	}
}

func main() {
	mux := http.NewServeMux()

	mux.HandleFunc("/api/hello", enableCORS(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(InfoResponse{
			Message: "Backend berhasil terhubung!",
			App:     "ALICE",
		})
	}))

	mux.HandleFunc("/api/tunanetra", enableCORS(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(dummyTunanetra)
	}))

	log.Println("Server berjalan di http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", mux))
}

