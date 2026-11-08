# Konten Ruang Belajar (Firestore)

Materi dan kuis disimpan di Firestore, bukan di kode aplikasi.

## Struktur
```
belajar_levels/{levelId}    -> tingkat, subtitle, order
belajar_modules/{moduleId}  -> levelId, order, title, description,
                               sections[{heading, body}], references[],
                               quiz{label, passingScore, questions[{question, options[], correctIndex, explanation}]}
```
Progres pengguna tetap di `users/{uid}` (`completedModules`, `completedQuizzes`) memakai **ID modul**.

## Mengisi / memperbarui konten
1. Edit `content.json`.
2. `npm install` (sekali saja).
3. Unduh service account key dari Firebase Console (Project settings > Service accounts) dan simpan sebagai `serviceAccountKey.json` di folder ini. Jangan di-commit.
4. `npm run validate` untuk mengecek isi, lalu `npm run seed` untuk menulis ke Firestore.
5. Deploy rules: `firebase deploy --only firestore:rules`.

## Aturan penting
- Jangan mengubah `id` modul yang sudah dipakai pengguna, karena progres tersimpan berdasarkan ID itu.
- Urutan tampil ditentukan field `order` (modul) dan `order` (level).
- Modul baru: tambahkan di `content.json` dengan `id` unik, lalu seed ulang.
