package monitoring

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	// ErrNotFound: tunanetra tidak ada, atau pemanggil bukan dirinya sendiri
	// dan bukan pendamping yang berstatus "Terhubung".
	// Sengaja satu error agar tidak membocorkan apakah tunanetra itu ada.
	ErrNotFound = errors.New("monitoring: data tunanetra tidak ditemukan")
)

// Repository adalah kontrak akses data pantauan tunanetra.
type Repository interface {
	// GetStatus: data pantauan terakhir. Boleh dibaca oleh tunanetra itu
	// sendiri atau pendamping yang Terhubung dengannya.
	GetStatus(ctx context.Context, userID, tunanetraID string) (*Status, error)

	// UpdateMyStatus: aplikasi tunanetra mengirim lokasi, baterai, dan suhu
	// miliknya sendiri. last_seen_at diisi otomatis.
	UpdateMyStatus(ctx context.Context, userID string, in UpdateInput) error
}

type postgresRepository struct {
	pool *pgxpool.Pool
}

func NewRepository(pool *pgxpool.Pool) Repository {
	return &postgresRepository{pool: pool}
}

func (r *postgresRepository) GetStatus(ctx context.Context, userID, tunanetraID string) (*Status, error) {
	// Izin baca dicek di query yang sama: pemilik sendiri, atau pendamping
	// yang berstatus Terhubung di tabel request.
	const query = `
		SELECT v.user_id::text, v.latitude, v.longitude, v.address,
		       v.battery_level::int, v.temperature_c::float8,
		       to_char(v.last_seen_at, 'YYYY-MM-DD"T"HH24:MI:SS')
		FROM public.visually_impaired v
		WHERE v.user_id = $2::uuid
		  AND (
		      $1::uuid = $2::uuid
		      OR EXISTS (
		          SELECT 1 FROM public.request r
		          WHERE r.companion_id = $1::uuid
		            AND r.visually_impaired_id = $2::uuid
		            AND r.status = 'Terhubung'
		      )
		  )`

	var s Status
	err := r.pool.QueryRow(ctx, query, userID, tunanetraID).Scan(
		&s.TunanetraID, &s.Latitude, &s.Longitude, &s.Address,
		&s.BatteryLevel, &s.Temperature, &s.LastSeenAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("ambil data pantauan: %w", err)
	}
	return &s, nil
}

func (r *postgresRepository) UpdateMyStatus(ctx context.Context, userID string, in UpdateInput) error {
	// Alamat lama tidak berlaku lagi kalau koordinat berganti, jadi alamat
	// ikut diganti (atau dikosongkan) setiap kali koordinat dikirim.
	const query = `
		UPDATE public.visually_impaired
		SET latitude      = COALESCE($2::float8, latitude),
		    longitude     = COALESCE($3::float8, longitude),
		    address       = CASE WHEN $2::float8 IS NOT NULL THEN $4::text ELSE address END,
		    battery_level = COALESCE($5::smallint, battery_level),
		    temperature_c = COALESCE($6::numeric, temperature_c),
		    last_seen_at  = now()
		WHERE user_id = $1::uuid`

	tag, err := r.pool.Exec(ctx, query,
		userID, in.Latitude, in.Longitude, in.Address, in.BatteryLevel, in.Temperature,
	)
	if err != nil {
		return fmt.Errorf("simpan data pantauan: %w", err)
	}
	// Tidak ada baris: akun ini bukan tunanetra.
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}