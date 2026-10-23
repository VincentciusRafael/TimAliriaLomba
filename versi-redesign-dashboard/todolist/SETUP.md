# Panduan Setup — Kelola Alteco

Data Kelola Alteco disimpan di GitHub Gist agar dapat diakses dari semua device.
Push notification dikirim otomatis via OneSignal + GitHub Actions setiap hari.
Viewer cukup buka URL — tidak perlu konfigurasi apapun.
Superadmin perlu melakukan setup sekali berikut ini.

---

## Prasyarat

- Akun GitHub (pemilik repo `dionisiusnp.github.io`)
- Akun Cloudflare (gratis) — untuk write proxy
- Akun OneSignal (gratis) — untuk push notification

---

## Langkah 1 — Buat Gist

1. Buka [gist.github.com](https://gist.github.com)
2. Isi form:
   - **Gist description**: `Alteco Data`
   - **Filename**: `alteco-data.json`
   - **Content**:
     ```json
     {"kelompoks":[],"members":[],"tasks":[],"assets":[],"events":[],"projects":[],"cultures":[],"regulasi":{"visi":"","misi":"","syaratAnggota":[],"syaratTim":[],"sanksi":[]},"orgName":"Nama Organisasi","settings":{"pushNotifEnabled":false,"notifTime":"07:00","notifDaysBefore":1,"writePat":""}}
     ```
3. Klik **"Create secret gist"**
4. Salin **Gist ID** dari URL browser:
   ```
   https://gist.github.com/dionisiusnp/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
                                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                        ini Gist ID-nya
   ```

---

## Langkah 2 — Buat Personal Access Token (PAT)

PAT digunakan sebagai Cloudflare Worker secret (agar app bisa tulis ke Gist) dan GitHub Actions secret (agar cron harian bisa baca/tulis Gist). PAT tidak disimpan di browser.

1. Buka [github.com/settings/tokens](https://github.com/settings/tokens)
2. Klik **"Generate new token (classic)"**
3. Isi:
   - **Note**: `alteco-gist`
   - **Expiration**: `No expiration`
   - **Scope**: centang **`gist`** saja
4. Klik **"Generate token"**
5. **Salin token sekarang** — hanya tampil sekali
   ```
   ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

---

## Langkah 3 — Pasang Gist ID ke Kode

Buka file `todolist/index.html`, cari baris:

```javascript
const GIST_ID   = 'GIST_ID_DISINI';
const WORKER_URL= 'WORKER_URL_DISINI';
```

Ganti `GIST_ID` dengan Gist ID dari Langkah 1. `WORKER_URL` diisi setelah Langkah 4.

Commit dan push ke GitHub.

---

## Langkah 4 — Setup Cloudflare Worker

Ikuti panduan lengkap di **[WORKER.md](WORKER.md)**.

Pastikan setelah selesai:
- 4 secrets sudah diset di Cloudflare (`GIST_ID`, `GIST_PAT`, `ONESIGNAL_APP_ID`, `ONESIGNAL_REST_KEY`)
- URL Worker sudah diisi ke `WORKER_URL` di `todolist/index.html` baris ~598

---

## Langkah 5 — Setup OneSignal (Push Notification)

### 5a. Buat aplikasi OneSignal

1. Buka [onesignal.com](https://onesignal.com) → daftar akun gratis
2. Buat **New App** → pilih platform **Web**
3. Pilih **Custom Code** sebagai integration type
4. Isi **Site URL**: `https://dionisiusnp.github.io`
5. Selesaikan wizard → catat **App ID**

### 5b. Ambil App ID dan REST API Key

1. Di dashboard OneSignal, buka **Settings → Keys & IDs**
2. Salin:
   - **OneSignal App ID** (format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)
   - **REST API Key** (format: `os_v2_...`)

### 5c. Pasang App ID ke kode

Buka `todolist/index.html`, cari:

```javascript
const ONESIGNAL_APP_ID = 'ONESIGNAL_APP_ID_DISINI';
```

Ganti dengan App ID dari OneSignal:

```javascript
const ONESIGNAL_APP_ID = 'b03c4a75-c2b0-4de5-ab9c-cb5aa2f58cd2'; // contoh
```

Commit dan push.

### 5d. Service Worker

File `OneSignalSDKWorker.js` sudah ada di root repo. Tidak perlu diubah:

```javascript
importScripts('https://cdn.onesignal.com/sdks/web/v16/OneSignalSDK.sw.js');
```

---

## Langkah 6 — Setup GitHub Secrets

GitHub Actions butuh 4 secrets untuk mengirim notifikasi harian.

1. Buka repo di GitHub → **Settings → Secrets and variables → Actions**
2. Klik **"New repository secret"**, tambahkan satu per satu:

| Secret Name | Nilai |
|---|---|
| `GIST_ID` | Gist ID dari Langkah 1 |
| `GIST_PAT` | PAT dari Langkah 2 |
| `ONESIGNAL_APP_ID` | App ID dari Langkah 5b |
| `ONESIGNAL_REST_KEY` | REST API Key dari Langkah 5b |

---

## Langkah 7 — Aktifkan Push Notification

1. Buka halaman Kelola Alteco → login superadmin
2. Di sidebar, klik **Pengaturan ⚙️**
3. Aktifkan toggle **Push Notification**
4. Set **Waktu Kirim** (jam pengiriman notifikasi, default 07:00 WIB)
5. Set **Notif Mulai H-** (berapa hari sebelum acara sekali notifikasi mulai dikirim, default 1)
6. Klik **Simpan**

---

## Alur Kerja Data

| Aksi | Penjelasan |
|------|-----------|
| Buka halaman | Data dimuat dari Gist publik — semua device dapat data terbaru |
| Tambah/edit data (admin/viewer) | POST ke Cloudflare Worker → Worker PATCH Gist. ~600ms setelah perubahan |
| Gist tidak terjangkau | Fallback ke data lokal browser |
| PAT | Disimpan di Cloudflare Worker secret + GitHub Actions secret. Tidak ada token di browser |

---

## Fitur Informasi

Superadmin dapat membuat **pengumuman/acara** di menu **Informasi 🔔**.

### Tipe acara

| Tipe | Penjelasan |
|------|-----------|
| **Sekali** | Acara pada tanggal tertentu. Notifikasi dikirim setiap hari mulai H-X sampai hari H. |
| **Berulang** | Acara rutin. Notifikasi hanya dikirim pada hari H sesuai pola pengulangan. |

### Pola pengulangan (Berulang)

| Pola | Notifikasi dikirim |
|------|-------------------|
| Harian | Setiap hari |
| Mingguan | Hari yang sama dengan tanggal acuan |
| Bulanan | Tanggal yang sama dengan tanggal acuan |
| Tahunan | Tanggal & bulan yang sama dengan tanggal acuan |

### Bell badge

Ikon lonceng di navbar menampilkan jumlah pengumuman baru/diperbarui yang belum dibaca.
Badge hilang setelah membuka halaman Informasi. Badge muncul kembali jika ada pengumuman baru atau yang diedit.

---

## Fitur Regulasi (Superadmin)

Tersedia di sidebar **📋 Regulasi** — admin CRUD, viewer hanya baca.

### Visi & Misi

Teks bebas. Admin klik ikon edit di kartu, simpan → tersimpan ke Gist.

### Syarat Anggota & Syarat Tim

Dua tab terpisah, masing-masing berisi daftar syarat dengan filter Non-IT / IT.

| Field | Keterangan |
|-------|-----------|
| Nama | Nama syarat |
| Tipe | `Non-IT` (default), `IT`, atau `Keduanya` (muncul di kedua filter) |
| Keterangan | Deskripsi syarat |
| URL | Link referensi (opsional) |

Urutan dapat diatur dengan tombol ▲ ▼ (admin).

### Sanksi

Daftar sanksi per kelompok. Tiap entri punya:

| Field | Keterangan |
|-------|-----------|
| Nama | Nama/judul sanksi |
| Kelompok | Pilih dari daftar kelompok di bagan organisasi |
| Level | Warning 1 → Warning 2 → Blacklist |
| Alasan | Penjelasan sanksi |
| Tanggal | Tanggal sanksi diberikan |

Sanksi ditampilkan urut per level (Warning 1, Warning 2, Blacklist) dengan badge warna.

---

## Fitur Lomba & Polling

Tersedia di sidebar **🏆 Lomba** (menu Manajemen) dan juga sebagai halaman mandiri: **`lomba.html`** di root repo.

### Tampilan

Halaman Lomba memakai **tampilan dashboard**:

| Bagian | Isi |
|--------|-----|
| Header | Judul + ringkasan (`4 lomba · 2 jenis · 4 ide · 14 suara`), search bar, dan tombol `🏷 Kelola Jenis` / `👥 Kelola Tim` / `＋ Tambah Lomba` (Superadmin) |
| Stat tiles | 🏆 **Lomba** (+jumlah jenis) · 👥 **Tim** (+total anggota & tim terpakai) · 💡 **Ide** (+ide resmi) · 🗳️ **Suara** (+jumlah polling) · ⏳ **Segera** (deadline terdekat) |
| Filter jenis | Pill `Semua` + 1 pill per jenis, masing-masing dengan titik warna. Klik = filter |
| Sebaran jenis | Bar horizontal per jenis (proporsional + persen). **Klik bar = filter jenis** |
| Kartu lomba | Grid (3 kolom di desktop, 1 di mobile). Badge jenis berwarna, badge countdown, badge tim, meta, dan bar suara. Klik kartu → expand jadi 1 baris penuh berisi daftar ide + polling + anggota tim |
| Ide | Setiap lomba punya daftar ide. Tiap ide menampilkan judul, deskripsi, nama pengusul, bar persentase polling, dan badge |
| Polling | 1 suara per **lomba** per **perangkat**. Persentase dihitung dari total pilihan di lomba tersebut |

> Warna badge jenis & bar bersifat **stabil** per nama jenis (hash → palet app), jadi selalu sama di card, pill, dan bar.

### Jenis Lomba & Filter

Setiap lomba bisa diberi **jenis** (mis. Hackathon, FGD, Seminar) lalu daftar lomba bisa difilter berdasarkan jenis tersebut.

#### Alur

1. **Buat jenis dulu** — Superadmin membuat daftar jenis lewat tombol **🏷 Kelola Jenis** di toolbar Lomba (pola sama seperti **👥 Kelola Tim**).
2. **Pilih jenisnya** — di modal **Tambah/Edit Lomba**, field opsional **Jenis Lomba** dipakai untuk memilih jenis yang sudah dibuat.

#### Modal "🏷 Kelola Jenis"

| Tombol | Fungsi |
|--------|--------|
| `＋ Tambah Jenis` | Form: **Nama Jenis** → Simpan |
| `✎` | Edit nama jenis |
| `✕` | Hapus jenis (soft delete). Nama jenis pada lomba yang memakainya **tetap tersimpan** |

Tiap baris menampilkan jumlah lomba yang memakai jenis tersebut.

#### Isi dropdown di modal Lomba

| Opsi | Arti |
|------|------|
| `— Tanpa Jenis —` | Lomba tanpa jenis (default) |
| `Jenis saat ini: <nama>` | Hanya muncul saat edit — jenis lama yang sudah tidak ada di daftar master |
| `Hackathon`, `FGD`, … | Daftar jenis master |

Kalau daftar jenis kosong, fieldnya nonaktif dan muncul catatan *"Belum ada jenis. Buat dulu lewat tombol 🏷 Kelola Jenis di toolbar."*

#### Filter jenis (pill)

- Deretan **pill** di toolbar, tepat **sebelah kiri searchbar**: `Semua` + satu pill per jenis yang dipakai lomba (urut A-Z).
- Pill aktif = accent. Filter berlaku untuk **Admin & Viewer**.
- Filter Combine dengan search: search juga cocok dengan kolom jenis (placeholder: `Cari lomba / jenis…`).
- Kalau filter aktif tapi jenisnya sudah tidak dipakai lomba mana pun → filter otomatis reset ke `Semua`.

### Tim & Anggota Tim

Setiap lomba punya **tim beserta daftar anggotanya**. Alurnya dua langkah:

1. **Buat tim dulu** — Superadmin membuat daftar tim lewat tombol **👥 Kelola Tim** di toolbar Lomba (kanan atas, sebelah tombol `＋ Tambah Lomba`).
2. **Pilih timnya** — di modal **Tambah/Edit Lomba**, field opsional **👥 Tim** dipakai untuk memilih tim yang sudah dibuat.

#### Modal "👥 Kelola Tim"

| Tombol | Fungsi |
|--------|--------|
| `＋ Tambah Tim` | Form: **Nama Tim** + tabel anggota → Simpan |
| `✎` | Edit tim (nama + anggota) |
| `✕` | Hapus tim (soft delete). Tim di lomba yang memakainya **tetap utuh** (lomba menyimpan salinan) |

#### Isi dropdown di modal Lomba

| Opsi | Arti |
|------|------|
| `— Tanpa Tim —` | Lomba tanpa tim (default). Field tim di bawah disembunyikan |
| `Tim saat ini: <nama>` | Hanya muncul saat edit — tim yang sudah terpasang, isinya bisa diedit |
| `▸ Daftar Tim` | Tim-tim dari daftar master (dibuat lewat Kelola Tim). Memilih salah satu akan **menyalin** anggotanya ke lomba ini |

Kalau daftar tim masih kosong, muncul catatan *"Belum ada tim. Buat dulu lewat tombol 👥 Kelola Tim di toolbar."*

#### Form tabel anggota

| Kolom | Keterangan |
|-------|------------|
| Nama Anggota | Wajib. Maksimal 60 karakter |
| Peran | Dropdown tetap: `Ketua` atau `Anggota`. **Hanya boleh 1 ketua per tim** — saat satu anggota diubah jadi Ketua, anggota lain otomatis jadi Anggota |
| NIM / ID | Opsional, maksimal 30 karakter |

Tombol `＋ Tambah Baris` menambah baris, `✕` menghapus baris. Validasi saat Simpan: nama tim wajib dan minimal 1 anggota bernama.

#### Aturan data

- **Daftar tim = template** — lomba yang memakai sebuah tim menyimpan **salinan** anggota. Mengubah / menghapus tim di daftar master **tidak** mengubah lomba yang sudah memakai tim tersebut.
- Salinan anggota mendapat **id baru**, jadi tidak bentrok dengan tim sumber.
- Lomba yang memakai tim versi lama tetap menampilkan anggota lamanya sampai dipilih ulang dari daftar master.

#### Tampilan di kartu Lomba

Di dalam body kartu Lomba ada baris **👥 Tim: `<nama>` · `<jumlah>` anggota** — bisa diklik (dropdown) untuk melihat tabel anggota (Nama / Peran / NIM). Viewer bisa membuka dropdown, Superadmin juga mendapat tombol `✎` untuk membuka modal Ubah Tim.

### Badge pada ide

| Badge | Arti |
|-------|------|
| 👤 *(nama)* | Nama pengusul ide (kosong → "Anonim" untuk viewer, "Tim" untuk admin) |
| Usulan Viewer | Ide diajukan oleh viewer (bukan admin) |
| ★ Resmi | Ide ditandai admin sebagai ide resmi/terpilih (tombol ★) |
| 🥇 Teratas | Ide dengan suara terbanyak di lomba tersebut |

### Peran

| Aksi | Viewer | Admin |
|------|--------|-------|
| Melihat list lomba & polling | ✅ | ✅ |
| Melihat dropdown anggota tim | ✅ | ✅ |
| **Filter jenis lomba** (pill) | ✅ | ✅ |
| Memilih ide (👍/👎) | ✅ | ✅ |
| **Mengajukan ide** (`＋ Ajukan Ide`) | ✅ | ✅ |
| Menghapus ide miliknya sendiri | ✅ | ✅ |
| Tambah / edit / hapus lomba | ❌ | ✅ |
| Isi / ubah jenis & tim di lomba | ❌ | ✅ |
| Kelola daftar jenis master (`🏷 Kelola Jenis`) | ❌ | ✅ |
| Kelola daftar tim master (`👥 Kelola Tim`) | ❌ | ✅ |
| Edit ide, tandai ★ Resmi | ❌ | ✅ |

Ide yang diajukan viewer **langsung aktif** (tidak perlu approval) dan bisa langsung dipilih oleh device lain.

### Penyimpanan

- Data lomba `lombas[].ide[]` disimpan di Gist yang sama (`alteco-data.json`, key `lombas`).
- Data jenis **master** (daftar jenis) disimpan di key baru `jenisLomba` pada Gist yang sama:
  ```jsonc
  "jenisLomba": [
    { "id":"j_x", "name":"Hackathon", "createdAt":0, "updatedAt":0 },
    { "id":"j_y", "name":"FGD",        "createdAt":0, "updatedAt":0 }
  ]
  ```
  - Hapus jenis = **soft delete** (`deleted: true`).
- Data jenis **di lomba** disimpan di `lombas[].jenis` (nama) + `lombas[].jenisId` (referensi master):
  ```jsonc
  "jenis": "Hackathon",
  "jenisId": "j_x"
  ```
  - `jenis` dipakai sebagai snapshot → nama jenis pada lomba lama tetap tampil walau master dihapus/berubah.
  - Field opsional → lomba tanpa jenis tetap valid dan tidak muncul di pill jenis (tapi tetap muncul di `Semua`).
- Data tim **master** (daftar tim) disimpan di key baru `timLomba` pada Gist yang sama:
  ```jsonc
  "timLomba": [
    { "id":"t_x", "name":"Tim A",
      "members":[
        { "id":"m_x", "name":"Budi Santoso", "peran":"ketua",   "nim":"221011234" },
        { "id":"m_y", "name":"Sari Wijaya",  "peran":"anggota", "nim":"221011567" }
      ],
      "createdAt":0, "updatedAt":0 }
  ]
  ```
  - `peran` hanya berisi `ketua` atau `anggota`.
  - Hapus tim = **soft delete** (`deleted: true`), mengikuti pola hapus item lain di app.
- Data tim **di lomba** (salinan) disimpan di `lombas[].tim`:
  ```jsonc
  "tim": {
    "name": "Tim A",
    "members": [
      { "id":"m_x", "name":"Budi Santoso", "peran":"ketua",   "nim":"221011234" },
      { "id":"m_y", "name":"Sari Wijaya",  "peran":"anggota", "nim":"221011567" }
    ]
  }
  ```
  - **Migrasi data lama:** `tim` sebelumnya berupa string (`"tim": "Nama Tim"`). String ini otomatis dinormalisasi jadi object `{name, members: []}` saat load, jadi data lama tetap tampil — hanya tanpa daftar anggota (bisa ditambah lewat modal Ubah Tim).
  - Karena `tim` menempel pada objek lomba, field ini mengikuti mekanisme merge `lombas[]` yang sudah ada (versi terbaru menang). Jika dua perangkat mengedit tim lomba yang sama bersamaan, perubahan terakhir yang tersimpan yang menang.
- ⚠️ **Worker perlu di-deploy ulang** setelah versi ini: key `timLomba` dan `jenisLomba` adalah array top-level baru, dan tanpa merge (`mergeTimLomba` / `mergeArr`) di Worker, isinya jadi *last-write-wins* (edit di 2 device bisa saling timpa). Kode Worker yang sudah di-update ada di [`WORKER.md`](WORKER.md) → **Edit code → Replace → Deploy**.
- Field baru pada ide: `author` (nama), `authorRole` (`admin`/`viewer`), `authorDevice` (id perangkat, penanda "ide milik saya"), `promoted` (tandai ★).
- Field baru bersifat opsional → data lama tetap aman. Ide tanpa `author` dianggap ide tim.
- State voting disimpan di `localStorage` (`alteco_lomba_votes_v1`) → 1 suara per lomba per perangkat, berlaku bersama di app `todolist` **dan** `lomba.html`.
- Id perangkat disimpan di `localStorage` (`alteco_device_id`) → dipakai untuk menentukan "ide milik saya" dan mencegah vote ganda.
- `lomba.html` memakai cache lokal sendiri (`alteco_lomba_page_v1`) dan **re-fetch + merge Gist sebelum menulis**, sehingga tidak menimpa perubahan yang dibuat di app `todolist`.

### Halaman mandiri `lomba.html`

- Menampilkan **hanya** fitur lomba (tanpa sidebar modul lain).
- Tombol **🔑** di kanan atas untuk masuk mode superadmin — kode superadmin sama dengan app `todolist` dan session login dipakai bersama (`sessionStorage: rak_alteco_role`).
- **Wajib kode akses**: tanpa session, halaman ini menampilkan gate login (superadmin `19950328` / viewer `20251208`). Tidak ada akses tamu.

### Landing `index.html` (situs khusus lomba)

| Bagian | Isi |
|--------|-----|
| Layar login | Background foto (banner_1/2/3) + kartu kode akses. **Wajib** — tidak ada mode tamu. Kode **superadmin `19950328`** / **viewer `20251208`** — sama dengan gate app `todolist` dan tombol 🔑 di `lomba.html` |
| Setelah masuk | Aplikasi Lomba ditampilkan di dalam `<iframe src="lomba.html?embed=1">` |
| Navigasi | Landing **tidak** punya navbar sendiri — navbar diambil dari halaman Lomba di dalam iframe (satu navbar). Tombol keluar `↩` ada di navbar tersebut dan mengirim pesan ke landing untuk logout |
| Link | Tidak ada link "Manajemen" di landing — app `todolist` diakses langsung via URL |

- Mode `?embed=1` → nav `lomba.html` jadi navbar tunggal: tombol "‹ Aliria" disembunyikan, brand `🏆 Lomba` + badge role + 🔑 + 🌙 + ↩ tetap tampil.
- Tema landing ↔ iframe saling sinkron lewat event `storage` (origin sama).
- Role di `sessionStorage` juga berlaku di iframe dan di app `todolist` (satu tab, satu origin). Role dikirim juga lewat `postMessage` agar badge & hak akses di iframe selalu sinkron dengan sesi.

### Halaman lain (arsip)

Halaman lama dipindah ke folder **`arsip/`** (`about.html`, `laravel.html`, `mitra/`, `pemasaran/`, `pengajar/`, `proyekan/`, `scrapper/`) dan **tidak di-link** dari landing. Akses langsung masih bisa lewat URL.

---


Tersedia di sidebar menu **Pengaturan ⚙️** — hanya terlihat oleh superadmin.

| Field | Penjelasan |
|-------|-----------|
| **Push Notification** | Toggle aktif/nonaktif push notification. Jika nonaktif, notifikasi web biasa saja yang berjalan (browser harus terbuka). |
| **Waktu Kirim** | Jam pengiriman push notification dalam WIB (contoh: `07:00`). |
| **Notif Mulai H-** | Berapa hari sebelum acara *sekali* notifikasi mulai dikirim. Default: 1 hari. Berlaku global untuk semua acara. |
| **OneSignal REST Key** | REST API Key dari OneSignal (dari Langkah 5b). Disimpan di Gist. Diperlukan untuk tombol **Kirim Sekarang** — isi sekali, berlaku untuk semua browser admin. |

### Kirim Rangkuman Manual

Tombol **Kirim Sekarang** di bagian *Kirim Manual* mengirim push notification langsung ke OneSignal API dari browser — tidak melalui GitHub Actions.

- Berisi semua pemberitahuan aktif (`date >= hari ini` untuk sekali; semua untuk berulang)
- Tidak mengubah `notifSentDate` — status notif harian tidak terganggu
- Membutuhkan **OneSignal REST Key** sudah diisi di Pengaturan dan disimpan

---

## Jadwal GitHub Actions

File workflow: `.github/workflows/daily-notif.yml`

```
Cron: 1 17 * * *  →  00:01 WIB
```

| Langkah | Penjelasan |
|---------|-----------|
| Baca Gist | Ambil data terbaru termasuk settings |
| Cek `pushNotifEnabled` | Jika false, berhenti |
| Filter acara hari ini | Cek tipe, tanggal, dan `notifSentDate` per acara |
| Kirim 1 bundled push | Semua acara hari ini dalam satu notifikasi |
| `send_after` | OneSignal mengirim pada jam `notifTime` WIB (bukan 00:01) |
| Update `notifSentDate` | Tandai sudah dikirim agar tidak duplikat hari yang sama |

### Dedup per acara

Setiap acara punya field `notifSentDate`. Workflow skip acara jika `notifSentDate === hari ini`.
Saat acara dibuat atau diedit, `notifSentDate` di-reset ke `null` agar notifikasi aktif kembali.

### Trigger manual

Workflow bisa dijalankan manual: **GitHub → Actions → Daily Notification → Run workflow**.

---

## Mode Notifikasi

| Mode | Kondisi | Perilaku |
|------|---------|---------|
| Push ON | `pushNotifEnabled = true`, browser/device sudah allow | Push notification muncul meski halaman tertutup |
| Push OFF | `pushNotifEnabled = false` | Notifikasi web biasa — hanya muncul saat halaman terbuka |

> **iOS Safari**: Push notification web hanya berfungsi jika situs ditambahkan ke Home Screen (Add to Home Screen) dan iOS ≥ 16.4. Browser Safari biasa tidak mendukung.

---

## Reset & Maintenance

### Ganti PAT (jika perlu rotate token)

1. Buka [github.com/settings/tokens](https://github.com/settings/tokens)
2. Klik **Delete** pada token `alteco-gist`
3. Buat PAT baru (ulangi Langkah 2)
4. Update secret di Cloudflare Worker (Settings → Variables and Secrets → edit `GIST_PAT`)
5. Update secret `GIST_PAT` di GitHub Actions (repo Settings → Secrets → edit)

### Reset status notifikasi (force kirim ulang)

Edit salah satu acara di Informasi → simpan. `notifSentDate` reset ke `null` → notif akan dikirim di run berikutnya.
