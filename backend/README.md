# Backend ALICE

Server API untuk aplikasi ALICE. Ditulis dengan bahasa **Go**, memakai database **PostgreSQL**.

> **Status: M0 + M1 (register & login) SELESAI.** Konfigurasi, koneksi PostgreSQL,
> router Gin, `/api/health`, `POST /api/auth/register`, dan `POST /api/auth/login`
> sudah jalan dan teruji sungguhan. Yang belum: proteksi token (M2) dan
> penyambungan ke Flutter.
> Satu file masih kerangka, ditandai **KERANGKA** di peta folder:
> `internal/shared/middleware/auth.go`.

---

## Daftar isi

1. [Ringkasan kondisi saat ini](#1-ringkasan-kondisi-saat-ini)
2. [Analogi: satu pesanan dari HP sampai gudang](#2-analogi-satu-pesanan-dari-hp-sampai-gudang)
3. [Peta folder](#3-peta-folder)
4. [Penjelasan tiap folder](#4-penjelasan-tiap-folder)
5. [Aturan arsitektur](#5-aturan-arsitektur)
6. [Kamus istilah](#6-kamus-istilah)
7. [Database](#7-database)
8. [Daftar endpoint](#8-daftar-endpoint)
9. [Cara menjalankan](#9-cara-menjalankan)
10. [Rencana bertahap](#10-rencana-bertahap)
11. [Jebakan yang sudah diketahui](#11-jebakan-yang-sudah-diketahui)

---

## 1. Ringkasan kondisi saat ini

### Sudah ada

| Hal | Keterangan |
|---|---|
| Server HTTP | jalan di port dari `.env` (`8080`) |
| Routing dasar | **Gin** (`github.com/gin-gonic/gin`) |
| Endpoint | auth, profil, pengajuan tautan, pencarian tunanetra, notifikasi — lihat [bagian 8](#8-daftar-endpoint) |
| Middleware | CORS + Recovery + Logger (Gin) + Auth (token sesi) |
| Konfigurasi | `.env` dibaca lewat `godotenv`, divalidasi di `shared/config/` |
| Koneksi database | `pgxpool` + `Ping`, berhenti jelas kalau DB mati |
| Makefile | ✅ pengganti `php artisan` |
| Seeder | ✅ `make seed` (memperbarui akun uji & password bcrypt) |
| Bentuk balasan API | ✅ `response.Response` untuk endpoint baru |
| Register & Login | ✅ `POST /api/auth/register` & `POST /api/auth/login` |
| Pengajuan tautan | ✅ pendamping mengajukan, tunanetra menerima/menolak (`Menunggu` → `Terhubung`/`Ditolak`) |
| Push notification | ✅ dikirim lewat FCM saat pengajuan dibuat |
| Data | ✅ seluruhnya dari database, tidak ada lagi data dummy |

### Belum ada

| Hal | Keterangan |
|---|---|
| Middleware auth | ✅ `shared/middleware/auth.go` memeriksa `Authorization: Bearer` |
| Endpoint yang dilindungi token | ✅ `GET`/`PUT /api/profile`, `/api/requests*`, `/api/tunanetra/*`, `/api/device-tokens` |
| Data perangkat tunanetra | ❌ lokasi/baterai/suhu di beranda masih diisi contoh (app tunanetra belum mengirimnya) |
| Penyambungan auth ke Flutter | ✅ `email_login_page.dart` sudah panggil `/api/auth/register` & `/api/auth/login` |
| Bentuk database di repo | ❌ tidak disimpan (lihat bagian 4) |

**Kesimpulan:** fondasi berdiri; autentikasi, pengajuan tautan, dan push
notification sudah jalan. Yang belum: pengiriman data perangkat dari app
tunanetra ke server.

### Tidak ada lagi file kerangka

Semua berkas inti sudah berisi implementasi penuh, termasuk
`internal/shared/middleware/auth.go` yang memeriksa token sesi pada setiap
endpoint terlindungi.

| Berkas | Isi |
|---|---|
| `shared/config/config.go` | baca `.env` |
| `shared/database/postgres.go` | buka connection pool |
| `shared/middleware/auth.go` | periksa token sesi (`Authorization: Bearer`) |
| `user/repository.go` | SQL tabel `user` + tabel profilnya |
| `auth/repository.go` | SQL tabel `session` |
| `auth/service.go` | aturan bisnis pendaftaran |
| `auth/dto.go`, `auth/handler.go` | bentuk JSON + lapisan HTTP |

### Tombol "Masuk" dan "Daftar" di Flutter sudah tersambung

`frontend/lib/features/auth/email_login_page.dart` **sudah memanggil backend**.
- Mode daftar (`isRegister == true`) memanggil `POST /api/auth/register`.
- Mode masuk (`isRegister == false`) memanggil `POST /api/auth/login`.
- Alamat baseUrl diambil dari `core/api_config.dart` (`http://localhost:8080` untuk desktop/web atau `http://10.0.2.2:8080` untuk emulator Android).
- Bila sukses: token disimpan ke `SharedPreferences` (`session_token`) bersama `user_role`, `user_name`, dan `user_email`.
- Bila gagal: pesan error dari API langsung ditampilkan di bawah kolom isian.

---

## 2. Analogi: satu pesanan dari HP sampai gudang

Anggap aplikasi ALICE sebagai **restoran**. Berikut yang terjadi saat seorang
pengguna menekan tombol **"Masuk"** di aplikasi Flutter.

```text
   HP pengguna (Flutter)
   │   mengetuk pintu :8080
   ▼
   ┌──────────────┐
   │   SATPAM     │  middleware/   cek asal pesanan (CORS), cek gelang (auth)
   └──────┬───────┘
          ▼
   ┌──────────────┐
   │   PELAYAN    │  handlers/     baca kertas pesanan, sampaikan hasilnya
   └──────┬───────┘
          ▼
   ┌──────────────┐
   │    KOKI      │  service/      tahu resep: "cari user, cocokkan password"
   └──────┬───────┘
          ▼
   ┌──────────────┐
   │ JURU GUDANG  │  repository/   satu-satunya yang boleh masuk gudang (SQL)
   └──────┬───────┘
          ▼
   ┌──────────────┐
   │   GUDANG     │  PostgreSQL    data yang sebenarnya
   └──────────────┘
```

### Peran masing-masing

**Gudang** — tempat bahan disimpan. Isinya rak-rak berlabel: rak `user`,
rak `session`, rak `schedule`. Bentuk rak itu disebut **skema**.

**Dapur (backend)** — pelanggan **tidak boleh** masuk gudang sendiri. Kalau
boleh, dia harus memegang kunci gudang, dan kunci itu harus ditanam di dalam
aplikasi yang bisa dibongkar orang. Jadi ada dapur sebagai perantara.

**Menu (API)** — kesepakatan antara pelanggan dan dapur. Daftar pesanan yang
boleh diminta beserta formatnya. Kalau frontend memesan sesuatu yang tidak ada
di menu, dapur menolak.

**Nomor pintu (port)** — dapur ada di pintu **8080**. Ketuk pintu lain, tidak
ada yang menjawab. `localhost` artinya "dapur yang ada di gedung ini sendiri"
(laptopmu), bukan gedung orang lain.

**Satpam (middleware)** — mengurus hal yang berlaku untuk *semua* pesanan:
cek asal pesanan, catat siapa yang lewat, periksa gelang. Kalau satpam menolak,
pesanan tidak pernah sampai ke koki.

**Pelayan (handler)** — menerima kertas pesanan, memastikan formatnya benar,
lalu menyerahkan ke koki. **Pelayan tidak memasak.** Dia juga yang menyampaikan
penolakan dengan sopan (misal "maaf, tidak tersedia" = status `404`).

**Koki (service)** — yang tahu resep. Resep login misalnya: *"cari pelanggan
dengan email ini, cocokkan passwordnya, kalau cocok buatkan gelang."* Koki
**tidak tahu** bahan disimpan di rak mana, dan tidak peduli.

**Juru gudang (repository)** — yang tahu persis rak dan laci. **Dia
satu-satunya yang boleh masuk gudang.** Semua urusan query SQL ada di sini.

**Juru gudang yang sudah siap (connection pool)** — membuka pintu gudang itu
lambat. Jadi beberapa juru gudang "sudah berdiri siap" dan bergiliran melayani.
Itulah connection pool.

**Gelang (session token)** — setelah login berhasil, pengguna tidak
terus-menerus membawa password. Dia diberi gelang, dan gelang itu dicatat di
buku depan. Kalau dia pulang, catatannya dicoret — gelangnya jadi tidak berlaku.

**Loker (file `.env`)** — dapur perlu tahu alamat gudang dan kuncinya.
Informasi itu tidak ditempel di dinding (ditulis keras di kode), karena alamat
gudang di laptop berbeda dengan di server produksi. Disimpan di loker supaya
tinggal ganti isinya. Loker **tidak boleh difoto** (tidak di-commit ke Git)
karena isinya kunci.

---

## 3. Peta folder

```text
backend/
├── cmd/
│   ├── server/
│   │   └── main.go              ← ✅ pintu masuk: config → db → routes → jalan
│   └── seed/
│       └── main.go              ← ✅ isi data uji (padanan db:seed)
│
├── internal/                    ← kode pendukung (privat, dijaga compiler Go)
│   │
│   ├── shared/                  ← BARANG BERSAMA (tidak dimiliki fitur mana pun)
│   │   ├── config/
│   │   │   └── config.go        ← ✅ baca .env jadi struct Config
│   │   ├── database/
│   │   │   └── postgres.go      ← ✅ buka connection pool + ping
│   │   ├── response/
│   │   │   └── response.go      ← ✅ bentuk baku balasan API
│   │   └── middleware/
│   │       ├── cors.go          ← ✅ satpam: CORS (versi Gin)
│   │       └── auth.go          ← KERANGKA: satpam token (M2)
│   │
│   ├── server/
│   │   └── routes.go            ← ✅ peta seluruh API (padanan routes/api.php)
│   │
│   ├── system/                  ← endpoint teknis, bukan fitur bisnis
│   │   ├── health.go            ← ✅ cek server + database
│   │   └── hello.go             ← ✅ uji cepat "server hidup?"
│   │
│   ├── user/                    ← FITUR: tabel "user" + tabel profilnya
│   │   ├── model.go             ← ✅ cerminan tabel "user"
│   │   └── repository.go        ← ✅ SQL tabel user, companion, visually_impaired
│   │
│   ├── profile/                 ← FITUR: profil pengguna (baca & ubah)
│   │   ├── service.go           ← ✅ aturan bisnis profil
│   │   ├── dto.go               ← ✅ bentuk JSON permintaan & balasan
│   │   └── handler.go           ← ✅ handler HTTP
│   │
│   ├── auth/                    ← FITUR: daftar, masuk, keluar
│   │   ├── model.go             ← ✅ cerminan tabel "session"
│   │   ├── repository.go        ← ✅ SQL tabel session
│   │   ├── service.go           ← ✅ aturan bisnis: validasi, bcrypt, token
│   │   ├── dto.go               ← ✅ bentuk JSON permintaan & balasan
│   │   └── handler.go           ← ✅ handler HTTP
│   │
│   ├── tunanetra/               ← FITUR: daftar akun & pencarian tunanetra
│   │   ├── handler.go           ← ✅ handler daftar akun tunanetra
│   │   ├── repository.go        ← ✅ SQL pencarian tunanetra
│   │   ├── service.go           ← ✅ aturan bisnis daftar akun
│   │   └── search_handler.go    ← ✅ handler pencarian tunanetra
│   │
│   ├── request/                 ← FITUR: pengajuan tautan pendamping ↔ tunanetra
│   │   ├── model.go             ← ✅ bentuk pengajuan + permintaan masuk
│   │   ├── repository.go        ← ✅ SQL tabel "request"
│   │   ├── service.go           ← ✅ aturan bisnis + kirim notifikasi
│   │   ├── dto.go               ← ✅ bentuk JSON permintaan & balasan
│   │   └── handler.go           ← ✅ handler HTTP
│   │
│   ├── notification/            ← FITUR: push notification (FCM)
│   │   ├── model.go             ← ✅ cerminan tabel "device_token"
│   │   ├── repository.go        ← ✅ SQL tabel device_token
│   │   ├── service.go           ← ✅ aturan bisnis + kirim ke perangkat
│   │   ├── fcm.go               ← ✅ pengirim Firebase Cloud Messaging
│   │   ├── dto.go               ← ✅ bentuk JSON permintaan & balasan
│   │   └── handler.go           ← ✅ handler HTTP
│   │
│   └── assistant/               ← FITUR: tanya-jawab asisten
│       ├── assistant.go         ← ✅ logika asisten
│       └── handler.go           ← ✅ handler HTTP
│
├── Makefile                     ← ✅ pengganti `php artisan`
├── .editorconfig                ← pengaturan dasar editor
├── .env                         ← konfigurasi lokal (TIDAK di-commit)
├── .env.example                 ← template isi .env
├── go.mod                       ← identitas project + daftar library
└── README.md                    ← file ini
```

Tanda **KERANGKA** berarti file itu sudah ada, tapi isinya baru nama fungsi
dan komentar `TODO` — belum ada implementasi. Rinciannya di
[bagian 4](#ringkasan-isi-tiap-file).

---

## 4. Penjelasan tiap folder

### `cmd/server/` — pintu masuk

Tempat program yang bisa dijalankan. Aturan komunitas Go: `cmd/` berisi
program, `internal/` berisi kode pendukung.

Isi `main.go` nantinya **sependek mungkin** — cuma 4 pekerjaan:

1. baca konfigurasi
2. sambung ke database
3. rakit daftar endpoint
4. nyalakan server

Kalau nanti ada tool tambahan (misal pengisi data awal), buat folder baru
`cmd/seed/`. Tidak dicampur ke sini.

### `internal/shared/` — barang bersama

**Isinya hal-hal yang tidak dimiliki fitur mana pun.** Analoginya: listrik, air,
dan piring di sebuah gedung berisi banyak stan. Semua stan memakainya, tapi
tidak ada satu stan pun yang bisa mengaku "ini punyaku".

Kenapa harus ada tempat terpisah? Bayangkan `config.go` ditaruh di dalam `auth/`:

```text
auth  →  user      (auth butuh tabel user)
user  →  auth      (user butuh config)        ❌ IMPORT CYCLE
```

Go **melarang** dua package saling mengimport. Jadi barang bersama **wajib**
punya tempat netral. Kalau tidak, kamu mentok di tengah jalan.

Cara memutuskan sesuatu masuk `shared/` atau masuk fitur:

> **Kalau fitur itu dihapus, apakah barang ini ikut terhapus?**
> Ikut terhapus → taruh di fiturnya. Masih dibutuhkan → `shared/`.

Aturan satu-satunya: **`shared/` tidak boleh mengimport fitur mana pun.** Dia
dasar piramida. Kalau aturan ini dilanggar, seluruh bangunan jadi cycle.

#### `shared/config/` — pembaca loker

Satu-satunya tempat yang membaca file `.env`. Setelah ini, **tidak ada satu pun
kode lain yang boleh memanggil `os.Getenv`**.

Kenapa begitu? Supaya kalau ada variabel yang salah, kamu tahu persis harus
melihat ke mana. Dan supaya variabel wajib bisa divalidasi sekali di awal —
kalau `DB_NAME` kosong, aplikasi berhenti dengan pesan jelas, bukan error aneh
di tengah request.

#### `shared/database/` — pembuka gudang

Tugasnya membuka **connection pool** dan memastikan database benar-benar hidup
(`Ping`).

Perlu dijelaskan: `pgxpool` itu **lazy** — dia tidak langsung connect, cuma
menyiapkan wadah. Tanpa `Ping`, server bisa "berhasil start" padahal database
mati, dan baru meledak saat pengguna pertama login. Dengan `Ping`, error
ketahuan sedetik itu juga, saat start.

#### `shared/response/` — piring standar

Bentuk baku balasan API. Semua endpoint **baru** memakai amplop yang sama:

```json
{ "success": true, "message": "...", "data": { } }
```

Kalau bentuk ini berubah, berubah untuk semua — dan itu memang yang diinginkan.

#### `shared/middleware/` — satpam gedung

Fungsi yang **membungkus** handler lain:

| Middleware | Tugas |
|---|---|
| CORS | menentukan alamat mana yang boleh mengakses API |
| Logger | mencatat setiap request ke terminal (dari Gin) |
| Auth | memeriksa gelang (token) sebelum request diteruskan — KERANGKA (M2) |

### `internal/server/` — peta API

Satu file: `routes.go`. **Satu-satunya tempat endpoint didaftarkan.** Jadi kalau
ada yang bertanya *"API project ini ada apa saja?"*, jawabannya satu file, bukan
hasil pencarian:

```go
api := r.Group("/api")
api.GET("/hello", system.Hello)
api.GET("/tunanetra", tunanetra.List)
api.GET("/health", health.Check)
```

Pola "satu file berisi peta seluruh API" ini juga yang dipakai Mat Ryer — lihat
[inspirasi dari luar](#inspirasi-dari-luar).

### `internal/system/` — endpoint teknis

Endpoint yang **bukan fitur bisnis**, tapi dibutuhkan operasional:

| File | Endpoint | Guna |
|---|---|---|
| `health.go` | `GET /api/health` | cek server + database hidup (503 kalau database mati) |
| `hello.go` | `GET /api/hello` | uji cepat "server hidup?" |

### Cara mengelompokkan: per lapisan vs per fitur

Ini keputusan struktur yang paling penting di project ini. Ada dua cara, dan
keduanya sah:

**Cara lama — per lapisan** (dulu dipakai, sekarang ditinggalkan):

```text
handlers/   service/   repository/   models/    ← dikelompokkan menurut JENIS
```

**Cara sekarang — per fitur:**

```text
auth/   user/   tunanetra/                      ← dikelompokkan menurut FITUR
```

Perhatikan: **lapisannya tidak hilang.** `handler → service → repository` tetap
ada, hanya sekarang berada **di dalam** folder fiturnya. Yang berubah cuma
"lemari mana yang menampung", bukan isinya.

| Pertanyaan | Per lapisan | Per fitur |
|---|---|---|
| "Semua soal login ada di mana?" | tersebar di 3 folder | **satu folder: `auth/`** |
| "Cara hapus fitur X?" | hapus baris di 3 folder | hapus 1 folder |
| "Nama package-nya enak?" | `service.AuthService` (dobel) | `auth.Service` |
| Bisa saling import antar fitur? | bebas, rawan cycle | dibatasi oleh `shared/` |

Alasan memilih per fitur:

1. **Mudah dicari** — semua soal satu fitur ada di satu tempat.
2. **Batasnya nyata** — package di Go memaksa aturan, bukan cuma kesepakatan.
3. **Mudah dihapus / dipisah** — fitur bisa jadi layanan terpisah kelak.
4. **Nama lebih bersih** — `auth.Service`, bukan `service.AuthService`.

Konsekuensi yang wajib diingat: **fitur tidak boleh saling import dua arah.**
Arah yang boleh hanya satu arah, dan yang dipakai bersama naik ke `shared/`:

```text
        cmd/server
             │
             ▼
      internal/server            ← peta API
       │       │        │
       ▼       ▼        ▼
    system   auth   tunanetra
               │
               ▼
             user
               │
               ▼
     internal/shared/*          ← dasar piramida, TIDAK import fitur
```

### Fitur: `auth/`, `user/`, `tunanetra/`

Satu fitur berisi sampai **tiga lapis** dengan peran yang sama seperti dulu:

| Lapis | Peran | Analogi | Contoh |
|---|---|---|---|
| `handler.go` | baca request, tulis response | pelayan | `auth/handler.go` |
| `service.go` | aturan bisnis | koki | `auth/service.go` |
| `repository.go` | SQL | juru gudang | `user/repository.go` |
| `model.go` | bentuk data | cetakan | `user/model.go` |

Aturannya tetap: **SQL tidak boleh keluar dari `repository`**, dan `handler`
tidak boleh melompati `service`.

Fitur yang ada sekarang:

| Fitur | Isi | Status |
|---|---|---|
| `user/` | cerminan tabel `user` + kontrak SQL | ✅ jalan |
| `auth/` | logika daftar & masuk | ✅ jalan |
| `tunanetra/` | daftar akun & pencarian tunanetra | ✅ jalan |
| `request/` | pengajuan tautan + permintaan masuk | ✅ jalan |
| `notification/` | token perangkat + pengiriman FCM | ✅ jalan |

**Kenapa `user/` terpisah dari `auth/`?** Karena keduanya menjawab pertanyaan
berbeda: `user/` soal *bentuk dan penyimpanan* data pengguna, `auth/` soal
*proses* daftar dan masuk. `auth/` boleh memakai `user/` (satu arah), tapi tidak
sebaliknya.

### Struct dan struct tag

Struct Go mencerminkan tabel database:

```go
type Tunanetra struct {
    ID       string  `json:"id"`
    Latitude float64 `json:"latitude"`
}
```

Bagian `` `json:"id"` `` disebut **struct tag**. Tanpa itu, Flutter akan membaca
`Latitude` (huruf besar) dan tidak menemukan `latitude`. Jadi tag ini wajib.

### Padanan Laravel: satu Eloquent Model dipecah jadi dua

Ini sumber kebingungan yang paling sering muncul kalau kamu datang dari Laravel.

Eloquent Model sebenarnya mengerjakan **dua tugas sekaligus**:

```php
// 1. menyimpan data (atribut)
$user->name = 'Budi';
echo $user->email;

// 2. bisa menyimpan dirinya sendiri (query)
$user->save();
User::where('email', $email)->first();
```

Di project ini dua tugas itu **dipisah**:

| Tugas | Laravel | Di sini |
|---|---|---|
| Menyimpan data (atribut) | `User` (property) | `user.User` (struct) |
| Query & simpan ke database | `User::where()`, `$user->save()` | `user.Repository` |

Perhatikan: keduanya sekarang berada di **folder yang sama**, `internal/user/`.
Satu folder fitur itulah pengganti satu Eloquent Model. Kalau ada yang bertanya
"mana model-nya?", jawabannya dua-duanya.

Perbandingan langsung:

**Laravel**

```php
$user = User::where('email', $email)->first();
$user->password = Hash::make($password);
$user->save();
```

**Project ini**

```go
u, err := userRepo.FindByEmail(ctx, email)       // user/repository.go (SQL)
hash, err := bcrypt.GenerateFromPassword(...)    // auth/service.go (aturan)
u.Password = &hashStr
err = userRepo.Update(ctx, u)                    // user/repository.go (SQL)
```

Perbedaan filosofinya:

| | Laravel (Eloquent) | Project ini (Repository) |
|---|---|---|
| Disebut | **Active Record** | **Repository** |
| Objek tahu cara menyimpan diri? | ✅ `$user->save()` | ❌ struct tidak punya method |
| Yang menyimpan | objek itu sendiri | repository |
| Query tersembunyi? | sering (relasi / lazy load) | tidak, semua SQL tertulis |
| Saat diuji | butuh database | repository bisa diganti tiruan |

Di Eloquent, `$user->sessions()->delete()` adalah satu baris — tapi SQL-nya tidak
terlihat. Di sini SQL-nya harus ditulis, jadi selalu kelihatan:

```go
const q = `DELETE FROM session WHERE user_id = $1`
_, err := r.pool.Exec(ctx, q, userID)
```

Lebih banyak ketik, tapi **tidak ada kejutan**.

Istilah Laravel yang pindah ke mana:

| Di Eloquent | Di sini |
|---|---|
| `protected $table = 'user';` | ditulis di SQL: `FROM public."user"` |
| `protected $fillable = [...];` | tidak perlu, `INSERT` ditulis eksplisit |
| `protected $hidden = ['password'];` | `json:"-"` pada field `Password` |
| `protected $casts = [...];` | dikonversi saat `Scan` |
| `$user->save()` | `userRepo.Update(ctx, u)` |
| `User::find($id)` | `userRepo.FindByID(ctx, id)` |

### Gin bukan ORM — dan Go tidak memaksakan struktur

Kesalahpahaman yang wajar: karena di Laravel kata "framework" berarti semuanya
(routing + Eloquent + container), orang mengira Gin juga begitu.

**Gin hanya menangani HTTP**: router, middleware, membaca JSON, menulis JSON.
Gin **tidak tahu** apa itu model, tabel, atau database. Gin bahkan tidak tahu
kamu memakai PostgreSQL.

| Bagian | Laravel | Go (project ini) |
|---|---|---|
| Router | bawaan | **Gin** |
| Validasi isi request | Form Request | `binding` bawaan Gin + `service` |
| Akses database | Eloquent (bawaan) | **pgx + repository** (dipilih sendiri) |
| Container / DI | otomatis | manual di `main.go` |
| Migrasi | bawaan | tidak ada (keputusan project) |
| Seeder | bawaan | `cmd/seed` |

Artinya cara "memodelkan" data seperti ini **bukan aturan Gin**. Itu pilihan di
lapisan akses data. Gin tidak peduli kamu memakai repository, ORM, atau SQL
langsung di dalam handler.

Yang paling perlu dipisah dengan jelas: **Gin mengurus HTTP, bukan struktur
folder.** Dua hal ini terpisah total:

| Bila kamu ganti... | Yang berubah |
|---|---|
| Gin → Echo / chi | handler, middleware, `routes.go` — **saja** |
| pgx → GORM | `repository.go` dan `model.go` di tiap fitur — **saja** |
| per lapisan → per fitur | **hanya lokasi file & baris import** — logika tidak |

Pola yang umum di Go:

| Pola | Bentuk | Cocok untuk |
|---|---|---|
| Langsung | handler → database | prototipe / proyek sangat kecil |
| Berlapis (per jenis) | `handlers/`, `service/`, `repository/` | fitur sedikit, sedang belajar |
| **Fitur + `shared/`** (dipilih di sini) | `auth/`, `user/`, `shared/` | 5–15 fitur |
| ORM (GORM / ent) | handler → model ORM | ingin rasa Eloquent |
| Clean / hexagonal | `domain/` + adapter | proyek besar, banyak tim |

Project ini memilih **fitur + `shared/`** karena: skema database **sudah ada**
(tidak perlu ORM untuk membuatnya), aturan bisnisnya nyata (email unik, hash
password, masa berlaku token), dan tiap fitur jadi mudah dicari, diuji, dan
dihapus sendiri-sendiri.

**Perbedaan paling terasa dengan Laravel:** Laravel **memaksa** satu struktur.
Go **tidak memaksa apa pun** — kamu yang memilih, dan konsekuensinya kamu yang
menanggung. Itu sebabnya di Go ada banyak "cara yang benar", tergantung ukuran
dan umur project.

### Inspirasi dari luar

Susunan ini tidak dikarang sendiri. Empat sumber yang paling berpengaruh:

| Sumber | Yang diambil |
|---|---|
| [Kat Zien — *How Do You Structure Your Go Apps?*](https://github.com/katzien/go-structure-examples) · [video](https://www.youtube.com/watch?v=oL6JBUk6tj0) | contoh `modular` = per fitur. Dia membandingkan 5 gaya: flat, layered, modular, domain, domain-hex |
| [Mat Ryer — *How I write HTTP services in Go after 13 years*](https://grafana.com/blog/2024/02/09/how-i-write-http-services-in-go-after-13-years/) | `cmd/` + `internal/`; `routes.go` sebagai satu peta API |
| [Ben Johnson — *Standard Package Layout*](https://www.gobeyond.dev/standard-package-layout/) | peringatan soal **import cycle** kalau salah mengelompokkan |
| [bxcodec/go-clean-arch](https://github.com/bxcodec/go-clean-arch) (⭐10 rb) | contoh nyata pola hibrida: fitur + `shared/` |

Catatan jujur: talk Kat Zien sendiri berpesan *"don't treat them as gospel"* —
tidak ada satu struktur yang benar untuk semua project. Yang penting alasannya
jelas, dan itu yang coba dituliskan di bagian ini.

### Tidak ada folder `migrations/` — dan itu disengaja

Project ini **tidak menyimpan** bentuk database di repo. Tidak ada folder
`migrations/`, tidak ada golang-migrate, tidak ada file `.sql` skema.

**Alasannya:** aplikasi memakai `app_user`, dan user itu **tidak boleh mengubah
struktur tabel**. Semua yang berbau "mengubah bentuk database" sengaja dijauhkan
dari repo, supaya tidak ada yang tidak sengaja menjalankannya dengan user
aplikasi.

Yang bisa dilakukan `app_user` (sudah diuji, semuanya ditolak PostgreSQL):

| Percobaan | Hasil |
|---|---|
| `CREATE TABLE` | ❌ `ijin ditolak untuk skema public` |
| `ALTER TABLE` | ❌ `must be owner of table` |
| `DROP TABLE` | ❌ `must be owner of table` |
| `TRUNCATE` | ❌ `permission denied for table` |
| `SELECT` / `INSERT` / `UPDATE` / `DELETE` | ✅ boleh |

**Konsekuensinya, yang perlu kamu tahu:**

Kalau database-nya hilang (laptop rusak) atau ada rekan yang meng-clone repo,
bentuk database **tidak bisa dibuat ulang dari repo ini**. Satu-satunya cara
adalah meminta salinan skema dari database yang masih hidup.

Kalau suatu saat kamu butuh salinan itu, ada perintahnya:

```bash
make db-dump > skema.sql
```

Perintah ini **hanya membaca** — tidak mengubah apa pun, dan tidak butuh izin
admin. Hasilnya bisa disimpan di luar repo atau dikirim ke rekanmu.

### Ringkasan isi tiap file

File yang masih **kerangka** isinya hanya nama fungsi + komentar `TODO`, dan
badan fungsinya mengembalikan error `belum diimplementasikan`.

#### `internal/shared/config/config.go` — ✅ sudah berfungsi

| Isi | Keterangan |
|---|---|
| `type Config struct` | 9 field: `AppEnv`, `AppPort`, `DBHost`, `DBPort`, `DBUser`, `DBPassword`, `DBName`, `DBSSLMode`, `SessionTTLHours` |
| `func Load() (*Config, error)` | baca `.env` lewat `godotenv`, isi struct, konversi `SESSION_TTL_HOURS`, validasi field wajib |
| `func (c *Config) DSN() string` | rangkai alamat koneksi dalam format URL (aman untuk password kosong / karakter khusus) |
| `func getEnv(key, fallback string) string` | bungkus `os.LookupEnv` + beri nilai cadangan |

Urutan prioritas nilai: **environment sistem → isi `.env` → default di kode.**

#### `internal/shared/database/postgres.go` — ✅ sudah berfungsi

| Isi | Keterangan |
|---|---|
| `func Connect(ctx context.Context, dsn string) (*pgxpool.Pool, error)` | buat pool pgxpool, atur `MaxConns`/`MinConns`/`MaxConnLifetime`, lalu `Ping` dengan batas waktu 5 detik |

Karena `pgxpool` bersifat *lazy*, `Ping` wajib: tanpa itu server bisa
"berhasil start" padahal database mati.

#### `internal/server/routes.go` — ✅ sudah berfungsi

| Isi | Keterangan |
|---|---|
| `func Setup(db *pgxpool.Pool, cfg *config.Config) *gin.Engine` | rakit router Gin + seluruh dependency, pasang Logger + Recovery + CORS, daftarkan 4 endpoint |
| `r.NoRoute` | endpoint tak dikenal → 404 JSON |
| `r.NoMethod` | method salah → 405 JSON (bukan 404) |
| `r.Group("/api")` | semua endpoint berawalan `/api` |
| blok "Perakitan dependency" | repository → service → handler, disambung terang-terangan |
| blok komentar | daftar endpoint M1/M2 yang belum dibuat, dikomentari |

Signature `Setup` berubah dari `(db, appEnv string)` menjadi `(db, cfg)`: dia
sekarang juga butuh `SESSION_TTL_HOURS` untuk menentukan umur token login.

Catatan: `gin.SetMode(gin.ReleaseMode)` dipakai saat `APP_ENV=production`,
supaya log debug tidak berisik.

#### `internal/system/health.go` — ✅ sudah berfungsi

| Isi | Keterangan |
|---|---|
| `type HealthHandler struct` | menyimpan `*pgxpool.Pool` |
| `func NewHealthHandler(db)` | constructor (dependency injection) |
| `func (h *HealthHandler) Check(c)` | `Ping` database dengan batas 3 detik; 200 kalau hidup, **503** kalau mati |

Bedanya dengan `/api/hello`: endpoint ini **benar-benar menyentuh database**,
jadi hasilnya bisa dipercaya untuk pemantauan.

#### `internal/system/hello.go` — ✅ sudah berfungsi

| Isi | Keterangan |
|---|---|
| `func Hello(c *gin.Context)` | balas `{"message": "...", "app": "ALICE"}` |
| bentuk balasan | `response.InfoResponse` — bentuk **lama**, sengaja dipertahankan |

#### `internal/tunanetra/handler.go` — ✅ sudah berfungsi

| Isi | Keterangan |
|---|---|
| `func (h *Handler) ListAccounts(c *gin.Context)` | balas daftar akun tunanetra asli (halaman "Tautkan Tunanetra") |
| `func (h *SearchHandler) Search(c *gin.Context)` | balas hasil pencarian tunanetra dari database (`?q=`) |

Semua balasan di fitur ini memakai amplop baku `response.Response`.

#### `internal/shared/response/response.go` — ✅ sudah berfungsi

| Isi | Keterangan |
|---|---|
| `type Response` | bentuk baku: `success`, `message`, `data` |
| `func OK(message, data)` | balasan berhasil |
| `func Fail(message)` | balasan gagal |
| `type InfoResponse` | bentuk **lama** untuk `/api/hello`, sengaja dipertahankan |

#### `internal/user/model.go` — ✅ sudah berfungsi

| Isi | Keterangan |
|---|---|
| `type User struct` | cerminan tabel `public."user"` |
| `Email`, `Password`, `ProviderID` | bertipe pointer karena boleh `NULL` di database |
| `json:"-"` pada `Password` | hash password **tidak pernah** ikut terkirim ke klien |
| konstanta `Role*`, `AuthProvider*` | menghindari salah ketik nilai enum |

#### `internal/shared/middleware/cors.go` — ✅ sudah berfungsi (versi Gin)

| Isi | Keterangan |
|---|---|
| `func CORS() gin.HandlerFunc` | izin lintas alamat untuk aplikasi Flutter |
| `Access-Control-Allow-Headers` | menyertakan `Authorization` (untuk token M2) |
| `OPTIONS` | dijawab `204` lalu `c.AbortWithStatus()` |

#### `internal/shared/middleware/auth.go` — ⬜ masih kerangka (M2)

| Isi | Keterangan |
|---|---|
| `func Auth() gin.HandlerFunc` | TODO: baca `Authorization: Bearer`, cari di tabel `session`, simpan `user_id` ke context |
| sekarang | selalu menjawab `501`, supaya tidak ada endpoint yang dikira sudah terlindungi |

#### `internal/user/repository.go` — ✅ sudah berfungsi

| Isi | Keterangan |
|---|---|
| `type Repository interface` | kontrak akses tabel pengguna |
| `FindByEmail(ctx, email)` | cari pengguna; kalau tidak ada → `(nil, nil)`, bukan error. Disiapkan untuk login |
| `Create(ctx, u *User)` | simpan `user` **+ baris profilnya** dalam **satu transaksi** |
| `NewRepository(pool, cipher)` | constructor (dependency injection) |
| `var ErrEmailTaken` | terjemahan dari kode PostgreSQL `23505` (`unique_violation`) |
| `isUniqueViolation(err)` | memeriksa kode `23505` lewat `errors.As` |
| `profileInsertQuery(role)` | pilih tabel profil: `pendamping` → `companion`, `tunanetra` → `visually_impaired` |

Dua keputusan yang disengaja:

1. **Tidak ada `SELECT` pendahulu** untuk memeriksa email kembar. Pengecekan
   diserahkan ke aturan `UNIQUE` milik database, lalu penolakannya diterjemahkan
   menjadi `ErrEmailTaken`. Cara ini kebal "balapan": dua orang yang mendaftar
   dengan email sama pada milidetik yang sama tetap tertangkap, sedangkan
   pengecekan manual bisa sama-sama lolos.
2. **Satu transaksi** untuk dua tabel. Kalau penyimpanan profil gagal, baris
   `user` ikut batal — tidak akan lahir "pengguna tanpa profil".

Nama `Repository` saja (bukan `UserRepository`) karena nama package-nya sudah
`user`. Dibaca lengkap menjadi `user.Repository`.

#### `internal/auth/model.go` — ✅ sudah berfungsi

| Isi | Keterangan |
|---|---|
| `type Session struct` | cerminan tabel `session` (satu baris = satu perangkat yang login) |
| `func (s *Session) IsExpired() bool` | apakah sesi sudah lewat batas waktunya |

Tabel `session` ditaruh di fitur `auth`, bukan `user`. Alasannya pertanyaan
kepemilikan: *"kalau fitur ini dihapus, apakah barang ini ikut terhapus?"*
Tabel `session` ada **hanya** karena ada login — jadi dia milik `auth`.

#### `internal/auth/repository.go` — ✅ sudah berfungsi

| Isi | Keterangan |
|---|---|
| `type SessionRepository interface` | kontrak akses tabel `session` |
| `Create(ctx, s *Session)` | simpan sesi login |
| `NewSessionRepository(pool)` | constructor |

Kolom `request_at` sengaja **tidak** diisi: database sudah punya nilai bawaan
`CURRENT_TIMESTAMP`.

#### `internal/auth/service.go` — ✅ sudah berfungsi

| Isi | Keterangan |
|---|---|
| `const PasswordMinLength = 6` | sama dengan aturan di Flutter — tapi tetap diperiksa di sini, karena pemeriksaan di klien bisa dilewati |
| `const bcryptCost` | `bcrypt.DefaultCost` (10), sama dengan seeder |
| `var emailPattern` | pola bentuk email; dikompilasi **sekali** di luar fungsi |
| `type ValidationError` | error berpesan ramah-pengguna (dipakai untuk `400`) |
| `var ErrEmailTaken` | error milik `auth`; diterjemahkan dari `user.ErrEmailTaken` |
| `type Service struct` | menyimpan 2 repository + `ttl`. Tidak ada variabel global |
| `func NewService(users, sessions, ttl)` | constructor — dependency injection tanpa framework |
| `func (s *Service) Register(ctx, in)` | validasi → hash bcrypt → simpan → buat token → simpan sesi |
| `func validateRegister(in)` | memeriksa **sekaligus merapikan** (`TrimSpace`, email jadi huruf kecil) |
| `func newToken()` | 32 byte acak dari `crypto/rand`, ditulis jadi 64 huruf heksadesimal |

Dua catatan penting:

- **Password tidak dirapikan** dengan `TrimSpace`. Spasi di awal atau akhir
  password adalah bagian sah dari password itu sendiri; merapikannya diam-diam
  membuat pengguna tidak bisa login padahal dia mengetik persis seperti saat
  mendaftar.
- **`crypto/rand`, bukan `math/rand`.** Angka dari `math/rand` bisa ditebak kalau
  keadaan awalnya diketahui — untuk token login itu sama saja dengan pintu yang
  tidak terkunci.

#### `internal/auth/dto.go` — ✅ sudah berfungsi

| Isi | Keterangan |
|---|---|
| `type RegisterRequest` | bentuk JSON yang diterima |
| `type UserResponse` | data pengguna yang **aman** dikirim (tanpa password) |
| `type RegisterResponse` | `user` + `token` + `expired_at` |

Dipisah dari struct model karena arti field yang namanya sama bisa berbeda:
`user.User.Password` berisi **hash**, sedangkan `RegisterRequest.Password`
berisi **teks asli**. Menyatukan keduanya mengundang kebocoran hash.

#### `internal/auth/handler.go` — ✅ sudah berfungsi

| Isi | Keterangan |
|---|---|
| `type Handler struct` | menyimpan `*Service` |
| `func (h *Handler) Register(c)` | `POST /api/auth/register` |
| `func writeError(c, err)` | satu-satunya tempat yang tahu peta error → kode HTTP |

Peta keputusannya:

| Jenis error | Kode | Artinya bagi pemanggil |
|---|---|---|
| `ValidationError` | `400` | "isianmu salah, perbaiki" |
| `ErrEmailTaken` | `409` | "email sudah dipakai, coba masuk saja" |
| lainnya | `500` | "salah kami" — pesan asli hanya masuk log, tidak dikirim ke klien |

#### `cmd/seed/main.go` — ✅ sudah berfungsi

Padanan `php artisan db:seed`. Membuat hash bcrypt lalu memasukkan 3 akun uji
(`user1@gmail.com`, `tunanetra@example.com`, `pendamping@example.com`) dengan
password `password123`.

Sifatnya **upsert**: kalau email-nya sudah ada, datanya ditimpa. Jadi aman
dijalankan berulang kali, dan inilah yang memperbaiki hash password rusak di
`user1@gmail.com` (lihat [bagian 11](#11-jebakan-yang-sudah-diketahui)).

#### `Makefile` — ✅ sudah berfungsi

Padanan `php artisan`. Jalankan `make` untuk melihat daftar lengkap.

| Perintah | Guna |
|---|---|
| `make run` | jalankan server |
| `make build` | build ke `bin/server` |
| `make check` | format + vet + test sekaligus |
| `make seed` | isi data uji |
| `make encrypt-profiles` | enkripsi data profil lama yang masih plaintext |
| `make psql` | buka psql ke database |
| `make db-dump` | cetak skema yang sedang terpasang (hanya membaca) |

Satu jebakan yang sudah kena: setiap baris perintah **wajib diawali TAB**.

#### `.env.example`

Template isi `.env`: 11 variabel, nilainya dikosongkan. Dipakai dengan cara
`cp .env.example .env` lalu isi sendiri.

---

## 5. Aturan arsitektur

Tujuh aturan yang dipegang project ini:

| # | Aturan | Alasan |
|---|---|---|
| 1 | **SQL hanya ada di `repository.go`** | ganti database cukup sentuh `repository.go` tiap fitur. *Pengecualian: `cmd/seed/`, karena itu alat pengembangan manual, bukan alur permintaan pengguna.* |
| 2 | **`handler.go` tidak boleh memanggil `repository.go` langsung** | aturan bisnis tidak boleh terlewat |
| 3 | **Konfigurasi hanya dibaca di `shared/config/`** | satu tempat untuk mencari masalah konfigurasi |
| 4 | **Endpoint hanya didaftarkan di `server/routes.go`** | melihat seluruh API cukup satu file |
| 5 | **`shared/` tidak boleh mengimport fitur mana pun** | mencegah import cycle — `shared/` adalah dasar piramida |
| 6 | **Fitur tidak boleh saling import dua arah** | Go melarang import cycle; arah hanya boleh satu arah |
| 7 | **Isi `internal/` bersifat privat** | kode di dalamnya tidak bisa diimport project lain |

Arah ketergantungan selalu **satu arah**, tidak boleh berputar balik:

```text
handler.go  →  service.go  →  repository.go  →  shared/database
      └────────────┴───────────────┴──────────────────►  shared/*
```

Handler tidak boleh tahu repository. Repository tidak boleh tahu handler.

Antar fitur juga satu arah, dan yang dipakai bersama naik ke `shared/`:

```text
auth  →  user  →  shared/*
```

Kalau aturan 5 dan 6 dilanggar, **compiler Go langsung menolak** — jadi bukan
sekadar kesepakatan yang bisa lupa.

---

## 6. Kamus istilah

Tabel rujukan saat kamu bertemu istilah teknis:

| Di analogi | Istilah teknis | Arti singkat |
|---|---|---|
| Gudang | PostgreSQL / database | tempat data disimpan |
| Bentuk rak | skema (schema) | susunan kolom & tabel |
| Foto cetak biru rak | migration | file pembuat skema |
| Dapur | backend / server | program yang melayani permintaan |
| Menu | API | kesepakatan cara memesan |
| Kertas pesanan | HTTP request, JSON | format permintaan |
| Nomor pintu | port (`8080`) | alamat pintu masuk server |
| Satpam | middleware | pemeriksa sebelum handler |
| Pelayan | handler | pengurus lapisan HTTP |
| Koki | service | tempat logika bisnis |
| Juru gudang | repository | tempat query SQL |
| Juru gudang siap | connection pool | kumpulan koneksi siap pakai |
| Brankas password | bcrypt / hashing | pengacak password satu arah |
| Gelang | session token | bukti sudah login |
| Buku catatan gelang | tabel `session` | daftar token aktif |
| Loker | file `.env` | penyimpan konfigurasi rahasia |
| Daftar isi loker | file `.env.example` | contoh .env untuk teman satu tim |
| — | `context.Context` | pengatur batas waktu & pembatalan operasi |
| — | struct | "class" versi Go (hanya data) |
| — | interface | kontrak; di Go dipenuhi secara otomatis |

---

## 7. Database

### Informasi koneksi (development)

| Item | Nilai |
|---|---|
| Database | `db_alice` |
| User aplikasi | `app_user` |
| Host / port | `localhost` / `5432` |
| Password | kosong (trust auth untuk koneksi lokal) |
| SSL mode | `disable` |

### Tabel yang sudah ada

| Tabel | Isi |
|---|---|
| `user` | `user_id` (uuid), `role`, `email`, `password`, `auth_provider`, `name`, `provider_id` |
| `session` | `session_id`, `user_id`, `session_token` (unik), `request_at`, `expired_at` |
| `companion` | data pendamping: `phone_number`, `address` |
| `visually_impaired` | `latitude`, `longitude`, `battery_level`, `last_seen_at` |
| `schedule` | jadwal |
| `request` | permintaan pendampingan |
| `schedule_request` | permintaan perubahan jadwal |
| `device_token` | token notifikasi perangkat |

### Tipe enum yang sudah ada

| Enum | Nilai |
|---|---|
| `user_role` | `tunanetra`, `pendamping` |
| `auth_provider_type` | `email`, `google`, `facebook` |
| `device_platform` | `android`, `ios` |
| `day_enum` | Senin … Minggu |
| `repeat_type_enum` | Tidak berulang, Setiap hari, Setiap minggu |
| `request_status` | Menunggu, Terhubung, Ditolak |
| `submission_status` | Menunggu, Disetujui, Ditolak |
| `schedule_action` | Tambah, Ubah, Hapus |

### Role database

| Role | Hak akses |
|---|---|
| `app_user` | baca + tulis (dipakai backend) |
| `operator_user` | baca + tulis |
| `viewer_user` | baca saja |

### Enkripsi data profil (nomor telepon & alamat)

Nomor telepon dan alamat pendamping **dienkripsi di aplikasi** sebelum masuk
database. Database hanya menyimpan ciphertext; ia tidak punya kunci dan tidak
tahu cara membukanya.

| Hal | Nilai |
|---|---|
| Algoritma | AES-256-GCM (authenticated encryption) |
| Kunci | `PROFILE_ENCRYPTION_KEY` di `.env`, base64 dari 32 byte |
| Format simpan | `v1:` + base64(nonce ‖ ciphertext ‖ tag) |
| AAD | `<user_id>:phone_number` / `<user_id>:address` |
| Tipe kolom | `phone_number` dan `address` bertipe `TEXT` |

Membuat kunci:

```bash
openssl rand -base64 32
```

Lalu isi di `.env`:

```text
PROFILE_ENCRYPTION_KEY=<hasil-perintah-di-atas>
```

Aplikasi **berhenti saat start** kalau kunci tidak ada atau panjangnya bukan
32 byte. Ini disengaja: lebih baik gagal sekarang daripada diam-diam
menyimpan data sensitif dalam bentuk plaintext.

**Peringatan:** kalau kunci ini hilang, data yang sudah terenkripsi tidak bisa
dipulihkan. Simpan cadangannya di tempat aman (bukan di repo).

**Data lama:** nilai yang belum berawalan `v1:` dianggap plaintext lama dan
tetap bisa dibaca. Begitu pemiliknya menyimpan ulang profil, nilainya berubah
menjadi ciphertext. Untuk membereskan semuanya sekaligus:

```bash
make encrypt-profiles
```

Perintah itu idempotent: baris yang sudah `v1:` dilewati, jadi aman dijalankan
berulang kali. Untuk memeriksa:

```sql
SELECT user_id, left(phone_number, 3), left(address, 3) FROM public.companion;
```

Baris baru akan terlihat seperti `v1:`; baris lama masih teks biasa.

Catatan: enkripsi ini melindungi data **saat tersimpan** (dump, backup, akses
langsung ke database). Untuk melindungi data saat dikirim, produksi tetap
harus memakai HTTPS.

### Desain autentikasi

Adanya tabel `session` dengan kolom `session_token` dan `expired_at` menunjukkan
bahwa **desainnya memakai session token yang disimpan di database** — bukan JWT.

Artinya: saat login, server membuat token acak, menyimpannya ke tabel `session`,
dan mengirimkannya ke aplikasi. Saat logout, barisnya dihapus sehingga token
langsung tidak berlaku. Kelebihan pendekatan ini: token **bisa dicabut kapan
saja**, dan mudah diperiksa langsung lewat `psql`.

---

## 8. Daftar endpoint

### Sudah ada

| Method | Path | Bentuk balasan | Keterangan |
|---|---|---|---|
| GET | `/api/hello` | lama (`message`, `app`) | uji koneksi backend |
| GET | `/api/health` | baku (`success`, `message`, `data`) | status server + database |
| POST | `/api/assistant/ask` | baku | tanya-jawab asisten |
| POST | `/api/auth/register` | baku | daftar akun baru, langsung dapat token |
| POST | `/api/auth/login` | baku | masuk dengan email & password, menerima token |
| POST | `/api/auth/google` | baku | masuk/daftar lewat akun Google |
| POST | `/api/auth/facebook` | baku | masuk/daftar lewat akun Facebook |

Endpoint berikut **butuh** header `Authorization: Bearer <token>`:

| Method | Path | Bentuk balasan | Keterangan |
|---|---|---|---|
| POST | `/api/auth/logout` | baku | akhiri sesi |
| GET | `/api/profile` | baku | profil pengguna yang sedang login |
| PUT | `/api/profile` | baku | ubah profil pengguna yang sedang login |
| GET | `/api/tunanetra/accounts` | baku | daftar akun tunanetra (halaman "Tautkan") |
| GET | `/api/tunanetra/search?q=` | baku | cari tunanetra berdasarkan kata kunci |
| GET | `/api/requests` | baku | pengajuan tautan milik pendamping (halaman "Terhubung") |
| POST | `/api/requests` | baku | kirim pengajuan tautan baru (status `Menunggu`) |
| DELETE | `/api/requests/{id}` | baku | batalkan pengajuan / putuskan tautan |
| GET | `/api/requests/incoming` | baku | permintaan masuk milik tunanetra yang login |
| PUT | `/api/requests/{id}/respond` | baku | tunanetra menerima (`Terhubung`) / menolak (`Ditolak`) |
| POST | `/api/device-tokens` | baku | daftarkan token perangkat untuk push notification |
| DELETE | `/api/device-tokens` | baku | hapus token perangkat (saat logout) |

Contoh `/api/health`:

```json
{
  "success": true,
  "message": "server dan database sehat",
  "data": { "status": "ok", "database": "connected" }
}
```

Kalau database mati, balasannya `503`:

```json
{ "success": false, "message": "database tidak bisa dihubungi" }
```

Endpoint yang tidak dikenal menjawab `404`, dan method yang salah menjawab
`405` — keduanya JSON, bukan teks kosong.

### `POST /api/auth/register` — ✅ sudah ada

Daftar akun baru dengan email. Karena tombol di aplikasi berbunyi
**"Daftar & Masuk"**, endpoint ini sekaligus membuat sesi login dan
mengembalikan token — pengguna tidak perlu mengetik ulang email dan password.

Badan permintaan:

```json
{
  "name": "Budi Santoso",
  "email": "BudiSantoso@gmail.com",
  "password": "rahasia123",
  "role": "pendamping",
  "phone_number": "08123456789",
  "address": "Jl. Ahmad Yani, Batam"
}
```

`role` hanya menerima dua nilai, sama dengan enum `user_role`:
`"pendamping"` atau `"tunanetra"`.

`phone_number` **wajib** untuk pendamping dan disimpan dalam bentuk rapi
(spasi, tanda hubung, dan kurung dibuang). `address` opsional, maksimal
255 karakter. Untuk `role: "tunanetra"`, kedua field ini diabaikan karena
tabel `visually_impaired` tidak punya kolomnya.

Balasan berhasil (`201 Created`):

```json
{
  "success": true,
  "message": "registrasi berhasil",
  "data": {
    "user": {
      "user_id": "bf0b2bf3-af32-43e1-9efa-614ae0c2e7d8",
      "name": "Budi Santoso",
      "email": "budi.santoso@gmail.com",
      "role": "pendamping"
    },
    "token": "cfa94de1214f5ab5570d141db47272f2...",
    "expired_at": "2026-10-29T15:22:46+07:00"
  }
}
```

Perhatikan `data.user`: email `BudiSantoso@gmail.com` tersimpan dan dibalas
sebagai huruf kecil, dan nama `"  Budi Santoso  "` sudah dirapikan lebih dulu.

Balasan gagal:

| Kode | Pesan | Sebab |
|---|---|---|
| `400` | `nama lengkap wajib diisi` | `name` kosong atau hanya berisi spasi |
| `400` | `email wajib diisi` | `email` kosong |
| `400` | `format email tidak valid` | `email` tidak berbentuk alamat email |
| `400` | `password minimal 6 karakter` | `password` terlalu pendek |
| `400` | `nomor telepon wajib diisi` | `phone_number` kosong untuk pendamping |
| `400` | `format nomor telepon tidak valid` | nomor bukan 9–15 digit (boleh diawali `+`) |
| `400` | `alamat maksimal 255 karakter` | `address` melebihi batas kolom database |
| `400` | `peran harus "pendamping" atau "tunanetra"` | `role` berisi nilai lain |
| `400` | `format JSON tidak valid` | badan permintaan bukan JSON yang sah |
| `409` | `email sudah terdaftar` | email sudah dipakai akun lain |
| `500` | `terjadi kesalahan pada server` | kesalahan di sisi kita; rinciannya hanya masuk log |

Contoh gagal:

```json
{ "success": false, "message": "email sudah terdaftar" }
```

### `POST /api/auth/login` — ✅ sudah ada

Masuk dengan email dan password, menerima session token.

Badan permintaan:

```json
{
  "email": "pendamping@example.com",
  "password": "password123"
}
```

Balasan berhasil (`200 OK`):

```json
{
  "success": true,
  "message": "login berhasil",
  "data": {
    "user": {
      "user_id": "69fe7760-540b-4280-a245-c24ff4e1eaff",
      "name": "Pengguna Pendamping",
      "email": "pendamping@example.com",
      "role": "pendamping"
    },
    "token": "7ab3325763d0cdb29b5b3027de1826671da1ed167b3832143b1b4e4d42bfc858",
    "expired_at": "2026-10-29T16:45:59+07:00"
  }
}
```

Balasan gagal:

| Kode | Pesan | Sebab |
|---|---|---|
| `400` | `email dan password wajib diisi` | salah satu atau kedua field kosong |
| `400` | `format JSON tidak valid` | badan permintaan bukan JSON sah |
| `401` | `email atau password salah` | email tidak terdaftar atau password tidak cocok |
| `500` | `terjadi kesalahan pada server` | kesalahan database / internal server |

### `GET /api/profile` dan `PUT /api/profile` — ✅ sudah ada

Endpoint ini butuh token:

```text
Authorization: Bearer <session_token>
```

`GET` mengembalikan data akun + profil pendamping:

```json
{
  "success": true,
  "message": "profil berhasil diambil",
  "data": {
    "user_id": "69fe7760-540b-4280-a245-c24ff4e1eaff",
    "name": "Pengguna Pendamping",
    "email": "pendamping@example.com",
    "role": "pendamping",
    "phone_number": "08123456789",
    "address": "Jl. Ahmad Yani, Batam"
  }
}
```

`PUT` menerima badan berikut (email & role tidak boleh diubah dari sini):

```json
{
  "name": "Pengguna Pendamping",
  "phone_number": "08123456789",
  "address": "Jl. Ahmad Yani, Batam"
}
```

Aturan validasinya sama dengan pendaftaran: nama wajib, telepon wajib &
9–15 digit, alamat opsional maksimal 255 karakter. Untuk pengguna
tunanetra, telepon & alamat diabaikan.

| Kode | Pesan | Sebab |
|---|---|---|
| `400` | `nama pengguna wajib diisi` | `name` kosong |
| `400` | `nomor telepon wajib diisi` | `phone_number` kosong |
| `400` | `format nomor telepon tidak valid` | bentuk nomor salah |
| `400` | `alamat maksimal 255 karakter` | alamat terlalu panjang |
| `401` | `sesi tidak valid atau sudah kedaluwarsa` | token tidak ada / kedaluwarsa |
| `404` | `profil tidak ditemukan` | `user_id` di token tidak ada di tabel `user` |

### `POST /api/device-tokens` dan `DELETE /api/device-tokens` — ✅ sudah ada

Menyimpan / menghapus token perangkat untuk push notification (FCM).
Keduanya butuh token sesi:

```text
Authorization: Bearer <session_token>
```

Badan permintaan `POST`:

```json
{ "token": "fcm-registration-token...", "platform": "android" }
```

`platform` hanya menerima `"android"` atau `"ios"`. Token yang sama boleh
dikirim berkali-kali; baris lama diperbarui, bukan diduplikasi. Balasan
berhasil (`200`):

```json
{
  "success": true,
  "message": "token perangkat tersimpan",
  "data": {
    "token_id": "1bea4938-fc13-48a9-aa12-7f6b7dbd724e",
    "platform": "android",
    "upload_at": "2026-11-20T10:32:33Z"
  }
}
```

Badan permintaan `DELETE` cukup berisi token:

```json
{ "token": "fcm-registration-token..." }
```

| Kode | Pesan | Sebab |
|---|---|---|
| `400` | `token perangkat wajib diisi` | `token` kosong |
| `400` | `platform harus "android" atau "ios"` | nilai enum salah |
| `401` | `sesi tidak valid atau sudah kedaluwarsa` | token login tidak ada / kedaluwarsa |

#### Mengaktifkan pengiriman notifikasi

1. Firebase Console → **Project Settings** → **Service accounts** →
   **Generate new private key**.
2. Simpan file JSON itu di `backend/service-account.json` (sudah masuk
   `.gitignore`).
3. Isi `.env`:

   ```text
   FIREBASE_CREDENTIALS_FILE=service-account.json
   ```

Kalau file belum ada, server tetap berjalan; di log muncul
`[notifikasi] push notification dimatikan` dan endpoint pendaftaran token
tetap bisa dipakai.

Di sisi Go, pengiriman dilakukan lewat `notification.Service.NotifyUser`
(otomatis membuang token yang dinyatakan mati oleh FCM). Pemanggilannya
belum dipasang ke fitur mana pun karena fitur jadwal/permintaan belum ada
di backend.

### Direncanakan (M2)

| Method | Path | Keterangan |
|---|---|---|
| POST | `/api/auth/logout` | mencabut token |

Endpoint yang butuh login akan memakai header:

```text
Authorization: Bearer <session_token>
```

---

## 9. Cara menjalankan

Butuh Go dan PostgreSQL (development local). Semua perintah dikumpulkan di
`Makefile`, jadi kamu tidak perlu menghafal `go run ...`.

Jalankan `make` untuk melihat daftar perintah.

### Pertama kali

```bash
cd backend
cp .env.example .env      # lalu isi nilainya (lihat tabel di bagian 7)
make seed                 # isi 3 akun uji
```

`.env` **tidak ikut ter-commit** (sudah dilindungi `.gitignore`).

Database dan skemanya **sudah ada** — project ini tidak membuat tabel. Itu
memang di luar jangkauan `app_user` (lihat
[bagian 4](#tidak-ada-folder-migrations--dan-itu-disengaja)).

### Setiap hari

```bash
make run
```

Harus muncul:

```text
Database: TERSAMBUNG
Server berjalan di http://localhost:8080
```

Kalau database mati atau namanya salah, aplikasi **berhenti** dengan pesan jelas
— bukan diam-diam jalan.

### Menguji

```bash
curl localhost:8080/api/hello
curl localhost:8080/api/health
```

### Melihat isi database

```bash
make psql        # masuk ke psql
make db-dump     # cetak skema yang sedang terpasang
```

### Menimpa nilai `.env` sementara

Environment sistem menang atas isi `.env`. Berguna untuk menguji jalur gagal
atau mengarahkan ke database lain:

```bash
DB_NAME=ngawur make run         # harus berhenti dengan error
APP_PORT=9000 make run          # jalan di port 9000
make seed DB_NAME=db_lain       # isi data uji ke database lain
```

### Memeriksa kode

```bash
make check      # format + vet + test
```

### Build

```bash
make build      # hasilnya di bin/server
```

Catatan versi: `go.mod` menulis `go 1.26.6`. Go otomatis mengunduh toolchain
yang sesuai (`GOTOOLCHAIN=auto`), jadi versi Go yang terpasang di sistem tidak
harus sama persis.

---

## 10. Rencana bertahap

| Milestone | Isi | Bukti berhasil |
|---|---|---|
| **M0 — Fondasi** | rapikan struktur, `.env` + `.env.example`, `shared/config`, `shared/database`, `server/routes.go`, `GET /api/health` | `curl /api/health` → `{"status":"ok","database":"connected"}` |
| **M0.5 — Struktur per fitur** | ubah pengelompokan dari *per lapisan* jadi *per fitur* + `shared/` | `make check` lolos; semua endpoint berperilaku identik sebelum & sesudah |
| **M1a — Register** | `POST /api/auth/register`, bcrypt, transaksi 2 tabel, token sesi | daftar lewat `curl` → `201` + token, dan datanya benar di database |
| **M1b — Login** | `POST /api/auth/login` | berhasil masuk dan menerima token |
| **M2 — Proteksi** | `shared/middleware/auth.go`, `GET /api/auth/me`, `POST /api/auth/logout` | token bisa dipakai & dicabut |
| **M3 — Sambung frontend** | ubah `email_login_page.dart` yang masih palsu, simpan token | login dari Flutter benar-benar memanggil backend |
| **M4 — Opsional** | Google / Facebook OAuth asli | — |

### Progres M0 — ✅ SELESAI

| Bagian | Status |
|---|---|
| Struktur folder (per fitur + `shared/`) | ✅ |
| `.env` + `.env.example` + `.gitignore` | ✅ |
| `internal/shared/config/config.go` | ✅ |
| `internal/shared/database/postgres.go` (pgxpool + ping) | ✅ |
| `Makefile` (padanan `artisan`) | ✅ |
| Seeder `make seed` | ✅ |
| Pindah ke Gin + CORS versi Gin | ✅ |
| `internal/server/routes.go` | ✅ |
| `GET /api/health` | ✅ |
| `internal/user/model.go` | ✅ |
| `internal/shared/response/response.go` | ✅ |
| `internal/shared/middleware/auth.go` (kerangka) | ✅ |
| `.editorconfig` | ✅ |
| Skema tersimpan di repo | ❌ (dihapus atas keputusan, lihat bagian 4) |

### Progres M1a (register) — ✅ SELESAI

| Janji | Status |
|---|---|
| `internal/user/repository.go` (SQL + transaksi) | ✅ |
| `internal/auth/model.go` (tabel `session`) | ✅ |
| `internal/auth/repository.go` (SQL session) | ✅ |
| `internal/auth/service.go` (validasi, bcrypt, token) | ✅ |
| `internal/auth/dto.go` (bentuk JSON) | ✅ |
| `internal/auth/handler.go` (HTTP, 400/409/500) | ✅ |
| `POST /api/auth/register` terdaftar di `server/routes.go` | ✅ |
| Diuji: 9 skenario lewat `curl` | ✅ semua sesuai harapan |
| Diuji: isi database sesudahnya (`user` + profil + `session`) | ✅ |
| Diuji: hash bcrypt benar-benar cocok dengan password | ✅ |
| Penyambungan ke Flutter | ❌ belum (M3) |

Bukti uji yang sudah dijalankan:

| Skenario | Hasil |
|---|---|
| Daftar pendamping, nama berlebih spasi, email huruf besar-kecil | `201` + token; tersimpan `Budi Santoso` / `budi.uji@example.com` |
| Daftar ulang dengan email sama (huruf kecil semua) | `409 email sudah terdaftar` |
| Password 5 karakter | `400 password minimal 6 karakter` |
| Email yang bukan berbentuk email | `400 format email tidak valid` |
| Nama hanya berisi spasi | `400 nama lengkap wajib diisi` |
| Peran `admin` | `400 peran harus "pendamping" atau "tunanetra"` |
| Badan permintaan bukan JSON | `400 format JSON tidak valid` |
| Daftar tunanetra | `201`; masuk ke `visually_impaired`, **bukan** `companion` |
| `GET` ke endpoint register | `405 method tidak didukung` |
| Hash tersimpan, diuji dengan library bcrypt | menerima `rahasia123`, menolak `password-salah` |
| Baris `session` sesudah daftar | ada, umur ±24 jam sesuai `SESSION_TTL_HOURS` |

### Progres M1b (login) — ✅ SELESAI

| Janji | Status |
|---|---|
| `internal/auth/service.go` (`Login` method + `ErrInvalidCredentials`) | ✅ |
| `internal/auth/dto.go` (`LoginRequest`, `LoginResponse`) | ✅ |
| `internal/auth/handler.go` (`Login` handler + 401 response) | ✅ |
| `POST /api/auth/login` terdaftar di `server/routes.go` | ✅ |
| Seeder `make seed` diperbarui untuk hash `password123` | ✅ |
| Diuji: 7 skenario lewat `curl` | ✅ semua lolos |

Bukti uji yang sudah dijalankan:

| Skenario | Hasil |
|---|---|
| Login valid `pendamping@example.com` | `200` + user data + token sesi |
| Login valid case-insensitive `USER1@GMAIL.COM` | `200` + user data + token sesi |
| Password salah | `401 email atau password salah` |
| Email tidak terdaftar | `401 email atau password salah` (pesan sama persis, anti-enumerasi) |
| Email / password kosong | `400 email dan password wajib diisi` |
| Format bukan JSON | `400 format JSON tidak valid` |
| Method GET | `405 method tidak didukung untuk endpoint ini` |

Berikutnya: **M2 — Proteksi Token (`shared/middleware/auth.go`, `/api/auth/me`, `/api/auth/logout`)**.

### Keputusan teknis yang sudah diambil

| Bagian | Pilihan |
|---|---|---|
| Router | Gin |
| Driver database | `pgx/v5` + `pgxpool` |
| Mekanisme login | session token di tabel `session` |
| Skema database | hanya ada di PostgreSQL; dicetak dengan `make db-dump` bila perlu |
| Config | `godotenv` + `internal/shared/config` |
| Hash password | `golang.org/x/crypto/bcrypt` (cost default = 10) |
| Enkripsi telepon & alamat | AES-256-GCM di aplikasi; kunci di `PROFILE_ENCRYPTION_KEY` |
| CLI perintah | `Makefile` |

---

## 11. Jebakan yang sudah diketahui

### 1. Password di database rusak

```text
user1@gmail.com | $2a$12$e8L9P2xX3m1      ← hanya 18 karakter
```

Hash bcrypt yang sah panjangnya **60 karakter**. Nilai di database sekarang
berisi 18 karakter, artinya **bukan hash yang valid**.

Akibatnya: berapa pun benar password yang diketik, proses pencocokan akan
selalu gagal. Jadi kalau nanti fitur login "selalu menolak" walau kodenya benar,
periksa dulu data ini.

**Sudah ada obatnya:** `make seed` menimpa baris itu dengan hash bcrypt yang
sah (60 karakter, dibuat oleh library yang sama dengan yang nanti dipakai
login).

### 1b. `app_user` tidak boleh mengubah struktur tabel

```text
ijin ditolak untuk skema public
must be owner of table user
permission denied for table session
```

`app_user` hanya punya `USAGE` di schema `public`, **tidak** `CREATE`. Yang
boleh mengubah bentuk tabel hanya admin (`postgres`).

Ini disengaja dan bagus: aplikasi yang sedang melayani pengguna tidak
seharusnya bisa membongkar tabel.

Yang boleh dilakukan `app_user` — sudah diuji langsung:

| Percobaan | Hasil |
|---|---|
| `CREATE TABLE` | ❌ `ijin ditolak untuk skema public` |
| `ALTER TABLE` | ❌ `must be owner of table` |
| `DROP TABLE` | ❌ `must be owner of table` |
| `TRUNCATE` | ❌ `permission denied for table` |
| `SELECT` / `INSERT` / `UPDATE` / `DELETE` | ✅ boleh |

**Karena itu tidak ada folder `migrations/` di project ini** — sudah dicoba,
lalu dihapus. Semua pekerjaan yang mengubah bentuk database harus dilakukan
admin, di luar repo, supaya tidak ada yang tanpa sengaja menjalankannya dengan
user aplikasi.

Kalau ada error "ijin ditolak untuk skema public", artinya ada perintah yang
mengubah struktur sedang dijalankan dengan `app_user`.

### 2. `.env` tidak boleh ikut ter-commit

`.env` berisi password dan kunci rahasia. Sudah dilindungi di `.gitignore` root:

```gitignore
backend/.env
.env
```

Cara memastikan sendiri:

```bash
git check-ignore -v backend/.env
# .gitignore:11:.env    backend/.env     ← aman
```

Yang di-commit hanya `.env.example` (isinya sama, value-nya dikosongkan).

**Jangan pernah menaruh password sebagai nilai cadangan di kode**, misalnya:

```go
DBPassword: getEnv("DB_PASSWORD", "password_asli")   // ❌ JANGAN
```

Nilai cadangan ikut ter-commit ke Git. Password asli hanya boleh ada di `.env`
atau environment sistem.

### 3. Password kosong menjebak di format DSN "kata kunci"

Sudah pernah terjadi di project ini. Format:

```text
host=localhost port=5432 user=app_user password= dbname=db_alice
```

Dengan password **kosong**, parser membacanya sebagai:

```text
password = "dbname=db_alice"
dbname   = ""            ← nama database hilang
```

Aplikasi jadi menyambung ke database yang salah **tanpa error yang jelas**.

Karena itu `config.DSN()` memakai format URL
(`postgres://user:@host:port/db?sslmode=...`), yang aman untuk password kosong
maupun password berisi `@` atau `:`.

### 4. Gin: `return` tidak menghentikan middleware

Di `net/http`, `return` sudah cukup untuk berhenti. Di Gin, `return` **tidak**
menghentikan rantai middleware — harus memakai `c.AbortWithStatus()`. Kalau
lupa, request yang seharusnya ditolak malah diteruskan.

### 5. Makefile wajib pakai TAB

Kalau memakai Makefile, indentasi **harus TAB**, bukan spasi. Kalau salah,
error-nya `missing separator` dan cukup membingungkan.

### 5b. `MAKEFILE_LIST` bisa berisi lebih dari satu file

Sudah pernah menggigit di project ini. Karena `Makefile` memuat `.env` dengan
`-include .env`, isi `$(MAKEFILE_LIST)` menjadi **dua** nama file:

```text
MAKEFILE_LIST = [Makefile .env]
```

Kalau variabel itu diberikan ke `grep` pada target `help`, `grep` menganggapnya
dua berkas dan menempelkan nama berkas di depan hasilnya:

```text
Makefile:run: ## Jalankan server      ← ada awalan "Makefile:"
```

Akibatnya kolom pertama `awk` berisi `Makefile`, dan daftar bantuan tampil kacau.

Perbaikannya: ambil berkas pertama saja, dan matikan awalan nama berkas:

```make
grep -h -E '...' $(firstword $(MAKEFILE_LIST))
```

Gunanya `-h`: kalau suatu saat file yang ikut termuat bertambah lagi, awalan
nama berkas tidak muncul lagi.

### 6. `down` migration itu berbahaya

File `*.down.sql` untuk migrasi awal berisi `DROP TABLE`. Menjalankannya di
database yang berisi data berarti **data hilang permanen**.
