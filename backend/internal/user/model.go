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
}

// Soal `json:"-"` pada Password:
//
// Tanda itu artinya "JANGAN pernah ikut dikirim sebagai JSON".
// Tanpa itu, siapa pun yang memanggil API bisa melihat hash password
// semua pengguna. Ini kesalahan yang sering terjadi dan berbahaya.

// Profile adalah gabungan data akun dan data profil pendamping.
//
// Kenapa digabung? Karena halaman profil di aplikasi membutuhkan keduanya
// sekaligus: nama & email dari tabel "user", telepon & alamat dari tabel
// "companion". Menggabungkannya di satu query menghindari dua perjalanan
// ke database untuk satu layar.
//
// Untuk pengguna tunanetra, PhoneNumber dan Address bernilai nil karena
// tabel "visually_impaired" tidak punya kolom itu.
type Profile struct {
	UserID      string  `json:"user_id"`
	Name        string  `json:"name"`
	Email       *string `json:"email,omitempty"`
	Role        string  `json:"role"`
	PhoneNumber *string `json:"phone_number,omitempty"`
	Address     *string `json:"address,omitempty"`
}

// CreateInput adalah bahan untuk membuat pengguna baru.
//
// Kenapa User dan data profil dipisah, bukan ditambahkan ke struct User?
// Karena struct User adalah cerminan tabel "user". Menaruh phone_number
// di sana akan menyesatkan: kolom itu tidak ada di tabel "user", melainkan
// di tabel "companion".
type CreateInput struct {
	User        *User
	PhoneNumber *string
	Address     *string
}
