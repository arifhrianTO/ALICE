// Package database bertanggung jawab membuka dan menutup koneksi ke
// PostgreSQL, termasuk mengatur connection pool-nya.
//
// ATURAN: package ini TIDAK berisi query SQL. Semua query ada di package
// fitur yang memiliki tabelnya (misalnya `internal/user`, `internal/auth`).
package database

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Connect membuka connection pool ke PostgreSQL dan memastikan koneksinya
// benar-benar hidup (ping).
//
// Kenapa perlu ping: pgxpool itu malas (lazy). NewWithConfig tidak langsung
// menyambung, hanya menyiapkan wadah. Tanpa ping, server bisa "berhasil
// start" padahal database mati, dan baru ketahuan error saat pengguna
// pertama login.
func Connect(ctx context.Context, dsn string) (*pgxpool.Pool, error) {
	cfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return nil, fmt.Errorf("DSN tidak valid: %w", err)
	}

	cfg.MaxConns = 10               // maksimal 10 koneksi bersamaan
	cfg.MinConns = 2                // sisakan 2 koneksi selalu terbuka
	cfg.MaxConnLifetime = time.Hour // koneksi didaur ulang tiap 1 jam

	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("gagal membuat pool: %w", err)
	}

	// Ping dengan batas waktu, supaya tidak menggantung selamanya
	// kalau server database diam saja.
	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	if err := pool.Ping(pingCtx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("database tidak bisa dihubungi: %w", err)
	}

	return pool, nil
}
