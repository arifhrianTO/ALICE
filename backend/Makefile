# Makefile -- pengganti `php artisan` di Laravel.
#
# Cara pakai:
#   make            -> tampilkan daftar semua perintah
#   make run        -> jalankan server
#   make seed       -> isi database dengan data uji
#
# PENTING: setiap baris perintah WAJIB diawali TAB, bukan spasi.
# Kalau pakai spasi, errornya "missing separator" dan membingungkan.

# Muat isi .env sebagai variabel. Tanda "-" di depan artinya
# "jangan berhenti kalau file .env belum ada".
-include .env
export

APP_NAME := alice-backend
BINARY   := bin/server

.DEFAULT_GOAL := help

.PHONY: help run build tidy fmt vet test check clean seed psql db-dump

# ---------------------------------------------------------------- bantuan

help: ## Tampilkan daftar perintah
	@echo "$(APP_NAME) -- daftar perintah:"
	@echo ""
	@grep -h -E '^[a-zA-Z_-]+:.*?## .*$$' $(firstword $(MAKEFILE_LIST)) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ---------------------------------------------------------------- harian

run: ## Jalankan server (development)
	go run ./cmd/server

build: ## Build binary ke bin/server
	go build -o $(BINARY) ./cmd/server

tidy: ## Rapikan daftar dependency di go.mod
	go mod tidy

fmt: ## Rapikan format semua file .go
	gofmt -w .

vet: ## Cari kesalahan mencurigakan di kode
	go vet ./...

test: ## Jalankan semua test
	go test ./...

check: fmt vet test ## Format + vet + test sekaligus

clean: ## Hapus hasil build
	rm -rf bin/

# ---------------------------------------------------------------- database

seed: ## Isi database dengan data uji
	go run ./cmd/seed

psql: ## Buka psql ke database (seperti `php artisan db`)
	psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d $(DB_NAME)

db-dump: ## Cetak skema database yang sedang terpasang
	pg_dump -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d $(DB_NAME) \
		--schema-only --no-owner --no-privileges
