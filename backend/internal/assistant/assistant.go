package assistant

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

type AskRequest struct {
	Question              string   `json:"question"`
	Latitude              *float64 `json:"latitude"`
	Longitude             *float64 `json:"longitude"`
	Timezone              string   `json:"timezone"`
	TimezoneOffsetMinutes int      `json:"timezoneOffsetMinutes"`
}

type Answer struct {
	Answer string `json:"answer"`
	Intent string `json:"intent"`
}

type Handler struct {
	client *http.Client
}

func NewHandler() *Handler {
	return &Handler{client: &http.Client{Timeout: 8 * time.Second}}
}

func (h *Handler) Ask(ctx context.Context, req AskRequest) (Answer, error) {
	question := normalize(req.Question)
	if question == "" {
		return Answer{}, errors.New("pertanyaan tidak boleh kosong")
	}

	switch {
	case hasAny(question, "cuaca", "hujan", "suhu", "prakiraan", "cerah", "berawan"):
		if req.Latitude == nil || req.Longitude == nil || *req.Latitude < -90 || *req.Latitude > 90 || *req.Longitude < -180 || *req.Longitude > 180 {
			return Answer{Answer: "Untuk mengecek cuaca, ALICE memerlukan izin lokasi perangkat Anda.", Intent: "weather"}, nil
		}
		answer, err := h.weather(ctx, *req.Latitude, *req.Longitude)
		return Answer{Answer: answer, Intent: "weather"}, err
	case hasAny(question, "jam berapa", "pukul berapa", "waktu sekarang", "sekarang jam", "jam sekarang"):
		loc := requestLocation(req)
		now := time.Now().In(loc)
		return Answer{Answer: fmt.Sprintf("Sekarang pukul %s.", now.Format("15.04")), Intent: "time"}, nil
	case hasAny(question, "tanggal berapa", "hari apa", "tanggal hari ini", "hari ini tanggal", "tanggal sekarang"):
		loc := requestLocation(req)
		now := time.Now().In(loc)
		days := []string{"Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"}
		months := []string{"Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"}
		return Answer{Answer: fmt.Sprintf("Hari %s, %d %s %d.", days[now.Weekday()], now.Day(), months[now.Month()-1], now.Year()), Intent: "date"}, nil
	case hasAny(question, "halo", "hai", "selamat pagi", "selamat siang", "selamat sore", "selamat malam"):
		return Answer{Answer: "Halo, saya ALICE. Ada yang bisa saya bantu?", Intent: "greeting"}, nil
	case hasAny(question, "siapa kamu", "kamu siapa", "apa itu alice", "nama kamu"):
		return Answer{Answer: "Saya ALICE, asisten suara yang siap membantu Anda.", Intent: "identity"}, nil
	case hasAny(question, "terima kasih", "makasih", "terimakasih"):
		return Answer{Answer: "Sama-sama. Senang bisa membantu Anda.", Intent: "thanks"}, nil
	case hasAny(question, "ulangi", "katakan lagi", "tidak dengar", "tidak terdengar"):
		return Answer{Answer: "Tentu. Silakan tanyakan kembali hal yang ingin Anda ketahui.", Intent: "repeat"}, nil
	case hasAny(question, "bantuan", "bisa apa", "bisa membantu", "cara menggunakan"):
		return Answer{Answer: "Anda bisa bertanya tentang waktu, tanggal, cuaca, atau meminta bantuan dasar.", Intent: "help"}, nil
	default:
		return Answer{Answer: "Maaf, saya belum memahami pertanyaan itu. Anda bisa bertanya tentang waktu, tanggal, atau cuaca.", Intent: "fallback"}, nil
	}
}

func requestLocation(req AskRequest) *time.Location {
	if req.Timezone != "" {
		if loc, err := time.LoadLocation(req.Timezone); err == nil {
			return loc
		}
	}
	if req.TimezoneOffsetMinutes >= -14*60 && req.TimezoneOffsetMinutes <= 14*60 {
		return time.FixedZone("waktu perangkat", req.TimezoneOffsetMinutes*60)
	}
	return time.Local
}

func (h *Handler) weather(ctx context.Context, latitude, longitude float64) (string, error) {
	params := url.Values{}
	params.Set("latitude", fmt.Sprintf("%.6f", latitude))
	params.Set("longitude", fmt.Sprintf("%.6f", longitude))
	params.Set("current", "temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code")
	params.Set("daily", "precipitation_probability_max,temperature_2m_max,temperature_2m_min")
	params.Set("timezone", "auto")
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, "https://api.open-meteo.com/v1/forecast?"+params.Encode(), nil)
	if err != nil {
		return "", err
	}
	response, err := h.client.Do(request)
	if err != nil {
		return "", fmt.Errorf("tidak dapat mengambil prakiraan cuaca: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return "", fmt.Errorf("layanan cuaca merespons HTTP %d", response.StatusCode)
	}
	var data struct {
		Current struct {
			Temperature float64 `json:"temperature_2m"`
			FeelsLike   float64 `json:"apparent_temperature"`
			Humidity    int     `json:"relative_humidity_2m"`
			Code        int     `json:"weather_code"`
		} `json:"current"`
		Daily struct {
			RainChance []int `json:"precipitation_probability_max"`
		} `json:"daily"`
	}
	if err := json.NewDecoder(response.Body).Decode(&data); err != nil {
		return "", fmt.Errorf("gagal membaca prakiraan cuaca: %w", err)
	}
	condition := weatherDescription(data.Current.Code)
	answer := fmt.Sprintf("Cuaca saat ini %s dengan suhu %.0f derajat Celsius. Terasa seperti %.0f derajat, kelembapan %d persen.", condition, data.Current.Temperature, data.Current.FeelsLike, data.Current.Humidity)
	if len(data.Daily.RainChance) > 0 {
		answer += fmt.Sprintf(" Peluang hujan hari ini hingga %d persen.", data.Daily.RainChance[0])
	}
	return answer, nil
}

func weatherDescription(code int) string {
	switch code {
	case 0:
		return "cerah"
	case 1, 2:
		return "cerah berawan"
	case 3:
		return "berawan"
	case 45, 48:
		return "berkabut"
	case 51, 53, 55, 56, 57:
		return "gerimis"
	case 61, 63, 65, 66, 67:
		return "hujan"
	case 71, 73, 75, 77:
		return "bersalju"
	case 80, 81, 82:
		return "hujan lebat"
	case 85, 86:
		return "hujan salju"
	case 95, 96, 99:
		return "hujan badai"
	default:
		return "belum diketahui"
	}
}

func normalize(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	return strings.Join(strings.Fields(strings.Map(func(r rune) rune {
		if r == '?' || r == '!' || r == '.' || r == ',' {
			return ' '
		}
		return r
	}, s)), " ")
}

func hasAny(text string, phrases ...string) bool {
	for _, phrase := range phrases {
		if text == phrase || strings.Contains(text, phrase) {
			return true
		}
	}
	return false
}
