package assistant

import (
	"context"
	"strings"
	"testing"
	"time"
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

func TestRelativeDateAnswers(t *testing.T) {
	now := time.Date(2026, 11, 20, 10, 0, 0, 0, time.FixedZone("WIB", 7*3600))
	tests := []struct {
		question string
		want     string
	}{
		{"besok tanggal berapa", "Besok adalah hari Sabtu, 21 November 2026."},
		{"lusa tanggal berapa", "Lusa adalah hari Minggu, 22 November 2026."},
		{"kemarin hari apa", "Kemarin adalah hari Kamis, 19 November 2026."},
		{"kemarin lusa tanggal berapa", "Kemarin lusa adalah hari Rabu, 18 November 2026."},
		{"2 hari lagi tanggal berapa", "2 hari lagi adalah hari Minggu, 22 November 2026."},
		{"tiga hari yang lalu tanggal berapa", "3 hari yang lalu adalah hari Selasa, 17 November 2026."},
	}
	for _, test := range tests {
		t.Run(test.question, func(t *testing.T) {
			got, ok := relativeDateAnswer(normalize(test.question), now)
			if !ok || got != test.want {
				t.Fatalf("relativeDateAnswer() = %q, %v; want %q, true", got, ok, test.want)
			}
		})
	}
}

func TestRelativeTimeAnswers(t *testing.T) {
	now := time.Date(2026, 11, 20, 10, 0, 0, 0, time.FixedZone("WIB", 7*3600))
	tests := []struct {
		question string
		want     string
	}{
		{"2 jam lagi jam berapa", "Sekarang pukul 10.00. 2 jam lagi pukul 12.00."},
		{"30 menit yang lalu jam berapa", "Sekarang pukul 10.00. 30 menit yang lalu pukul 09.30."},
		{"setengah jam lagi jam berapa", "Sekarang pukul 10.00. 30 menit lagi pukul 10.30."},
		{"sejam yang lalu jam berapa", "Sekarang pukul 10.00. 1 jam yang lalu pukul 09.00."},
	}
	for _, test := range tests {
		t.Run(test.question, func(t *testing.T) {
			got, ok := relativeTimeAnswer(normalize(test.question), now)
			if !ok || got != test.want {
				t.Fatalf("relativeTimeAnswer() = %q, %v; want %q, true", got, ok, test.want)
			}
		})
	}
}

func TestAskHandlesRelativeDates(t *testing.T) {
	answer, err := NewHandler().Ask(context.Background(), AskRequest{Question: "besok tanggal berapa", TimezoneOffsetMinutes: 420})
	if err != nil {
		t.Fatal(err)
	}
	if answer.Intent != "date_relative" || !strings.Contains(answer.Answer, "Besok adalah hari") {
		t.Fatalf("unexpected answer: %+v", answer)
	}
}

func TestAskLocationUseCases(t *testing.T) {
	handler := NewHandler()

	named, err := handler.Ask(context.Background(), AskRequest{Question: "saya sedang dimana", LocationName: "Batam"})
	if err != nil {
		t.Fatal(err)
	}
	if named.Intent != "location" || !strings.Contains(named.Answer, "Batam") {
		t.Fatalf("unexpected named location answer: %+v", named)
	}

	latitude, longitude := 1.1301, 104.0529
	coords, err := handler.Ask(context.Background(), AskRequest{Question: "lokasi saya", Latitude: &latitude, Longitude: &longitude})
	if err != nil {
		t.Fatal(err)
	}
	if coords.Intent != "location" || !strings.Contains(coords.Answer, "koordinat") {
		t.Fatalf("unexpected coordinate answer: %+v", coords)
	}

	missing, err := handler.Ask(context.Background(), AskRequest{Question: "posisi saya"})
	if err != nil {
		t.Fatal(err)
	}
	if missing.Intent != "location" || !strings.Contains(missing.Answer, "izin lokasi") {
		t.Fatalf("unexpected missing location answer: %+v", missing)
	}
}
