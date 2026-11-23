package request_test

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"alice-backend/internal/request"
	"alice-backend/internal/user"
)

// fakeRepo meniru tabel `request` di memori. Hanya method yang dipakai
// tes ini yang berperilaku; sisanya mengembalikan nilai netral.
type fakeRepo struct {
	incoming    []request.IncomingRequest
	incomingErr error
	incomingFor string

	respondedID   string
	respondedBy   string
	respondAccept *bool
	respondErr    error

	createdFor     string
	createdAgainst string
	createResult   *request.Request
	createErr      error
}

func (f *fakeRepo) ListByCompanion(ctx context.Context, companionID string) ([]request.Request, error) {
	return nil, nil
}

func (f *fakeRepo) Create(ctx context.Context, companionID, visuallyImpairedID string) (*request.Request, error) {
	f.createdFor = companionID
	f.createdAgainst = visuallyImpairedID
	if f.createResult != nil {
		return f.createResult, f.createErr
	}
	return &request.Request{ID: "req-baru", Status: request.StatusMenunggu}, f.createErr
}

func (f *fakeRepo) Delete(ctx context.Context, companionID, requestID string) error {
	return nil
}

func (f *fakeRepo) ListIncoming(ctx context.Context, tunanetraID string) ([]request.IncomingRequest, error) {
	f.incomingFor = tunanetraID
	return f.incoming, f.incomingErr
}

func (f *fakeRepo) Respond(ctx context.Context, requestID, tunanetraID string, accept bool) error {
	f.respondedID = requestID
	f.respondedBy = tunanetraID
	f.respondAccept = &accept
	return f.respondErr
}

// ListIncoming dengan repository kosong harus mengembalikan slice kosong
// (bukan nil) supaya balasan JSON-nya `[]`, bukan `null`.
func TestListIncomingReturnsEmptySlice(t *testing.T) {
	svc := request.NewService(&fakeRepo{}, nil, nil)

	items, err := svc.ListIncoming(context.Background(), "tn-1")
	if err != nil {
		t.Fatalf("ListIncoming error: %v", err)
	}
	if items == nil {
		t.Fatal("hasil nil; seharusnya slice kosong")
	}
	if len(items) != 0 {
		t.Fatalf("harus kosong, dapat %d item", len(items))
	}
}

func TestListIncomingForwardsTunanetraIDAndItems(t *testing.T) {
	repo := &fakeRepo{incoming: []request.IncomingRequest{
		{
			ID:             "req-1",
			CompanionName:  "Rina",
			CompanionEmail: "rina@example.com",
			Status:         request.StatusMenunggu,
		},
	}}
	svc := request.NewService(repo, nil, nil)

	items, err := svc.ListIncoming(context.Background(), "tn-9")
	if err != nil {
		t.Fatalf("ListIncoming error: %v", err)
	}
	if repo.incomingFor != "tn-9" {
		t.Fatalf("tunanetra id tidak diteruskan, dapat %q", repo.incomingFor)
	}
	if len(items) != 1 || items[0].CompanionName != "Rina" {
		t.Fatalf("item tidak diteruskan apa adanya: %+v", items)
	}
}

func TestListIncomingPropagatesError(t *testing.T) {
	sentinel := errors.New("db mati")
	svc := request.NewService(&fakeRepo{incomingErr: sentinel}, nil, nil)

	if _, err := svc.ListIncoming(context.Background(), "tn-1"); !errors.Is(err, sentinel) {
		t.Fatalf("error tidak diteruskan, dapat %v", err)
	}
}

func TestRespondRejectsBlankID(t *testing.T) {
	svc := request.NewService(&fakeRepo{}, nil, nil)

	err := svc.Respond(context.Background(), "tn-1", "   ", true)
	var ve *request.ValidationError
	if !errors.As(err, &ve) {
		t.Fatalf("id kosong seharusnya ValidationError, dapat %v", err)
	}
}

func TestRespondTrimsIDAndForwardsChoice(t *testing.T) {
	repo := &fakeRepo{}
	svc := request.NewService(repo, nil, nil)

	if err := svc.Respond(context.Background(), "tn-1", "  req-7  ", false); err != nil {
		t.Fatalf("Respond error: %v", err)
	}
	if repo.respondedID != "req-7" {
		t.Fatalf("id tidak di-trim, dapat %q", repo.respondedID)
	}
	if repo.respondedBy != "tn-1" {
		t.Fatalf("tunanetra id salah, dapat %q", repo.respondedBy)
	}
	if repo.respondAccept == nil || *repo.respondAccept {
		t.Fatalf("pilihan tolak (false) tidak diteruskan: %v", repo.respondAccept)
	}
}

func TestRespondPropagatesNotFound(t *testing.T) {
	svc := request.NewService(&fakeRepo{respondErr: request.ErrNotFound}, nil, nil)

	if err := svc.Respond(context.Background(), "tn-1", "req-1", true); !errors.Is(err, request.ErrNotFound) {
		t.Fatalf("ErrNotFound tidak diteruskan, dapat %v", err)
	}
}

// ---------------------------------------------------------------------
//  Notifikasi saat pengajuan dibuat (Tahap 2)
// ---------------------------------------------------------------------

// fakeUsers meniru user.Repository seperlunya.
type fakeUsers struct {
	profiles map[string]*user.Profile
}

func (f *fakeUsers) ListAccountsByRole(context.Context, string) ([]user.Account, error) {
	return nil, nil
}

func (f *fakeUsers) FindByEmail(context.Context, string) (*user.User, error) {
	return nil, nil
}

func (f *fakeUsers) Create(context.Context, user.CreateInput) error {
	return nil
}

func (f *fakeUsers) FindProfile(_ context.Context, userID string) (*user.Profile, error) {
	return f.profiles[userID], nil
}

func (f *fakeUsers) UpdateProfile(context.Context, string, string, *string, *string) error {
	return nil
}

// notifyCall merekam satu panggilan NotifyUser untuk diperiksa.
type notifyCall struct {
	userID string
	title  string
	body   string
	data   map[string]string
}

// fakeNotifier meniru notification.Service. Karena pengiriman berjalan di
// goroutine, hasilnya dikirim lewat channel supaya tes bisa menunggu
// dengan pasti (tidak sekadar menebak lewat waktu tunggu).
type fakeNotifier struct {
	ch  chan notifyCall
	err error
}

func (f *fakeNotifier) NotifyUser(_ context.Context, userID, title, body string, data map[string]string) error {
	if f.ch != nil {
		f.ch <- notifyCall{userID: userID, title: title, body: body, data: data}
	}
	return f.err
}

func tunanetraProfile(id, name string) *user.Profile {
	return &user.Profile{UserID: id, Name: name, Role: user.RoleTunanetra}
}

func TestCreateNotifiesTunanetra(t *testing.T) {
	repo := &fakeRepo{}
	users := &fakeUsers{profiles: map[string]*user.Profile{
		"tn-1":   tunanetraProfile("tn-1", "Agak Laen"),
		"pend-1": {UserID: "pend-1", Name: "Firgi", Role: user.RolePendamping},
	}}
	notifier := &fakeNotifier{ch: make(chan notifyCall, 1)}
	svc := request.NewService(repo, users, notifier)

	if _, err := svc.Create(context.Background(), "pend-1", "tn-1"); err != nil {
		t.Fatalf("Create error: %v", err)
	}

	select {
	case call := <-notifier.ch:
		if call.userID != "tn-1" {
			t.Fatalf("notifikasi ke %q, harusnya tn-1", call.userID)
		}
		if call.data["request_id"] != "req-baru" {
			t.Fatalf("request_id notifikasi salah: %q", call.data["request_id"])
		}
		if call.data["type"] != "connection_request" {
			t.Fatalf("type notifikasi salah: %q", call.data["type"])
		}
		if !strings.Contains(call.body, "Firgi") {
			t.Fatalf("body tidak memuat nama pendamping: %q", call.body)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("notifikasi tidak dikirim")
	}
}

func TestCreateSucceedsWhenNotifyFails(t *testing.T) {
	repo := &fakeRepo{}
	users := &fakeUsers{profiles: map[string]*user.Profile{
		"tn-1": tunanetraProfile("tn-1", "Agak Laen"),
	}}
	notifier := &fakeNotifier{ch: make(chan notifyCall, 1), err: errors.New("fcm mati")}
	svc := request.NewService(repo, users, notifier)

	if _, err := svc.Create(context.Background(), "pend-1", "tn-1"); err != nil {
		t.Fatalf("Create harus tetap sukses walau notifikasi gagal, dapat %v", err)
	}

	select {
	case <-notifier.ch:
	case <-time.After(2 * time.Second):
		t.Fatal("notifier tidak dipanggil")
	}
}

func TestCreateRejectsNonTunanetraTarget(t *testing.T) {
	repo := &fakeRepo{}
	users := &fakeUsers{profiles: map[string]*user.Profile{
		"pend-2": {UserID: "pend-2", Name: "Bukan TN", Role: user.RolePendamping},
	}}
	svc := request.NewService(repo, users, nil)

	_, err := svc.Create(context.Background(), "pend-1", "pend-2")
	var ve *request.ValidationError
	if !errors.As(err, &ve) {
		t.Fatalf("target bukan tunanetra harus ValidationError, dapat %v", err)
	}
}

func TestCreateSkipsNotifyWhenNotifierNil(t *testing.T) {
	repo := &fakeRepo{}
	users := &fakeUsers{profiles: map[string]*user.Profile{
		"tn-1": tunanetraProfile("tn-1", "Agak Laen"),
	}}
	svc := request.NewService(repo, users, nil)

	if _, err := svc.Create(context.Background(), "pend-1", "tn-1"); err != nil {
		t.Fatalf("Create error: %v", err)
	}
	if repo.createdAgainst != "tn-1" {
		t.Fatalf("create tidak diteruskan, dapat %q", repo.createdAgainst)
	}
}
