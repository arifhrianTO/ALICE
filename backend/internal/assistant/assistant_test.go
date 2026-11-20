package assistant

import (
	"context"
	"strings"
	"testing"
)

func TestAskMatchesBasicFAQ(t *testing.T) {
	handler := NewHandler()
	tests := []struct {
		question string
		intent   string
	}{
		{"Halo Alice!", "greeting"},
		{"Kamu siapa?", "identity"},
		{"Tolong ulangi jawaban", "repeat"},
		{"Bagaimana cuaca hari ini?", "weather"},
	}
	for _, test := range tests {
		t.Run(test.intent, func(t *testing.T) {
			answer, err := handler.Ask(context.Background(), AskRequest{Question: test.question})
			if err != nil {
				t.Fatalf("Ask() error = %v", err)
			}
			if answer.Intent != test.intent || strings.TrimSpace(answer.Answer) == "" {
				t.Fatalf("Ask() = %+v, want intent %q and non-empty answer", answer, test.intent)
			}
		})
	}
}

func TestAskUsesDeviceTimezoneOffset(t *testing.T) {
	answer, err := NewHandler().Ask(context.Background(), AskRequest{
		Question:              "sekarang jam berapa",
		TimezoneOffsetMinutes: -420,
	})
	if err != nil {
		t.Fatal(err)
	}
	if answer.Intent != "time" || !strings.HasPrefix(answer.Answer, "Sekarang pukul ") {
		t.Fatalf("unexpected answer: %+v", answer)
	}
}

func TestWeatherWithoutCoordinatesRequestsLocation(t *testing.T) {
	answer, err := NewHandler().Ask(context.Background(), AskRequest{Question: "Apakah hari ini hujan?"})
	if err != nil {
		t.Fatal(err)
	}
	if answer.Intent != "weather" || !strings.Contains(answer.Answer, "izin lokasi") {
		t.Fatalf("unexpected answer: %+v", answer)
	}
}
