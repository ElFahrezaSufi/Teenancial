# Teenancial

Teenancial adalah aplikasi manajemen keuangan Android berbasis Flutter yang dirancang khusus untuk membantu remaja mencatat dan mengelola keuangan harian secara mandiri dan disiplin. Aplikasi ini memfasilitasi:
- **Pencatatan Transaksi:** Pemasukan, pengeluaran, transfer antar-dompet/eksternal, serta pinjaman (hutang & piutang) secara *atomic* dengan *Cloud Firestore*.
- **Manajemen Dompet:** Pengelolaan dompet Tunai, Rekening & E-Wallet, serta Kartu dengan jejak penyesuaian saldo otomatis pada riwayat.
- **Target Menabung (*Allocation Model*):** Alokasi tabungan per target impian (Tabung & Tarik) tanpa mencampuradukkan saldo dompet utama.
- **Pengingat Jatuh Tempo Pinjaman:** Notifikasi lokal terjadwal (H-1 dan Hari-H pukul 09.00) serta notifikasi instan saat pencatatan pinjaman.
- **Tren Saldo & Riwayat Dinamis:** Grafik tren saldo aktual berdasarkan efek mutasi dompet dan filter rentang waktu.
- **Ruang Belajar & Tanya Feen:** Modul edukasi literasi keuangan remaja.

## Kelompok Pura-Pura Galiat

1. El Fahreza Sufi - 241401042
2. Pocut Qanitah Putroe Azizul - 241401105
3. Valmai Imtiyaz - 241401135

---

## Prasyarat Lingkungan (Setup)

Untuk menjalankan atau mem-build proyek ini, pastikan lingkungan pengembangan Anda memenuhi spesifikasi berikut:
- **Flutter SDK:** `>= 3.24.0` (kompatibel dengan Dart SDK `^3.5.0`).
- **Android SDK:** Compile SDK 36, Min SDK 24 (Android 7.0+), dengan *Core Library Desugaring* aktif.
- **Layanan Cloud (Gratis / Free Tier):**
  - **Firebase Authentication** (Email/Password & Google Sign-In) dan **Cloud Firestore** (konfigurasi di `lib/firebase_options.dart` & `android/app/google-services.json`).
  - **Cloudinary** (*Unsigned Upload Preset* untuk unggahan foto profil dan target menabung, dikonfigurasi di `lib/config/app_constants.dart`).

---

## Cara Menjalankan Aplikasi (Development)

1. Clone repositori ini dan masuk ke direktori proyek:
   ```bash
   cd Teenancial
   ```
2. Unduh seluruh dependensi paket Flutter:
   ```bash
   flutter pub get
   ```
3. Jalankan analisis statis untuk memastikan tidak ada masalah kode:
   ```bash
   dart analyze
   ```
4. Jalankan aplikasi pada emulator atau perangkat fisik Android:
   ```bash
   flutter run
   ```

---

## Cara Membuat APK untuk Demo (Release Build)

Untuk menghasilkan file `.apk` siap pasang di perangkat Android:

```bash
flutter build apk --release
```

File hasil build akan tersedia di:
`build/app/outputs/flutter-apk/app-release.apk`

> **Catatan Google Sign-In:** Pastikan fingerprint sertifikat (`SHA-1` dan `SHA-256`) dari komputer yang mem-build APK sudah terdaftar pada pengaturan aplikasi Android di *Firebase Console*.
