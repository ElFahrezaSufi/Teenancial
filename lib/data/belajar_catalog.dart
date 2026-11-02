import '../models/belajar_model.dart';

class BelajarCatalog {
  BelajarCatalog._();

  static List<LevelData> buildLevels() {
    return [
      // ── DASAR ──────────────────────────────────────────────────────────────
      LevelData(
        tingkat: 'Dasar (Beginner)',
        subtitle: 'Modul dasar untuk membangun kebiasaan dan pemahaman awal.',
        modules: [
          ModuleData(
            title: 'Mengenal Uang: Kebutuhan vs Keinginan',
            description:
                'Pahami dari mana asal uang sakumu dan temukan cara termudah '
                'membedakan antara kebutuhan pokok dan sekadar keinginan sementara.',
            quiz: QuizData(label: 'Kuis 1: Analisis Kebutuhan'),
            status: ModuleStatus.available,
          ),
          ModuleData(
            title: 'Jurus Anggaran Sederhana: Metode 50/30/20',
            description:
                'Uang saku selalu habis di tengah bulan? Pelajari cara membagi '
                'uangmu ke dalam pos-pos pengeluaran agar selalu cukup dan bisa menabung.',
            quiz: QuizData(label: 'Kuis 2: Praktik Budgeting'),
          ),
          ModuleData(
            title: 'Celengan Konvensional vs Dompet Digital',
            description:
                'Mulai dari celengan babi, rekening bank, hingga QRIS dan e-wallet. '
                'Kenali tempat terbaik dan teraman untuk menyimpan uangmu.',
            quiz: QuizData(label: 'Kuis 3: Keamanan Bertransaksi'),
          ),
        ],
      ),

      // ── SEDANG ─────────────────────────────────────────────────────────────
      LevelData(
        tingkat: 'Sedang (Intermediate)',
        subtitle:
            'Modul untuk remaja yang mulai ingin merencanakan keuangan masa depan di Teenancial.',
        modules: [
          ModuleData(
            title: 'Dana Darurat: Penyelamat Saat Kepepet',
            description:
                'Apa itu dana darurat? Pelajari cara mengumpulkan jaring pengaman '
                'finansial untuk kejadian tak terduga seperti HP rusak atau ban bocor.',
            quiz: QuizData(label: 'Kuis 4: Simulasi Dana Darurat'),
          ),
          ModuleData(
            title: 'Jebakan Batman: Utang dan Paylater',
            description:
                'Bedakan mana utang yang produktif dan utang yang merugikan. '
                'Pahami bahaya fitur bayar-nanti (paylater) jika tidak dikendalikan.',
            quiz: QuizData(label: 'Kuis 5: Detektif Utang'),
          ),
          ModuleData(
            title: 'Kenalan dengan Investasi Ringan',
            description:
                'Uangmu bisa bekerja untukmu. Temukan instrumen investasi yang '
                'cocok untuk pelajar, seperti Reksa Dana Pasar Uang dan Deposito.',
            quiz: QuizData(label: 'Kuis 6: Profil Risiko Pemula'),
          ),
        ],
      ),

      // ── SULIT ──────────────────────────────────────────────────────────────
      LevelData(
        tingkat: 'Sulit (Advanced)',
        subtitle:
            'Modul lanjutan untuk mencapai kemandirian dan kebebasan finansial sejak muda.',
        modules: [
          ModuleData(
            title: 'Musuh Tak Terlihat: Inflasi',
            description:
                'Kenapa harga jajan sekolah selalu naik setiap tahun? Ketahui '
                'bagaimana inflasi menggerus nilai uangmu dan cara melawannya.',
            quiz: QuizData(label: 'Kuis 7: Hitung Efek Inflasi'),
          ),
          ModuleData(
            title: 'Keajaiban Bunga Majemuk (Compound Interest)',
            description:
                'Rahasia terbesar para miliarder. Pelajari bagaimana bunga yang '
                'berbunga lagi bisa melipatgandakan asetmu dalam jangka panjang.',
            quiz: QuizData(label: 'Kuis 8: Kekuatan Waktu'),
          ),
          ModuleData(
            title: 'Membangun Passive Income Sebagai Pelajar',
            description:
                'Jangan hanya bergantung pada uang saku. Mulai eksplorasi cara '
                'menciptakan sumber pendapatan otomatis dari hobi dan keahlianmu.',
            quiz: QuizData(label: 'Kuis 9: Strategi Income Tambahan'),
          ),
        ],
      ),
    ];
  }
}
