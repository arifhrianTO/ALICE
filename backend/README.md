# Backend ALICE

Server API untuk aplikasi ALICE. Ditulis dengan bahasa **Go**, memakai database **PostgreSQL**.

> **Status: FONDASI SELESAI (M0).** Konfigurasi, koneksi PostgreSQL, router Gin,
> `/api/health`, model, dan Makefile sudah jalan. Yang belum: fitur aplikasi.
> File yang masih kerangka ditandai **KERANGKA** di peta folder:
> `auth_service.go` dan `user_repository.go`.
> Belum ada satu pun endpoint login/register.

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
| Endpoint | 3 buah: `GET /api/hello`, `GET /api/tunanetra`, `GET /api/health` |
| Middleware | CORS + Recovery + Logger (Gin) |
| Konfigurasi | `.env` dibaca lewat `godotenv`, divalidasi di `shared/config/` |
| Koneksi database | `pgxpool` + `Ping`, berhenti jelas kalau DB mati |
| Makefile | ✅ pengganti `php artisan` |
| Seeder | ✅ `make seed` |
| Bentuk balasan API | ✅ `response.Response` untuk endpoint baru |
| Data | **data dummy** (ditulis keras di kode, bukan dari database) |

### Belum ada

| Hal | Keterangan |
|---|---|
| Fitur login / register | belum ada |
| Middleware auth | kerangka ada, isinya belum (`shared/middleware/auth.go`) |
| Endpoint yang membaca tabel | belum ada (`/api/health` hanya `Ping`, tidak membaca tabel) |
| Bentuk database di repo | ❌ tidak disimpan (lihat bagian 4) |

**Kesimpulan:** fondasi sudah berdiri, database tersambung, API sudah memakai
Gin, dan `/api/health` sudah terbukti menjawab jujur soal database. Tapi belum
ada satu pun fitur yang membaca isi tabel. Datanya masih palsu.

### Kerangka file yang belum diisi

`internal/user/repository.go` dan `internal/auth/service.go` masih **berisi file
kerangka (stub)**. Isinya hanya nama fungsi dan komentar `TODO` yang menjelaskan
apa yang nanti dikerjakan di situ — **belum ada implementasi**.

Yang **sudah** diimplementasikan: `internal/shared/config/config.go` dan
`internal/shared/database/postgres.go`.

Fungsi kerangka yang tersisa masih mengembalikan error `belum diimplementasikan`.
Jadi kalau sekarang ada yang memanggilnya, kegagalannya kelihatan jelas, bukan
diam-diam mengembalikan nilai kosong yang menyesatkan.

Belum ada satu pun fungsi kerangka itu yang dipanggil dari `main.go`, jadi server
tetap berjalan normal.

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
│   ├── tunanetra/               ← FITUR (data masih dummy)
│   │   ├── handler.go           ← ✅ handler HTTP
│   │   ├── model.go             ← bentuk data yang dikirim ke klien
│   │   └── data.go              ← SEMENTARA: data dummy, akan dihapus
│   │
│   ├── user/                    ← FITUR
│   │   ├── model.go             ← ✅ cerminan tabel "user"
│   │   └── repository.go        ← KERANGKA: kontrak SQL tabel user & session
│   │
│   └── auth/                    ← FITUR
│       └── service.go           ← KERANGKA: logika daftar & masuk
│           (M1 menambah: handler.go, repository.go, dto.go)
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
| `tunanetra/` | handler + model + data dummy | ✅ jalan (data masih dummy) |
| `user/` | cerminan tabel `user` + kontrak SQL | KERANGKA |
| `auth/` | logika daftar & masuk | KERANGKA |

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

### `internal/tunanetra/data.go` — data dummy (SEMENTARA)

Data yang ditulis keras di kode, sebagai pengganti database sementara supaya
frontend bisa dikerjakan lebih dulu.

Karena sudah berada di dalam fiturnya, file ini **tidak perlu import apa pun** —
`handler.go`, `model.go`, dan `data.go` satu package.

**File ini akan dihapus** begitu `tunanetra/repository.go` bisa mengambil data
asli. Aturannya: hapus saat penggantinya sudah siap, jangan sebelum.

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
| `func Setup(db *pgxpool.Pool, appEnv string) *gin.Engine` | rakit router Gin, pasang Logger + Recovery + CORS, daftarkan 3 endpoint |
| `r.NoRoute` | endpoint tak dikenal → 404 JSON |
| `r.NoMethod` | method salah → 405 JSON (bukan 404) |
| `r.Group("/api")` | semua endpoint berawalan `/api` |
| blok komentar | daftar endpoint M1/M2 yang belum dibuat, dikomentari |

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

#### `internal/tunanetra/handler.go` — ✅ sudah berfungsi (data masih dummy)

| Isi | Keterangan |
|---|---|
| `func List(c *gin.Context)` | balas daftar tunanetra sebagai **array polos**, bukan amplop `Response` |

⚠️ Bentuk array polos ini **wajib dipertahankan**: aplikasi Flutter sudah
memakainya dan membaca hasilnya langsung sebagai `List<dynamic>`. Kalau dibungkus
jadi `{"success": true, "data": [...]}`, halaman "tunanetra location" di aplikasi
akan rusak.

#### `internal/tunanetra/model.go` dan `data.go` — SEMENTARA

| Isi | Keterangan |
|---|---|
| `type Tunanetra struct` | bentuk satu baris data tunanetra yang dikirim ke klien |
| `var DummyTunanetra` | dua baris data tulis-keras (dummy), pengganti database sementara |

Keduanya akan **dihapus/diganti** begitu `tunanetra/` mengambil data asli dari
database.

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

#### `internal/user/repository.go`

| Isi | Keterangan |
|---|---|
| `type UserRepository interface` | kontrak akses tabel `user`. TODO: `FindByEmail`, `FindByID`, `Create` |
| `type SessionRepository interface` | kontrak akses tabel `session`. TODO: `Create`, `FindByToken`, `Delete` |
| `type postgresUserRepository struct` | implementasi asli. TODO: simpan `pool`, tulis query SQL-nya |

#### `internal/auth/service.go`

| Isi | Keterangan |
|---|---|
| `type AuthService struct` | TODO: isi dengan `UserRepository`, `SessionRepository`, `ttl` |
| `func NewAuthService() *AuthService` | TODO: terima repository sebagai parameter (dependency injection) |
| `func (s *AuthService) Login(email, password string) (string, error)` | TODO: cari user → cocokkan bcrypt → buat token → simpan session |
| `func (s *AuthService) Register(name, email, password, role string) error` | TODO: validasi → hash password → simpan user + tabel sesuai role |

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
| GET | `/api/tunanetra` | **array langsung** (dipakai Flutter) | daftar tunanetra (**data dummy**) |
| GET | `/api/health` | baku (`success`, `message`, `data`) | status server + database |

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

### Direncanakan

| Method | Path | Keterangan |
|---|---|---|
| POST | `/api/auth/register` | daftar akun baru |
| POST | `/api/auth/login` | masuk, menerima token |
| POST | `/api/auth/logout` | mencabut token |
| GET | `/api/auth/me` | data pengguna yang sedang login |
| POST | `/api/auth/logout` | mencabut token |
| GET | `/api/auth/me` | data pengguna yang sedang login |

Permintaan login yang direncanakan:

```json
{ "email": "user@example.com", "password": "rahasia123" }
```

Balasan berhasil:

```json
{
  "token": "a1b2c3d4...",
  "expired_at": "2026-10-29T10:00:00Z",
  "user": { "user_id": "...", "name": "Budi", "role": "pendamping" }
}
```

Endpoint yang butuh login akan memakai header:

```text
Authorization: Bearer a1b2c3d4...
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
curl localhost:8080/api/tunanetra
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
| **M1 — Auth inti** | `POST /api/auth/register`, `POST /api/auth/login`, bcrypt, simpan session | berhasil login dan menerima token |
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

Berikutnya: **M1 — register & login**.

### Keputusan teknis yang sudah diambil

| Bagian | Pilihan |
|---|---|---|
| Router | Gin |
| Driver database | `pgx/v5` + `pgxpool` |
| Mekanisme login | session token di tabel `session` |
| Skema database | hanya ada di PostgreSQL; dicetak dengan `make db-dump` bila perlu |
| Config | `godotenv` + `internal/shared/config` |
| Hash password | `golang.org/x/crypto/bcrypt` (cost default = 10) |
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
