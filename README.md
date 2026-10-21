# FileBrowser untuk Termux

Skrip sederhana untuk memasang dan menjalankan [FileBrowser](https://github.com/filebrowser/filebrowser) di Android (Termux, tanpa root). Hasilnya adalah antarmuka web mirip Google Drive untuk mengunggah, mengunduh, dan mengelola file di ponsel dari browser mana pun di jaringan lokal.

Berisi tiga skrip:

| Skrip | Fungsi |
| :--- | :--- |
| `install.sh` | Memasang FileBrowser, membuat konfigurasi dan akun admin |
| `start.sh` | Menjalankan FileBrowser di latar belakang |
| `stop.sh` | Menghentikan FileBrowser |

> **Status:** skrip hanya diperiksa sintaksnya (`bash -n`) dan belum diuji di banyak perangkat. Baca bagian [Batasan](#batasan) sebelum dipakai untuk data penting.

## Prasyarat

1. **Termux dari F-Droid atau GitHub**, bukan Google Play. Versi Play Store sudah tidak dikembangkan dan sering bermasalah dengan paket.
2. Koneksi internet saat instalasi.
3. Ponsel dan perangkat klien (laptop/PC) berada di **jaringan Wi-Fi yang sama** local LAN.
4. Disarankan: matikan optimasi baterai untuk Termux (Pengaturan → Baterai → Termux → Tanpa batasan). Di Android 12 ke atas, Android dapat menghentikan proses latar belakang secara agresif; opsi "Disable child process restrictions" di Opsi Pengembang dapat membantu. Letak pengaturan berbeda per perangkat.

## Instalasi

```bash
pkg update && pkg upgrade
pkg install git
git clone https://github.com/<username>/<nama-repo>.git
cd <nama-repo>
bash install.sh
```

Ganti `<username>/<nama-repo>` dengan alamat repositori ini. Tanpa Git, salin ketiga berkas ke Termux dengan cara lain, lalu jalankan `bash install.sh`.

Saat instalasi, skrip akan:

1. Mencoba `pkg install filebrowser`. Jika tidak tersedia, skrip mengunduh biner rilis resmi dari GitHub sesuai arsitektur perangkat.
2. Membuat folder yang dibagikan (default `~/nas`).
3. Meminta Anda membuat **password admin** (minimal 12 karakter).
4. Menyimpan konfigurasi di `~/services/filebrowser/filebrowser.db`.

## Penggunaan

Menjalankan:

```bash
bash start.sh
```

Skrip akan menampilkan alamat akses, misalnya:

```
[OK] FileBrowser berjalan (PID 12345).
     Di ponsel  : http://localhost:8081
     Dari jaringan: http://192.168.1.20:8081
```

Buka alamat itu di browser, lalu masuk dengan pengguna `admin` dan password yang Anda buat saat instalasi.

Menghentikan:

```bash
bash stop.sh
```

Setelah berhenti, wake lock Termux masih aktif. Jika tidak ada layanan lain yang berjalan, lepaskan dengan `termux-wake-unlock` agar baterai tidak terus terpakai.

## Konfigurasi

Pengaturan diubah lewat variabel lingkungan **saat menjalankan `install.sh`**:

| Variabel | Default | Keterangan |
| :--- | :--- | :--- |
| `FB_ROOT` | `~/nas` | Folder yang dibagikan |
| `FB_PORT` | `8081` | Port web. Port di bawah 1024 tidak bisa dipakai tanpa root |
| `FB_ADDR` | `0.0.0.0` | Alamat bind. `127.0.0.1` berarti hanya bisa diakses dari ponsel sendiri |
| `FB_USER` | `admin` | Nama pengguna admin |
| `FB_DIR` | `~/services/filebrowser` | Lokasi database, log, dan PID file |

Contoh:

```bash
FB_PORT=9000 FB_ROOT=$HOME/storage/shared/NAS bash install.sh
```

Untuk memakai `~/storage/shared` (penyimpanan internal yang terlihat di aplikasi file Android), jalankan `termux-setup-storage` dulu dan izinkan aksesnya. Sebaiknya arahkan ke satu subfolder khusus, bukan seluruh penyimpanan.

Konfigurasi disimpan di database, jadi mengubah variabel di atas **setelah** instalasi tidak berpengaruh. Untuk mengubahnya kemudian, hentikan server lalu gunakan `filebrowser config set`, misalnya:

```bash
bash stop.sh
filebrowser config set -p 9000 -d ~/services/filebrowser/filebrowser.db
bash start.sh
```

Jika Anda memakai `FB_DIR` khusus, set variabel yang sama saat menjalankan `start.sh` dan `stop.sh`.

## Akses dari Windows

Buka alamat `http://<IP-PONSEL>:<PORT>` di browser. Tidak ada pemasangan drive jaringan; ini murni antarmuka web. Untuk memasang sebagai drive di Windows, gunakan SFTP (`pkg install openssh`) dengan WinSCP atau SSHFS-Win sebagai gantinya.

## Berkas yang dibuat

```
~/services/filebrowser/
├── filebrowser.db     # konfigurasi dan akun (izin 600)
├── filebrowser.log    # log (dipotong otomatis jika > 1 MB)
└── filebrowser.pid    # PID proses yang berjalan
~/nas/                 # folder yang dibagikan (default)
```

## Pemecahan masalah

| Gejala | Kemungkinan penyebab dan solusi |
| :--- | :--- |
| `start.sh` gagal dan menampilkan log | Port sudah dipakai (misalnya server PHP di port yang sama). Ganti port dengan `filebrowser config set -p ...` |
| Tidak bisa dibuka dari laptop | Pastikan satu jaringan. Sebagian router mengaktifkan "AP isolation" yang memblokir antarperangkat |
| IP tidak terdeteksi | Android versi baru membatasi perintah jaringan. Lihat IP di pengaturan Wi-Fi ponsel |
| Server mati sendiri | Android mematikan proses latar belakang. Cek optimasi baterai dan jalankan `termux-wake-lock` |
| Instalasi gagal mengunduh | Cek koneksi. Pastikan jaringan mengizinkan akses ke `github.com` |
| Perintah `filebrowser` macet saat server jalan | Database terkunci oleh server. Jalankan `bash stop.sh` dulu |
| Lupa password | Hentikan server, lalu `filebrowser users update admin --password '<password-baru>' -d ~/services/filebrowser/filebrowser.db` (sintaks perlu diverifikasi di versi Anda dengan `filebrowser users update --help`) |

## Menghapus

```bash
bash stop.sh
rm -rf ~/services/filebrowser          # database, log, PID
pkg uninstall filebrowser              # jika dipasang lewat pkg
rm -f "$PREFIX/bin/filebrowser"        # jika dipasang dari unduhan GitHub
```

Folder yang dibagikan (`~/nas`) **tidak** dihapus oleh langkah di atas. Hapus manual hanya jika Anda yakin sudah punya salinan filenya.

## Batasan

- **Tanpa HTTPS.** Password dan file dikirim tanpa enkripsi di jaringan. Pakai hanya di jaringan yang Anda percaya dan **jangan buka port ke internet**.
- **Tanpa redundansi.** Data hanya ada di ponsel. Simpan cadangan di tempat lain.
- **Tanpa auto-start.** Server tidak menyala otomatis setelah ponsel dihidupkan ulang. Itu membutuhkan Termux:Boot, yang tidak termasuk di sini.
- **Unduhan tanpa verifikasi checksum.** Jika memakai jalur unduhan GitHub, biner tidak diperiksa checksum-nya.
- **Belum diuji luas.** Nama berkas rilis, ketersediaan paket `filebrowser` di repositori Termux, dan perilaku di berbagai versi Android perlu diverifikasi di perangkat Anda.
- Ketahanan server bergantung pada Android; ponsel yang dipakai sebagai penyimpanan utama tanpa cadangan tidak disarankan.

## Kredit

FileBrowser adalah proyek terpisah: [filebrowser/filebrowser](https://github.com/filebrowser/filebrowser). Repositori ini hanya berisi skrip pembungkus untuk Termux.
