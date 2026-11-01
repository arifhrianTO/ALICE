package database

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// WithActor bungkus operasi dalam transaksi dan set app.current_user_id untuk trigger audit DB.
func WithActor(ctx context.Context, pool *pgxpool.Pool, actorID string, fn func(tx pgx.Tx) error) error {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if actorID != "" {
		if _, err := tx.Exec(ctx, "SELECT set_config('app.current_user_id', $1, true)", actorID); err != nil {
			return err
		}
	}

	if err := fn(tx); err != nil {
		return err
	}

	return tx.Commit(ctx)
}
