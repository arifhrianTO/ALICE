package auth_test

import (
	"context"
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

type mockSessionRepo struct{}

func (m *mockSessionRepo) Create(ctx context.Context, s *auth.Session) error {
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

	svc := auth.NewService(&mockUserRepo{user: mockUser}, &mockSessionRepo{}, nil, time.Hour)

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
