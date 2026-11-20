package assistant

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"
)

type AskRequest struct {
	Question              string   `json:"question"`
	Latitude              *float64 `json:"latitude"`
	Longitude             *float64 `json:"longitude"`
	LocationName          string   `json:"locationName"`
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

var (
	dayNames   = []string{"Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"}
	monthNames = []string{"Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"}
)

const numberPattern = `(\d+|dua\s+belas|sebelas|sepuluh|sembilan|delapan|tujuh|enam|lima|empat|tiga|dua|satu)`

var (
	minutesFuture = regexp.MustCompile(`(?i)` + numberPattern + `\s+menit\s+(lagi|kemudian|kedepan)`)
	minutesPast   = regexp.MustCompile(`(?i)` + numberPattern + `\s+menit\s+(yang\s+)?(lalu|sebelum)`)
	hoursFuture   = regexp.MustCompile(`(?i)` + numberPattern + `\s+jam\s+(lagi|kemudian|kedepan)`)
	hoursPast     = regexp.MustCompile(`(?i)` + numberPattern + `\s+jam\s+(yang\s+)?(lalu|sebelum)`)
	daysFuture    = regexp.MustCompile(`(?i)` + numberPattern + `\s+hari\s+(lagi|kemudian|kedepan)`)
	daysPast      = regexp.MustCompile(`(?i)` + numberPattern + `\s+hari\s+(yang\s+)?(lalu|sebelum)`)
)

var numberWords = map[string]int{
	"satu": 1, "dua": 2, "tiga": 3, "empat": 4, "lima": 5, "enam": 6,
	"tujuh": 7, "delapan": 8, "sembilan": 9, "sepuluh": 10, "sebelas": 11, "dua belas": 12,
}

func (h *Handler) Ask(ctx context.Context, req AskRequest) (Answer, error) {
	question := normalize(req.Question)
	if question == "" {
		return Answer{}, errors.New("pertanyaan tidak boleh kosong")
	}

	loc := requestLocation(req)
	now := time.Now().In(loc)

	if answer, ok := relativeTimeAnswer(question, now); ok {
		return Answer{Answer: answer, Intent: "time_relative"}, nil
	}
	if answer, ok := relativeDateAnswer(question, now); ok {
		return Answer{Answer: answer, Intent: "date_relative"}, nil
	}

	switch {
	case hasAny(question, "cuaca", "hujan", "suhu", "prakiraan", "cerah", "berawan"):
		if req.Latitude == nil || req.Longitude == nil || *req.Latitude < -90 || *req.Latitude > 90 || *req.Longitude < -180 || *req.Longitude > 180 {
			return Answer{Answer: "Untuk mengecek cuaca, ALICE memerlukan izin lokasi perangkat Anda.", Intent: "weather"}, nil
		}
		answer, err := h.weather(ctx, *req.Latitude, *req.Longitude)
		return Answer{Answer: answer, Intent: "weather"}, err
	case isLocationQuestion(question):
		name := strings.TrimSpace(req.LocationName)
		if name != "" {
			return Answer{Answer: fmt.Sprintf("Anda sedang berada di sekitar %s.", name), Intent: "location"}, nil
		}
		if req.Latitude != nil && req.Longitude != nil && *req.Latitude >= -90 && *req.Latitude <= 90 && *req.Longitude >= -180 && *req.Longitude <= 180 {
			return Answer{Answer: fmt.Sprintf("Anda berada di sekitar koordinat %.4f, %.4f.", *req.Latitude, *req.Longitude), Intent: "location"}, nil
		}
		return Answer{Answer: "Untuk mengetahui lokasi Anda, ALICE memerlukan izin lokasi perangkat.", Intent: "location"}, nil
	case hasAny(question, "jam berapa", "pukul berapa", "waktu sekarang", "sekarang jam", "jam sekarang"):
		return Answer{Answer: fmt.Sprintf("Sekarang pukul %s.", now.Format("15.04")), Intent: "time"}, nil
	case hasAny(question, "tanggal berapa", "hari apa", "tanggal hari ini", "hari ini tanggal", "tanggal sekarang"):
		return Answer{Answer: fmt.Sprintf("Hari %s, %d %s %d.", dayNames[now.Weekday()], now.Day(), monthNames[now.Month()-1], now.Year()), Intent: "date"}, nil
	case hasAny(question, "halo", "hai", "selamat pagi", "selamat siang", "selamat sore", "selamat malam"):
		return Answer{Answer: "Halo, saya ALICE. Ada yang bisa saya bantu?", Intent: "greeting"}, nil
	case hasAny(question, "siapa kamu", "kamu siapa", "apa itu alice", "nama kamu"):
		return Answer{Answer: "Saya ALICE, asisten suara yang siap membantu Anda.", Intent: "identity"}, nil
	case hasAny(question, "terima kasih", "makasih", "terimakasih"):
		return Answer{Answer: "Sama-sama. Senang bisa membantu Anda.", Intent: "thanks"}, nil
	case hasAny(question, "ulangi", "katakan lagi", "tidak dengar", "tidak terdengar"):
		return Answer{Answer: "Tentu. Silakan tanyakan kembali hal yang ingin Anda ketahui.", Intent: "repeat"}, nil
	case hasAny(question, "bantuan", "bisa apa", "bisa membantu", "cara menggunakan"):
		return Answer{Answer: "Anda bisa bertanya tentang waktu, tanggal, cuaca, atau lokasi Anda saat ini.", Intent: "help"}, nil
	default:
		return Answer{Answer: "Maaf, saya belum memahami pertanyaan itu. Anda bisa bertanya tentang waktu, tanggal, cuaca, atau lokasi.", Intent: "fallback"}, nil
	}
}

func relativeTimeAnswer(question string, now time.Time) (string, bool) {
	if m := minutesFuture.FindStringSubmatch(question); m != nil {
		if n, ok := parseNumberWord(m[1]); ok {
			return relativeClockAnswer(now, time.Duration(n)*time.Minute, fmt.Sprintf("%d menit lagi", n)), true
		}
	}
	if m := minutesPast.FindStringSubmatch(question); m != nil {
		if n, ok := parseNumberWord(m[1]); ok {
			return relativeClockAnswer(now, -time.Duration(n)*time.Minute, fmt.Sprintf("%d menit yang lalu", n)), true
		}
	}
	if m := hoursFuture.FindStringSubmatch(question); m != nil {
		if n, ok := parseNumberWord(m[1]); ok {
			return relativeClockAnswer(now, time.Duration(n)*time.Hour, fmt.Sprintf("%d jam lagi", n)), true
		}
	}
	if m := hoursPast.FindStringSubmatch(question); m != nil {
		if n, ok := parseNumberWord(m[1]); ok {
			return relativeClockAnswer(now, -time.Duration(n)*time.Hour, fmt.Sprintf("%d jam yang lalu", n)), true
		}
	}

	past := hasAny(question, "yang lalu", "lalu", "sebelum")
	switch {
	case strings.Contains(question, "setengah jam"):
		if past {
			return relativeClockAnswer(now, -30*time.Minute, "30 menit yang lalu"), true
		}
		return relativeClockAnswer(now, 30*time.Minute, "30 menit lagi"), true
	case strings.Contains(question, "seperempat jam"):
		if past {
			return relativeClockAnswer(now, -15*time.Minute, "15 menit yang lalu"), true
		}
		return relativeClockAnswer(now, 15*time.Minute, "15 menit lagi"), true
	case strings.Contains(question, "sejam") || strings.Contains(question, "satu jam"):
		if past {
			return relativeClockAnswer(now, -time.Hour, "1 jam yang lalu"), true
		}
		return relativeClockAnswer(now, time.Hour, "1 jam lagi"), true
	}
	return "", false
}

func relativeClockAnswer(now time.Time, delta time.Duration, label string) string {
	target := now.Add(delta)
	return fmt.Sprintf("Sekarang pukul %s. %s pukul %s.", now.Format("15.04"), label, target.Format("15.04"))
}

func relativeDateAnswer(question string, now time.Time) (string, bool) {
	switch {
	case hasAny(question, "kemarin lusa", "kemarin dulu"):
		return relativeDayAnswer(now, -2, "Kemarin lusa"), true
	case strings.Contains(question, "besok lusa"):
		return relativeDayAnswer(now, 2, "Besok lusa"), true
	}
	if m := daysFuture.FindStringSubmatch(question); m != nil {
		if n, ok := parseNumberWord(m[1]); ok && n > 0 {
			return relativeDayAnswer(now, n, fmt.Sprintf("%d hari lagi", n)), true
		}
	}
	if m := daysPast.FindStringSubmatch(question); m != nil {
		if n, ok := parseNumberWord(m[1]); ok {
			return relativeDayAnswer(now, -n, fmt.Sprintf("%d hari yang lalu", n)), true
		}
	}
	switch {
	case strings.Contains(question, "lusa"):
		return relativeDayAnswer(now, 2, "Lusa"), true
	case strings.Contains(question, "besok"):
		return relativeDayAnswer(now, 1, "Besok"), true
	case strings.Contains(question, "kemarin"):
		return relativeDayAnswer(now, -1, "Kemarin"), true
	}
	return "", false
}

func relativeDayAnswer(now time.Time, days int, label string) string {
	target := now.AddDate(0, 0, days)
	return fmt.Sprintf("%s adalah hari %s, %d %s %d.", label, dayNames[target.Weekday()], target.Day(), monthNames[target.Month()-1], target.Year())
}

func parseNumberWord(s string) (int, bool) {
	s = strings.Join(strings.Fields(strings.ToLower(s)), " ")
	if n, err := strconv.Atoi(s); err == nil && n >= 0 {
		return n, true
	}
	n, ok := numberWords[s]
	return n, ok
}

func isLocationQuestion(question string) bool {
	return hasAny(question, "dimana", "di mana", "lokasi saya", "posisi saya")
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
