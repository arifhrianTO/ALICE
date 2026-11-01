package user

// User adalah cerminan tabel public."user" di database.
//
// Padanan Laravel: `app/Models/User.php`.
//
// Bedanya besar dengan Laravel: di sini TIDAK ADA Eloquent. Struct ini
// hanya wadah data. Semua query SQL ditulis manual di `repository/`.
//
// Nama field mengikuti kolom tabel. Urutannya juga sama, supaya mudah
// dicocokkan saat membaca kode.

// Peran pengguna. Nilai ini HARUS sama persis dengan enum `user_role`
// di PostgreSQL. Salah satu huruf saja -> PostgreSQL menolak.
const (
	RoleTunanetra  = "tunanetra"
	RolePendamping = "pendamping"
)

// Cara pengguna masuk. Harus sama dengan enum `auth_provider_type`.
const (
	AuthProviderEmail    = "email"
	AuthProviderGoogle   = "google"
	AuthProviderFacebook = "facebook"
)

type User struct {
	UserID string `json:"user_id"`
	Role   string `json:"role"`

	// Tiga field di bawah boleh KOSONG (NULL) di database, jadi tipenya
	// pointer. Kenapa pointer? Karena `string` biasa tidak bisa bernilai
	// NULL. Kalau dipaksa, saat membaca baris yang NULL, aplikasi error:
	//   cannot scan NULL into *string
	//
	// Dengan pointer, NULL terbaca sebagai `nil`, dan aman.
	Email      *string `json:"email,omitempty"`
	Password   *string `json:"-"`
	ProviderID *string `json:"provider_id,omitempty"`

	AuthProvider string `json:"auth_provider"`
	Name         string `json:"name"`

	// Profil pendamping (dari tabel companion)
	PhoneNumber string `json:"phone_number,omitempty"`
	Address     string `json:"address,omitempty"`
}

// Soal `json:"-"` pada Password:
//
// Tanda itu artinya "JANGAN pernah ikut dikirim sebagai JSON".
// Tanpa itu, siapa pun yang memanggil API bisa melihat hash password
// semua pengguna. Ini kesalahan yang sering terjadi dan berbahaya.
