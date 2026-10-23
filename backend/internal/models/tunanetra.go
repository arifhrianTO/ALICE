package models

type Tunanetra struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Email       string  `json:"email"`
	Latitude    float64 `json:"latitude"`
	Longitude   float64 `json:"longitude"`
	Address     string  `json:"address"`
	Battery     string  `json:"battery"`
	Temperature string  `json:"temperature"`
}
