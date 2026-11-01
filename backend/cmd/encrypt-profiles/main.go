// Command encrypt-profiles mengenkripsi data profil lama yang masih
// tersimpan sebagai plaintext.
//
// Kapan dipakai? Saat fitur enkripsi baru dipasang dan database sudah
// berisi nomor telepon/alamat dari versi aplikasi sebelumnya. Data baru
// otomatis terenkripsi; alat ini hanya membereskan sisa yang lama.
//
// Sifatnya idempotent: baris yang sudah berawalan "v1:" dilewati. Jadi
// aman dijalankan berkali-kali.
//
// Cara pakai:
//
//	cd backend
//	go run ./cmd/encrypt-profiles
package main

import (
	"context"
	"fmt"
	"log"
	"time"

	"alice-backend/internal/shared/config"
	"alice-backend/internal/shared/crypto"
	"alice-backend/internal/shared/database"
	"alice-backend/internal/user"

	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	if err := run(); err != nil {
		log.Fatalf("migrasi gagal: %v", err)
	}
}

type companionRow struct {
	userID  string
	phone   *string
	address *string
}

func run() error {
	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("konfigurasi tidak valid: %w", err)
	}

	fieldCipher, err := crypto.New(cfg.ProfileEncryptionKey)
	if err != nil {
		return fmt.Errorf("siapkan enkripsi: %w", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	db, err := database.Connect(ctx, cfg.DSN())
	if err != nil {
		return fmt.Errorf("tidak bisa konek ke database: %w", err)
	}
	defer db.Close()

	rows, err := loadRows(ctx, db)
	if err != nil {
		return err
	}

	fmt.Printf("Menemukan %d baris profil dengan data.\n\n", len(rows))

	encrypted := 0
	for _, row := range rows {
		phone, phoneChanged, err := encryptIfNeeded(
			fieldCipher, row.phone, user.PhoneAAD(row.userID),
		)
		if err != nil {
			return fmt.Errorf("enkripsi telepon %s: %w", row.userID, err)
		}

		address, addressChanged, err := encryptIfNeeded(
			fieldCipher, row.address, user.AddressAAD(row.userID),
		)
		if err != nil {
			return fmt.Errorf("enkripsi alamat %s: %w", row.userID, err)
		}

		if !phoneChanged && !addressChanged {
			continue
		}

		const update = `
			UPDATE public.companion
			SET phone_number = $2, address = $3
			WHERE user_id = $1`

		if _, err := db.Exec(ctx, update, row.userID, phone, address); err != nil {
			return fmt.Errorf("simpan hasil enkripsi %s: %w", row.userID, err)
		}

		encrypted++
		fmt.Printf("  OK  %s\n", row.userID)
	}

	fmt.Printf("\nSelesai. %d baris dienkripsi, %d baris dilewati (sudah terenkripsi).\n",
		encrypted, len(rows)-encrypted)

	return nil
}

func loadRows(ctx context.Context, db *pgxpool.Pool) ([]companionRow, error) {
	const query = `
		SELECT user_id, phone_number, address
		FROM public.companion
		WHERE phone_number IS NOT NULL OR address IS NOT NULL`

	rows, err := db.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("baca data companion: %w", err)
	}
	defer rows.Close()

	var result []companionRow
	for rows.Next() {
		var row companionRow
		if err := rows.Scan(&row.userID, &row.phone, &row.address); err != nil {
			return nil, fmt.Errorf("baca baris companion: %w", err)
		}
		result = append(result, row)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("baca data companion: %w", err)
	}

	return result, nil
}

// encryptIfNeeded mengembalikan nilai (mungkin sudah terenkripsi) beserta
// penanda apakah nilainya berubah.
func encryptIfNeeded(c *crypto.Cipher, value *string, aad string) (*string, bool, error) {
	if value == nil || crypto.IsEncrypted(*value) {
		return value, false, nil
	}

	encrypted, err := c.Encrypt(*value, aad)
	if err != nil {
		return nil, false, err
	}
	return &encrypted, true, nil
}
