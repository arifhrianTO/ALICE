package notification

import (
	"context"
	"fmt"
	"os"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

// Sender adalah kontrak pengirim push notification.
//
// Dipisah dari implementasi FCM supaya Service bisa diuji tanpa jaringan
// dan tanpa kunci rahasia Firebase.
type Sender interface {
	// Send mengirim satu pesan ke satu token perangkat.
	Send(ctx context.Context, token, title, body string, data map[string]string) error
}

// fcmSender adalah implementasi Sender memakai Firebase Admin SDK.
type fcmSender struct {
	client *messaging.Client
}

// NewFCMSender menyiapkan pengirim FCM dari file kredensial service account.
//
// File itu HARUS tetap di server, tidak boleh masuk Git, dan tidak pernah
// dikirim ke aplikasi. Isinya kunci admin project Firebase.
func NewFCMSender(ctx context.Context, credentialsFile string) (Sender, error) {
	if credentialsFile == "" {
		return nil, fmt.Errorf("FIREBASE_CREDENTIALS_FILE belum diisi")
	}
	if _, err := os.Stat(credentialsFile); err != nil {
		return nil, fmt.Errorf("file kredensial Firebase tidak terbaca: %w", err)
	}

	app, err := firebase.NewApp(ctx, nil, option.WithCredentialsFile(credentialsFile))
	if err != nil {
		return nil, fmt.Errorf("siapkan Firebase: %w", err)
	}

	client, err := app.Messaging(ctx)
	if err != nil {
		return nil, fmt.Errorf("siapkan FCM: %w", err)
	}

	return &fcmSender{client: client}, nil
}

// Send mengirim satu notifikasi.
//
// Prioritas tinggi di Android membuat pesan segera dibangunkan, bukan
// ditunda sampai perangkat keluar dari mode hemat baterai. Untuk aplikasi
// pendamping tunanetra, keterlambatan beberapa menit bisa berarti
// kehilangan momen penting.
func (s *fcmSender) Send(ctx context.Context, token, title, body string, data map[string]string) error {
	msg := &messaging.Message{
		Token: token,
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
		Data: data,
		Android: &messaging.AndroidConfig{
			Priority: "high",
			Notification: &messaging.AndroidNotification{
				Sound: "default",
			},
		},
		APNS: &messaging.APNSConfig{
			Payload: &messaging.APNSPayload{
				Aps: &messaging.Aps{Sound: "default"},
			},
		},
	}

	if _, err := s.client.Send(ctx, msg); err != nil {
		return fmt.Errorf("kirim FCM: %w", err)
	}
	return nil
}

// IsUnregistered menjawab apakah error berarti token sudah mati.
//
// Token menjadi mati ketika aplikasi dihapus, data aplikasi dibersihkan,
// atau FCM menggantinya dengan token baru. Baris seperti ini harus dibuang
// dari database, bukan dicoba lagi selamanya.
func IsUnregistered(err error) bool {
	return messaging.IsUnregistered(err)
}
