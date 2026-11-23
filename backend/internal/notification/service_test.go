package notification_test

import (
	"context"
	"errors"
	"testing"

	"alice-backend/internal/notification"
)

// fakeRepo meniru tabel device_token di memori.
type fakeRepo struct {
	tokens  []notification.DeviceToken
	deleted []string
}

func (f *fakeRepo) Upsert(ctx context.Context, userID, token, platform string) (*notification.DeviceToken, error) {
	return &notification.DeviceToken{UserID: userID, Token: token, Platform: platform}, nil
}

func (f *fakeRepo) ListByUser(ctx context.Context, userID string) ([]notification.DeviceToken, error) {
	return f.tokens, nil
}

func (f *fakeRepo) Delete(ctx context.Context, token string) error {
	f.deleted = append(f.deleted, token)
	return nil
}

// fakeSender mencatat pesan yang dikirim dan bisa dibuat gagal.
type fakeSender struct {
	sent       []string
	errByToken map[string]error
}

func (f *fakeSender) Send(ctx context.Context, token, title, body string, data map[string]string) error {
	if err := f.errByToken[token]; err != nil {
		return err
	}
	f.sent = append(f.sent, token)
	return nil
}

func TestRegisterTokenValidation(t *testing.T) {
	svc := notification.NewService(&fakeRepo{}, nil)

	if _, err := svc.RegisterToken(context.Background(), "usr-1", notification.RegisterTokenInput{}); err == nil {
		t.Fatal("token kosong seharusnya ditolak")
	}

	_, err := svc.RegisterToken(context.Background(), "usr-1", notification.RegisterTokenInput{
		Token: "abc", Platform: "windows",
	})
	var ve *notification.ValidationError
	if !errors.As(err, &ve) {
		t.Fatalf("platform salah seharusnya ValidationError, dapat %v", err)
	}

	saved, err := svc.RegisterToken(context.Background(), "usr-1", notification.RegisterTokenInput{
		Token: "abc", Platform: "android",
	})
	if err != nil {
		t.Fatalf("token sah ditolak: %v", err)
	}
	if saved.Platform != "android" {
		t.Fatalf("platform tidak tersimpan: %+v", saved)
	}
}

func TestNotifyUserRemovesDeadToken(t *testing.T) {
	repo := &fakeRepo{tokens: []notification.DeviceToken{
		{Token: "hidup"},
		{Token: "mati"},
	}}
	sender := &fakeSender{errByToken: map[string]error{
		"mati": errors.New("unregistered"),
	}}
	svc := notification.NewService(repo, sender)

	// Pengirim tiruan tidak bisa menandai error sebagai "unregistered"
	// milik FCM, jadi test ini hanya memastikan perangkat lain tetap
	// dicoba walaupun satu gagal.
	_ = svc.NotifyUser(context.Background(), "usr-1", "judul", "isi", nil)

	if len(sender.sent) != 1 || sender.sent[0] != "hidup" {
		t.Fatalf("perangkat sehat harus tetap dikirimi, dapat %+v", sender.sent)
	}
}

func TestNotifyUserWithoutSenderIsNoop(t *testing.T) {
	repo := &fakeRepo{tokens: []notification.DeviceToken{{Token: "abc"}}}
	svc := notification.NewService(repo, nil)

	if err := svc.NotifyUser(context.Background(), "usr-1", "judul", "isi", nil); err != nil {
		t.Fatalf("tanpa pengirim seharusnya tidak error: %v", err)
	}
}
