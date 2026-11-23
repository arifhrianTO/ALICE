package auth_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"alice-backend/internal/auth"
	"alice-backend/internal/user"

	"golang.org/x/crypto/bcrypt"
)

type mockUserRepo struct {
	user *user.User
}

func (m *mockUserRepo) FindByEmail(ctx context.Context, email string) (*user.User, error) {
	if m.user != nil && m.user.Email != nil && *m.user.Email == email {
		return m.user, nil
	}
	return nil, nil
}

func (m *mockUserRepo) Create(ctx context.Context, in user.CreateInput) error {
	return nil
}

func (m *mockUserRepo) FindProfile(ctx context.Context, userID string) (*user.Profile, error) {
	return nil, nil
}

func (m *mockUserRepo) UpdateProfile(ctx context.Context, userID, name string, phoneNumber, address *string) error {
	return nil
}

func (m *mockUserRepo) ListAccountsByRole(ctx context.Context, role string) ([]user.Account, error) {
	return nil, nil
}

type mockSessionRepo struct{}

func (m *mockSessionRepo) Create(ctx context.Context, s *auth.Session) error {
	return nil
}

func (m *mockSessionRepo) DeleteByToken(ctx context.Context, token string) error {
	return nil
}

func TestLogin(t *testing.T) {
	ctx := context.Background()
	hash, err := bcrypt.GenerateFromPassword([]byte("password123"), bcrypt.DefaultCost)
	if err != nil {
		t.Fatalf("hash: %v", err)
	}
	hashStr := string(hash)
	email := "test@example.com"

	mockUser := &user.User{
		UserID:   "usr-1",
		Email:    &email,
		Password: &hashStr,
	}

	svc := auth.NewService(&mockUserRepo{user: mockUser}, &mockSessionRepo{}, nil, time.Hour, "", "", "")

	// Case 1: user not found
	if _, err := svc.Login(ctx, auth.LoginInput{Email: "unknown@example.com", Password: "any"}); err != auth.ErrInvalidCredentials {
		t.Fatalf("expected ErrInvalidCredentials for unknown email, got %v", err)
	}

	// Case 2: wrong password
	if _, err := svc.Login(ctx, auth.LoginInput{Email: email, Password: "wrong"}); err != auth.ErrInvalidCredentials {
		t.Fatalf("expected ErrInvalidCredentials for wrong password, got %v", err)
	}

	// Case 3: valid login
	res, err := svc.Login(ctx, auth.LoginInput{Email: email, Password: "password123"})
	if err != nil {
		t.Fatalf("login failed: %v", err)
	}
	if res.User.UserID != "usr-1" || res.Token == "" {
		t.Fatalf("invalid login result: %+v", res)
	}
}

func TestRegister(t *testing.T) {
	ctx := context.Background()
	var createdUser *user.User

	mockU := &mockUserRepoCreate{
		onCreate: func(in user.CreateInput) error {
			createdUser = in.User
			in.User.UserID = "usr-new"
			if in.PhoneNumber != nil {
				createdUser.PhoneNumber = *in.PhoneNumber
			}
			if in.Address != nil {
				createdUser.Address = *in.Address
			}
			return nil
		},
	}

	svc := auth.NewService(mockU, &mockSessionRepo{}, nil, time.Hour, "", "", "")

	res, err := svc.Register(ctx, auth.RegisterInput{
		Name:        "Pendamping Baru",
		Email:       "baru@example.com",
		Password:    "password123",
		Role:        "pendamping",
		PhoneNumber: "08123456789",
		Address:     "Jl. Sudirman No 1",
	})
	if err != nil {
		t.Fatalf("register failed: %v", err)
	}
	if res.User.UserID != "usr-new" || res.Token == "" {
		t.Fatalf("invalid register result: %+v", res)
	}
	if createdUser.PhoneNumber != "08123456789" || createdUser.Address != "Jl. Sudirman No 1" {
		t.Fatalf("phone and address not set properly: %+v", createdUser)
	}
}

func TestLoginWithFacebook_EmptyToken(t *testing.T) {
	svc := auth.NewService(&mockUserRepo{}, &mockSessionRepo{}, nil, time.Hour, "", "", "")
	_, err := svc.LoginWithFacebook(context.Background(), "", "", "pendamping")
	if err == nil {
		t.Fatal("expected error for empty Facebook access token, got nil")
	}
}

func TestLogout_EmptyToken(t *testing.T) {
	svc := auth.NewService(&mockUserRepo{}, &mockSessionRepo{}, nil, time.Hour, "", "", "")

	if err := svc.Logout(context.Background(), "   "); err == nil {
		t.Fatal("expected error for empty session token, got nil")
	}
}

func TestLoginWithFacebook_InvalidRole(t *testing.T) {
	svc := auth.NewService(
		&mockUserRepo{}, &mockSessionRepo{}, nil, time.Hour,
		"", "app-id", "app-secret",
	)

	_, err := svc.LoginWithFacebook(context.Background(), "dummy-token", "classic", "admin")
	if err == nil {
		t.Fatal("expected error for invalid role, got nil")
	}

	var ve *auth.ValidationError
	if !errors.As(err, &ve) {
		t.Fatalf("expected ValidationError, got %T: %v", err, err)
	}
}

func TestLoginWithFacebook_InvalidTokenType(t *testing.T) {
	svc := auth.NewService(
		&mockUserRepo{}, &mockSessionRepo{}, nil, time.Hour,
		"", "app-id", "app-secret",
	)

	_, err := svc.LoginWithFacebook(context.Background(), "dummy-token", "weird", "pendamping")
	if err == nil {
		t.Fatal("expected error for unknown token type, got nil")
	}

	var ve *auth.ValidationError
	if !errors.As(err, &ve) {
		t.Fatalf("expected ValidationError, got %T: %v", err, err)
	}
}

type mockUserRepoCreate struct {
	onCreate func(in user.CreateInput) error
}

func (m *mockUserRepoCreate) FindByEmail(ctx context.Context, email string) (*user.User, error) {
	return nil, nil
}

func (m *mockUserRepoCreate) Create(ctx context.Context, in user.CreateInput) error {
	if m.onCreate != nil {
		return m.onCreate(in)
	}
	return nil
}

func (m *mockUserRepoCreate) FindProfile(ctx context.Context, userID string) (*user.Profile, error) {
	return nil, nil
}

func (m *mockUserRepoCreate) UpdateProfile(ctx context.Context, userID, name string, phoneNumber, address *string) error {
	return nil
}

func (m *mockUserRepoCreate) ListAccountsByRole(ctx context.Context, role string) ([]user.Account, error) {
	return nil, nil
}
