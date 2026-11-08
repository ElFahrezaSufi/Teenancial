// File ini tidak lagi dipakai oleh provider.
// Konten modul sekarang diambil dari Firestore.
// Dipertahankan sebagai referensi konten default.

import '../models/belajar_model.dart';

class BelajarCatalog {
  BelajarCatalog._();

  static List<LevelData> buildLevels() {
    return const [
      LevelData(
        id: 'dasar',
        order: 0,
        tingkat: 'Dasar (Beginner)',
        subtitle: 'Modul dasar untuk membangun kebiasaan dan pemahaman awal.',
        modules: [
          ModuleData(
            id: 'kebutuhan-vs-keinginan',
            order: 0,
            title: 'Mengenal Uang: Kebutuhan vs Keinginan',
            description:
                'Pahami dari mana asal uang sakumu dan temukan cara termudah '
                'membedakan antara kebutuhan pokok dan sekadar keinginan sementara.',
            quiz: QuizData(label: 'Kuis 1: Analisis Kebutuhan'),
            status: ModuleStatus.available,
          ),
          ModuleData(
            id: 'metode-50-30-20',
            order: 1,
            title: 'Jurus Anggaran Sederhana: Metode 50/30/20',
            description:
                'Uang saku selalu habis di tengah bulan? Pelajari cara membagi '
                'uangmu ke dalam pos-pos pengeluaran agar selalu cukup dan bisa menabung.',
            quiz: QuizData(label: 'Kuis 2: Praktik Budgeting'),
          ),
          ModuleData(
            id: 'celengan-vs-dompet-digital',
            order: 2,
            title: 'Celengan Konvensional vs Dompet Digital',
            description:
                'Mulai dari celengan babi, rekening bank, hingga QRIS dan e-wallet. '
                'Kenali tempat terbaik dan teraman untuk menyimpan uangmu.',
            quiz: QuizData(label: 'Kuis 3: Keamanan Bertransaksi'),
          ),
        ],
      ),
      LevelData(
        id: 'sedang',
        order: 1,
        tingkat: 'Sedang (Intermediate)',
        subtitle:
            'Modul untuk remaja yang mulai ingin merencanakan keuangan masa depan.',
        modules: [
          ModuleData(
            id: 'dana-darurat',
            order: 0,
            title: 'Dana Darurat: Penyelamat Saat Kepepet',
            description:
                'Apa itu dana darurat? Pelajari cara mengumpulkan jaring pengaman '
                'finansial untuk kejadian tak terduga.',
            quiz: QuizData(label: 'Kuis 4: Simulasi Dana Darurat'),
          ),
          ModuleData(
            id: 'utang-paylater',
            order: 1,
            title: 'Jebakan Batman: Utang dan Paylater',
            description:
                'Bedakan mana utang yang produktif dan utang yang merugikan.',
            quiz: QuizData(label: 'Kuis 5: Detektif Utang'),
          ),
          ModuleData(
            id: 'investasi-ringan',
            order: 2,
            title: 'Kenalan dengan Investasi Ringan',
            description:
                'Uangmu bisa bekerja untukmu. Temukan instrumen investasi yang '
                'cocok untuk pelajar.',
            quiz: QuizData(label: 'Kuis 6: Profil Risiko Pemula'),
          ),
        ],
      ),
      LevelData(
        id: 'sulit',
        order: 2,
        tingkat: 'Sulit (Advanced)',
        subtitle:
            'Modul lanjutan untuk mencapai kemandirian finansial sejak muda.',
        modules: [
          ModuleData(
            id: 'inflasi',
            order: 0,
            title: 'Musuh Tak Terlihat: Inflasi',
            description:
                'Kenapa harga jajan sekolah selalu naik setiap tahun? Ketahui '
                'bagaimana inflasi menggerus nilai uangmu.',
            quiz: QuizData(label: 'Kuis 7: Hitung Efek Inflasi'),
          ),
          ModuleData(
            id: 'bunga-majemuk',
            order: 1,
            title: 'Keajaiban Bunga Majemuk (Compound Interest)',
            description:
                'Rahasia terbesar para miliarder. Pelajari bagaimana bunga yang '
                'berbunga lagi bisa melipatgandakan asetmu.',
            quiz: QuizData(label: 'Kuis 8: Kekuatan Waktu'),
          ),
          ModuleData(
            id: 'passive-income',
            order: 2,
            title: 'Membangun Passive Income Sebagai Pelajar',
            description:
                'Jangan hanya bergantung pada uang saku. Eksplorasi cara '
                'menciptakan sumber pendapatan dari hobi dan keahlianmu.',
            quiz: QuizData(label: 'Kuis 9: Strategi Income Tambahan'),
          ),
        ],
      ),
    ];
  }
}
