package schedule

import (
	"context"
	"errors"
	"fmt"

	"alice-backend/internal/shared/database"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	// ErrNotConnected: pendamping belum berstatus "Terhubung" dengan tunanetra itu.
	ErrNotConnected = errors.New("schedule: pendamping belum terhubung dengan tunanetra")
	// ErrScheduleNotFound: jadwal yang mau diubah/dihapus tidak ada.
	ErrScheduleNotFound = errors.New("schedule: jadwal tidak ditemukan")
	// ErrPendingExists: jadwal itu sudah punya pengajuan yang masih menunggu.
	ErrPendingExists = errors.New("schedule: sudah ada pengajuan yang menunggu untuk jadwal ini")
	// ErrRequestNotFound: pengajuan tidak ada, bukan milik user ini, atau sudah dijawab.
	ErrRequestNotFound = errors.New("schedule: pengajuan tidak ditemukan")
	// ErrScheduleGone: saat disetujui, jadwal aslinya sudah tidak ada.
	// Pengajuannya otomatis ditandai "Ditolak".
	ErrScheduleGone = errors.New("schedule: jadwal sudah tidak ada")
)

// defaultReminderMinutes harus sama dengan DEFAULT kolom schedule.reminder_minutes.
const defaultReminderMinutes = 10

// CreateInput adalah bahan untuk membuat pengajuan.
// Title/RepeatType/Time/Day/StartDate/ReminderMinutes boleh nil; untuk "Ubah",
// yang nil dipertahankan dari jadwal lama.
type CreateInput struct {
	CompanionID     string
	TunanetraID     string
	Action          string
	ScheduleID      *string
	Title           *string
	RepeatType      *string
	Time            *string // "HH:MM"
	Day             *string
	StartDate       *string // "YYYY-MM-DD"
	ReminderMinutes *int
}

// Repository adalah kontrak akses tabel schedule dan schedule_request.
type Repository interface {
	// ListSchedules: jadwal yang berlaku milik seorang tunanetra.
	// Boleh dibaca oleh tunanetra itu sendiri atau pendamping yang Terhubung.
	ListSchedules(ctx context.Context, userID, tunanetraID string) ([]Schedule, error)

	// ListRequests: pengajuan milik pendamping (semua status).
	// tunanetraID nil = semua tunanetra yang terhubung.
	ListRequests(ctx context.Context, companionID string, tunanetraID *string) ([]Request, error)

	// ListIncoming: pengajuan yang menunggu jawaban seorang tunanetra.
	ListIncoming(ctx context.Context, tunanetraID string) ([]Request, error)

	// CreateRequest menyimpan pengajuan baru (status Menunggu) dan
	// mengembalikan id-nya.
	CreateRequest(ctx context.Context, in CreateInput) (string, error)

	// Respond: tunanetra menerima (true) atau menolak (false).
	// Kalau diterima, perubahan diterapkan ke tabel schedule.
	Respond(ctx context.Context, requestID, tunanetraID string, accept bool) error

	// CancelRequest: pendamping membatalkan pengajuan yang masih Menunggu.
	CancelRequest(ctx context.Context, requestID, companionID string) error

		// NotifyInfo: bahan teks push untuk satu pengajuan.
	NotifyInfo(ctx context.Context, requestID string) (*NotifyInfo, error)
}

type postgresRepository struct {
	pool *pgxpool.Pool
}

func NewRepository(pool *pgxpool.Pool) Repository {
	return &postgresRepository{pool: pool}
}

// ---------------------------------------------------------------------
// Baca
// ---------------------------------------------------------------------

func (r *postgresRepository) ListSchedules(ctx context.Context, userID, tunanetraID string) ([]Schedule, error) {
	// Izin baca dicek di query yang sama: pemilik sendiri, atau pendamping
	// yang berstatus Terhubung di tabel request.
	const query = `
		SELECT s.schedule_id::text, s.visually_impaired_id::text, s.title,
		       s.repeat_type::text, to_char(s.time, 'HH24:MI'), s.day::text,
		       to_char(s.start_date, 'YYYY-MM-DD'), s.reminder_minutes::int
		FROM public.schedule s
		WHERE s.visually_impaired_id = $2::uuid
		  AND (
		      $1::uuid = $2::uuid
		      OR EXISTS (
		          SELECT 1 FROM public.request r
		          WHERE r.companion_id = $1::uuid
		            AND r.visually_impaired_id = $2::uuid
		            AND r.status = 'Terhubung'
		      )
		  )
		ORDER BY s.time, s.title`

	rows, err := r.pool.Query(ctx, query, userID, tunanetraID)
	if err != nil {
		return nil, fmt.Errorf("ambil jadwal: %w", err)
	}
	defer rows.Close()

	// Non-nil supaya JSON-nya [] dan bukan null.
	items := make([]Schedule, 0)
	for rows.Next() {
		var s Schedule
		if err := rows.Scan(
			&s.ID, &s.TunanetraID, &s.Title, &s.RepeatType, &s.Time, &s.Day,
			&s.StartDate, &s.ReminderMinutes,
		); err != nil {
			return nil, fmt.Errorf("baca jadwal: %w", err)
		}
		items = append(items, s)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("baca jadwal: %w", err)
	}
	return items, nil
}

const requestSelect = `
	SELECT sr.schedule_request_id::text,
	       sr.visually_impaired_id::text, vi.name,
	       sr.companion_id::text, cu.name,
	       sr.schedule_id::text,
	       sr.action::text, sr.submission_status::text,
	       sr.title, sr.repeat_type::text, to_char(sr.time, 'HH24:MI'), sr.day::text,
	       to_char(sr.start_date, 'YYYY-MM-DD'), sr.reminder_minutes::int
	FROM public.schedule_request sr
	JOIN public."user" vi ON vi.user_id = sr.visually_impaired_id
	JOIN public."user" cu ON cu.user_id = sr.companion_id`

func (r *postgresRepository) ListRequests(ctx context.Context, companionID string, tunanetraID *string) ([]Request, error) {
	const query = requestSelect + `
		WHERE sr.companion_id = $1::uuid
		  AND ($2::uuid IS NULL OR sr.visually_impaired_id = $2::uuid)
		ORDER BY (sr.submission_status = 'Menunggu') DESC, sr.title`

	return r.listRequests(ctx, query, companionID, tunanetraID)
}

func (r *postgresRepository) ListIncoming(ctx context.Context, tunanetraID string) ([]Request, error) {
	const query = requestSelect + `
		WHERE sr.visually_impaired_id = $1::uuid
		  AND sr.submission_status = 'Menunggu'
		ORDER BY sr.title`

	return r.listRequests(ctx, query, tunanetraID)
}

func (r *postgresRepository) listRequests(ctx context.Context, query string, args ...any) ([]Request, error) {
	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("ambil pengajuan jadwal: %w", err)
	}
	defer rows.Close()

	items := make([]Request, 0)
	for rows.Next() {
		var q Request
		if err := rows.Scan(
			&q.ID,
			&q.TunanetraID, &q.TunanetraName,
			&q.CompanionID, &q.CompanionName,
			&q.ScheduleID,
			&q.Action, &q.Status,
			&q.Title, &q.RepeatType, &q.Time, &q.Day,
			&q.StartDate, &q.ReminderMinutes,
		); err != nil {
			return nil, fmt.Errorf("baca pengajuan jadwal: %w", err)
		}
		items = append(items, q)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("baca pengajuan jadwal: %w", err)
	}
	return items, nil
}

// ---------------------------------------------------------------------
// Tulis (lewat WithActor, sama seperti repository lain)
// ---------------------------------------------------------------------

func (r *postgresRepository) CreateRequest(ctx context.Context, in CreateInput) (string, error) {
	var newID string

	err := database.WithActor(ctx, r.pool, in.CompanionID, func(tx pgx.Tx) error {
		// 1. Pendamping harus sudah Terhubung dengan tunanetra ini.
		var connected bool
		const checkConnected = `
			SELECT EXISTS (
			    SELECT 1 FROM public.request
			    WHERE companion_id = $1::uuid
			      AND visually_impaired_id = $2::uuid
			      AND status = 'Terhubung'
			)`
		if err := tx.QueryRow(ctx, checkConnected, in.CompanionID, in.TunanetraID).Scan(&connected); err != nil {
			return fmt.Errorf("cek koneksi pendamping: %w", err)
		}
		if !connected {
			return ErrNotConnected
		}

		title, repeat, tm, day := in.Title, in.RepeatType, in.Time, in.Day
		startDate, reminder := in.StartDate, in.ReminderMinutes

		// 2. Ubah / Hapus: jadwalnya harus ada dan milik tunanetra ini.
		if in.Action != ActionTambah {
			if in.ScheduleID == nil {
				return ErrScheduleNotFound
			}

			var curTitle, curRepeat, curTime string
			var curDay, curStart *string
			var curReminder int
			const loadCurrent = `
				SELECT title, repeat_type::text, to_char(time, 'HH24:MI'), day::text,
				       to_char(start_date, 'YYYY-MM-DD'), reminder_minutes::int
				FROM public.schedule
				WHERE schedule_id = $1::uuid AND visually_impaired_id = $2::uuid`
			err := tx.QueryRow(ctx, loadCurrent, *in.ScheduleID, in.TunanetraID).
				Scan(&curTitle, &curRepeat, &curTime, &curDay, &curStart, &curReminder)
			if errors.Is(err, pgx.ErrNoRows) {
				return ErrScheduleNotFound
			}
			if err != nil {
				return fmt.Errorf("ambil jadwal lama: %w", err)
			}

			// Satu jadwal hanya boleh punya satu pengajuan yang menunggu.
			var pending bool
			const checkPending = `
				SELECT EXISTS (
				    SELECT 1 FROM public.schedule_request
				    WHERE schedule_id = $1::uuid AND submission_status = 'Menunggu'
				)`
			if err := tx.QueryRow(ctx, checkPending, *in.ScheduleID).Scan(&pending); err != nil {
				return fmt.Errorf("cek pengajuan menunggu: %w", err)
			}
			if pending {
				return ErrPendingExists
			}

			if in.Action == ActionHapus {
				// Simpan salinan jadwal yang akan dihapus untuk riwayat.
				title, repeat, tm, day = &curTitle, &curRepeat, &curTime, curDay
				startDate, reminder = curStart, &curReminder
			} else {
				// Ubah: isian yang kosong memakai nilai lama.
				if title == nil {
					title = &curTitle
				}
				if repeat == nil {
					repeat = &curRepeat
				}
				if tm == nil {
					tm = &curTime
				}
				if day == nil {
					day = curDay
				}
				if startDate == nil {
					startDate = curStart
				}
				if reminder == nil {
					reminder = &curReminder
				}
			}
		}

		// 3. Simpan pengajuan. Tabel schedule TIDAK disentuh di sini.
		const insert = `
			INSERT INTO public.schedule_request
			    (visually_impaired_id, companion_id, schedule_id, action,
			     title, repeat_type, time, day, start_date, reminder_minutes)
			VALUES ($1::uuid, $2::uuid, $3::uuid, $4::schedule_action,
			        $5, $6::repeat_type_enum, $7::time, $8::day_enum,
			        $9::date, $10::smallint)
			RETURNING schedule_request_id::text`
		if err := tx.QueryRow(ctx, insert,
			in.TunanetraID, in.CompanionID, in.ScheduleID, in.Action,
			title, repeat, tm, day, startDate, reminder,
		).Scan(&newID); err != nil {
			return fmt.Errorf("simpan pengajuan jadwal: %w", err)
		}
		return nil
	})
	if err != nil {
		return "", err
	}
	return newID, nil
}

func (r *postgresRepository) Respond(ctx context.Context, requestID, tunanetraID string, accept bool) error {
	gone := false

	err := database.WithActor(ctx, r.pool, tunanetraID, func(tx pgx.Tx) error {
		// Kunci baris pengajuan supaya tidak dijawab dua kali bersamaan.
		var action string
		var scheduleID, title, repeat, tm, day, startDate *string
		var reminder *int
		const load = `
			SELECT action::text, schedule_id::text, title, repeat_type::text,
			       to_char(time, 'HH24:MI'), day::text,
			       to_char(start_date, 'YYYY-MM-DD'), reminder_minutes::int
			FROM public.schedule_request
			WHERE schedule_request_id = $1::uuid
			  AND visually_impaired_id = $2::uuid
			  AND submission_status = 'Menunggu'
			FOR UPDATE`
		err := tx.QueryRow(ctx, load, requestID, tunanetraID).
			Scan(&action, &scheduleID, &title, &repeat, &tm, &day, &startDate, &reminder)
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrRequestNotFound
		}
		if err != nil {
			return fmt.Errorf("ambil pengajuan jadwal: %w", err)
		}

		if accept {
			switch action {
			case ActionTambah:
				var newScheduleID string
				const insert = `
					INSERT INTO public.schedule
					    (visually_impaired_id, title, repeat_type, time, day, start_date, reminder_minutes)
					VALUES ($1::uuid, $2,
					        COALESCE($3::repeat_type_enum, 'Tidak berulang'::repeat_type_enum),
					        $4::time, $5::day_enum, $6::date,
					        COALESCE($7::smallint, $8::smallint))
					RETURNING schedule_id::text`
				if err := tx.QueryRow(ctx, insert,
					tunanetraID, title, repeat, tm, day, startDate, reminder, defaultReminderMinutes,
				).Scan(&newScheduleID); err != nil {
					return fmt.Errorf("tambah jadwal: %w", err)
				}
				const link = `
					UPDATE public.schedule_request SET schedule_id = $2::uuid
					WHERE schedule_request_id = $1::uuid`
				if _, err := tx.Exec(ctx, link, requestID, newScheduleID); err != nil {
					return fmt.Errorf("tautkan pengajuan ke jadwal: %w", err)
				}

			case ActionUbah:
				const update = `
					UPDATE public.schedule s
					SET title = COALESCE($2, s.title),
					    repeat_type = COALESCE($3::repeat_type_enum, s.repeat_type),
					    time = COALESCE($4::time, s.time),
					    day = COALESCE($5::day_enum, s.day),
					    start_date = COALESCE($7::date, s.start_date),
					    reminder_minutes = COALESCE($8::smallint, s.reminder_minutes)
					WHERE s.schedule_id = $1::uuid AND s.visually_impaired_id = $6::uuid`
				tag, err := tx.Exec(ctx, update,
					scheduleID, title, repeat, tm, day, tunanetraID, startDate, reminder)
				if err != nil {
					return fmt.Errorf("ubah jadwal: %w", err)
				}
				if tag.RowsAffected() == 0 {
					gone = true
				}

			case ActionHapus:
				// Pengajuan lain yang menunggu untuk jadwal ini ikut ditolak,
				// karena jadwalnya akan hilang.
				const rejectOthers = `
					UPDATE public.schedule_request
					SET submission_status = 'Ditolak'::submission_status
					WHERE schedule_id = $1::uuid
					  AND submission_status = 'Menunggu'
					  AND schedule_request_id <> $2::uuid`
				if _, err := tx.Exec(ctx, rejectOthers, scheduleID, requestID); err != nil {
					return fmt.Errorf("tolak pengajuan lain: %w", err)
				}

				const del = `
					DELETE FROM public.schedule
					WHERE schedule_id = $1::uuid AND visually_impaired_id = $2::uuid`
				tag, err := tx.Exec(ctx, del, scheduleID, tunanetraID)
				if err != nil {
					return fmt.Errorf("hapus jadwal: %w", err)
				}
				if tag.RowsAffected() == 0 {
					gone = true
				}

			default:
				return fmt.Errorf("aksi pengajuan tidak dikenal: %q", action)
			}
		}

		status := StatusDitolak
		if accept && !gone {
			status = StatusDisetujui
		}
		const mark = `
			UPDATE public.schedule_request
			SET submission_status = $2::submission_status
			WHERE schedule_request_id = $1::uuid`
		if _, err := tx.Exec(ctx, mark, requestID, status); err != nil {
			return fmt.Errorf("ubah status pengajuan: %w", err)
		}
		return nil
	})
	if err != nil {
		return err
	}
	if gone {
		return ErrScheduleGone
	}
	return nil
}

func (r *postgresRepository) CancelRequest(ctx context.Context, requestID, companionID string) error {
	return database.WithActor(ctx, r.pool, companionID, func(tx pgx.Tx) error {
		const query = `
			DELETE FROM public.schedule_request
			WHERE schedule_request_id = $1::uuid
			  AND companion_id = $2::uuid
			  AND submission_status = 'Menunggu'`

		tag, err := tx.Exec(ctx, query, requestID, companionID)
		if err != nil {
			return fmt.Errorf("batalkan pengajuan jadwal: %w", err)
		}
				if tag.RowsAffected() == 0 {
			return ErrRequestNotFound
		}
		return nil
	})
}

func (r *postgresRepository) NotifyInfo(ctx context.Context, requestID string) (*NotifyInfo, error) {
	const query = `
		SELECT sr.visually_impaired_id::text, cu.name, sr.action::text,
		       COALESCE(sr.title, ''), COALESCE(sr.repeat_type::text, ''),
		       COALESCE(to_char(sr.time, 'HH24:MI'), ''), COALESCE(sr.day::text, ''),
		       COALESCE(to_char(sr.start_date, 'YYYY-MM-DD'), '')
		FROM public.schedule_request sr
		JOIN public."user" cu ON cu.user_id = sr.companion_id
		WHERE sr.schedule_request_id = $1::uuid`

	var in NotifyInfo
	err := r.pool.QueryRow(ctx, query, requestID).Scan(
		&in.TunanetraID, &in.CompanionName, &in.Action,
		&in.Title, &in.RepeatType, &in.Time, &in.Day, &in.StartDate,
	)
	if err != nil {
		return nil, fmt.Errorf("ambil bahan notifikasi jadwal: %w", err)
	}
	return &in, nil
}