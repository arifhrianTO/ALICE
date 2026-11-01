package audit

import (
	"context"
	"log"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Record tulis audit log semantik langsung ke tabel audit_logs.
// ponytail: query synchronous; ganti buffered channel/worker pool jika throughput tinggi.
func Record(ctx context.Context, pool *pgxpool.Pool, actor, action, table, objectID, result string) error {
	if pool == nil {
		return nil
	}
	const q = `
		INSERT INTO audit_logs (actor, action, object_table, object_id, result)
		VALUES ($1, $2, $3, $4, $5)`

	_, err := pool.Exec(ctx, q, actor, action, table, objectID, result)
	if err != nil {
		log.Printf("audit insert gagal: %v", err)
	}
	return err
}
