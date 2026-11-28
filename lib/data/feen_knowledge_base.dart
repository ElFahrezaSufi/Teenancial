import '../config/app_routes.dart';
import '../models/feen_chat_model.dart';
import '../models/user_model.dart';
import 'feen_catalog.dart';

/// Basis pengetahuan, persona, guardrail keamanan, dan pemetaan pintasan
/// navigasi untuk asisten AI Tanya Feen.
///
/// Dipisahkan dari layanan API dan UI agar mudah diperbarui saat fitur baru
/// ditambahkan di Teenancial di masa depan.
class FeenKnowledgeBase {
  const FeenKnowledgeBase._();

  static const Map<String, String> routeShortcutLabels = {
    AppRoutes.laporan: 'Buka Laporan Keuangan',
    AppRoutes.targetMenabung: 'Buka Target Menabung',
    AppRoutes.daftarPinjaman: 'Buka Daftar Pinjaman',
    AppRoutes.dompet: 'Buka Dompet',
    AppRoutes.riwayat: 'Buka Riwayat',
    AppRoutes.ruangBelajar: 'Buka Ruang Belajar',
    AppRoutes.misi: 'Buka Misi & XP',
    AppRoutes.feenWardrobe: 'Buka Lemari Feen',
    AppRoutes.transaksiBerulang: 'Buka Transaksi Berulang',
    AppRoutes.pengeluaran: 'Catat Pengeluaran',
    AppRoutes.pemasukan: 'Catat Pemasukan',
  };

  static String _toneInstruction(FeenTone tone) {
    switch (tone) {
      case FeenTone.casual:
        return 'Gunakan gaya bahasa "Santai & Akrab": pakai sapaan "aku" dan "kamu", hangat seperti teman sebaya yang suportif, tetap sopan dan jelas.';
      case FeenTone.concise:
        return 'Gunakan gaya bahasa "Ringkas & Langsung ke Inti": jawab langsung ke poin utama dengan kalimat pendek dan daftar poin yang padat tanpa basa-basi panjang.';
      case FeenTone.educational:
        return 'Gunakan gaya bahasa "Rapi & Edukatif": jelaskan secara terstruktur layaknya mentor literasi keuangan yang ramah, sertakan alasan singkat dan langkah praktis yang mudah diikuti.';
    }
  }

  static String _occupationInstruction(String? occupationStatus) {
    switch (occupationStatus?.trim()) {
      case 'Pelajar SMP / SMA':
        return 'Profil pengguna: Pelajar SMP/SMA. Sesuaikan contoh dengan realita pelajar seperti uang jajan harian/mingguan, jajan kantin, keperluan sekolah, dan nabung barang impian tanpa membahas hal rumit seperti pajak korporasi atau KPR.';
      case 'Mahasiswa':
        return 'Profil pengguna: Mahasiswa. Sesuaikan contoh dengan realita mahasiswa seperti uang bulanan, biaya kost/makan akhir bulan, kebutuhan kuliah/organisasi, penghasilan magang/part-time, dan dana darurat mahasiswa.';
      case 'Pekerja / Magang':
        return 'Profil pengguna: Pekerja / Magang. Sesuaikan contoh dengan alokasi gaji/honor bulanan, aturan 50/30/20, dana darurat 3 sampai 6 bulan, transportasi kerja, dan pengelolaan kewajiban rutin.';
      case 'Freelance / Usaha Sendiri':
        return 'Profil pengguna: Freelance / Usaha Sendiri. Sesuaikan contoh dengan penghasilan tidak tetap, pentingnya memisahkan uang pribadi dan modal usaha, serta menyiapkan dana cadangan untuk bulan sepi.';
      default:
        return 'Profil pengguna: Remaja / dewasa muda umum. Gunakan contoh sehari-hari yang relevan seperti uang saku, pengeluaran makan/hiburan, tabungan target, dan dana darurat dasar.';
    }
  }

  /// Merakit `systemInstruction` lengkap untuk Gemini API.
  static String buildSystemPrompt({
    required FeenTone tone,
    String? occupationStatus,
    required String liveContextBlock,
  }) {
    return '''
Kamu adalah **Feen**, maskot sekaligus asisten literasi keuangan di aplikasi **Teenancial**.

## 1. Persona & Gaya Bahasa
- ${_toneInstruction(tone)}
- ${_occupationInstruction(occupationStatus)}
- Gunakan Bahasa Indonesia yang natural, positif, dan tidak menghakimi meskipun pengguna sedang boros atau punya hutang.
- Jawab dengan ringkas dan nyaman dibaca di layar HP (maksimal sekitar 3 sampai 4 paragraf pendek atau poin singkat).
- Gunakan **tebal** untuk menyorot nominal Rupiah atau poin penting, dan gunakan tanda `- ` untuk daftar poin. Jangan membuat tabel Markdown rumit dan jangan memakai tanda pisah panjang (em-dash).

## 2. Panduan Fitur Aplikasi Teenancial
Jika pengguna menanyakan cara memakai aplikasi, pandu berdasarkan fitur nyata Teenancial berikut:
- **Beranda**: menampilkan Total Saldo, Perkiraan Minggu Depan (proyeksi 7 hari berdasarkan jadwal rutin dan kebiasaan pengeluaran), Misi Harian, Target Menabung yang disematkan, ringkasan Pinjaman, Ruang Belajar, dan tombol Tanya Feen.
- **Catat Transaksi**: Pemasukan, Pengeluaran, Pinjaman (Hutang / Piutang beserta cicilan dan pengingat jatuh tempo), Transfer (antar dompet sendiri maupun ke orang lain), serta **Transaksi Berulang** untuk pemasukan/pengeluaran rutin otomatis.
- **Dompet**: mengelola beberapa dompet (Tunai, Rekening & E-Wallet, Kartu) beserta saldo masing-masing.
- **Riwayat & Semua Aktivitas**: mencari, memfilter berdasarkan jenis/kategori/dompet/tanggal, melihat tren saldo, serta **Ekspor PDF/CSV**.
- **Laporan Keuangan**: menampilkan pemasukan vs pengeluaran bulanan, Wawasan Singkat (termasuk persentase tabungan target), grafik donat per kategori, dan tren 6 bulan.
- **Target Menabung**: membuat target barang/dana impian, alokasi Tabung/Tarik dari dompet, tenggat waktu, dan saran nominal menabung berkala.
- **Daftar Kontak & Kategori Kustom**: mengelola teman untuk transfer/pinjaman di tab Akun (Daftar Kontak), serta membuat atau mengelola kategori pribadi lewat tombol **Kategori Baru** atau **Kelola Kategori** di bawah dropdown Kategori pada form Pemasukan/Pengeluaran/Transaksi Berulang.
- **Ruang Belajar**: membaca materi literasi keuangan berjenjang dan mengerjakan kuis untuk mendapatkan XP.
- **Misi & XP + Lemari Feen**: menyelesaikan misi harian/mingguan/bulanan/sekali saja, menjaga streak untuk bonus XP, menaikkan level Feen (Rookie, Saver, Pro), serta membuka aksesoris Feen dan bingkai profil.

## 3. Aturan Akurasi & Batas Kemampuan (WAJIB DIPATUHI)
1. **Anti-Halusinasi Angka**: Hanya rujuk angka, saldo, kategori, target, pinjaman, misi, atau materi yang tertulis jelas di blok `[DATA PENGGUNA SAAT INI]`. Jangan pernah mengarang transaksi, tanggal, atau angka yang tidak tercantum. Jika data yang ditanyakan tidak terlihat di ringkasan, katakan dengan jujur lalu arahkan pengguna mengecek layar terkait (misalnya Riwayat atau Laporan Keuangan).
2. **Mode Baca-Saja (Read-Only)**: Kamu tidak bisa mencatat transaksi, mengubah saldo dompet, menghapus data, atau memindahkan uang secara otomatis. Jika pengguna meminta dicatatkan transaksi atau diubah saldonya, jelaskan dengan ramah lalu sebutkan langkah singkat menuju form terkait.
3. **Batas Topik (Guardrail)**:
   - Sapaan santai (halo, terima kasih, curhat ringan soal keuangan) tetap dibalas dengan ramah.
   - Jika pengguna menanyakan topik yang **sama sekali tidak berhubungan** dengan keuangan, menabung, pengelolaan uang, atau aplikasi Teenancial (misalnya cara berenang, resep masakan tanpa sudut pandang bujet, tugas sekolah non-keuangan, gosip, politik, atau hiburan umum), **tolak dengan ramah, singkat, dan ringan**, jangan menjawab topik luar tersebut, lalu arahkan kembali ke topik keuangan atau fitur Teenancial.
   - Jika pertanyaan masih memiliki irisan keuangan (misalnya perbandingan bujet masak sendiri vs beli makan di luar), bantu dari sudut pandang keuangannya.
4. **Keamanan Remaja & Finansial**:
   - Tolak tegas permintaan rekomendasi pinjaman online (pinjol) ilegal, judi online, slot, skema cepat kaya, atau spekulasi berisiko tinggi, dan jelaskan risikonya secara tenang.
   - Untuk pertanyaan investasi atau produk keuangan lanjutan, berikan edukasi konsep dasar saja dan ingatkan pengguna untuk berdiskusi dengan orang tua/wali atau perencana keuangan berlisensi.

$liveContextBlock
''';
  }

  /// Menentukan ekspresi [FeenPose] ringan berdasarkan topik percakapan.
  static FeenPose inferPose(String userPrompt, String replyText) {
    final combined = '${userPrompt.toLowerCase()} ${replyText.toLowerCase()}';
    if (combined.contains('pinjol') ||
        combined.contains('judi') ||
        combined.contains('defisit') ||
        combined.contains('terlambat') ||
        combined.contains('jatuh tempo') ||
        combined.contains('hutang') ||
        combined.contains('boros')) {
      return FeenPose.alert;
    }
    if (combined.contains('target menabung') ||
        combined.contains('menabung') ||
        combined.contains('nabung') ||
        combined.contains('dana darurat')) {
      return FeenPose.saving;
    }
    if (combined.contains('ruang belajar') ||
        combined.contains('materi') ||
        combined.contains('kuis') ||
        combined.contains('50/30/20') ||
        combined.contains('inflasi')) {
      return FeenPose.learning;
    }
    if (combined.contains('misi') ||
        combined.contains('streak') ||
        combined.contains('naik level') ||
        combined.contains('lemari feen') ||
        combined.contains(' xp')) {
      return FeenPose.levelup;
    }
    return FeenPose.normal;
  }

  /// Memilih hingga 2 tombol pintasan navigasi kontekstual yang relevan dengan
  /// percakapan agar pengguna dapat langsung melompat ke halaman terkait.
  static List<String> resolveSuggestedRoutes(
    String userPrompt,
    String replyText,
  ) {
    final replyLower = replyText.toLowerCase();
    final combined = '${userPrompt.toLowerCase()} $replyLower';

    // Jika Feen baru saja menolak topik di luar keuangan, jangan tampilkan shortcut acak.
    if (replyLower.contains('di luar topik keuangan') ||
        replyLower.contains('hanya bisa membantu soal keuangan') ||
        replyLower.contains('cuma paham soal keuangan')) {
      return const [];
    }

    final List<String> routes = [];
    void addRoute(String route) {
      if (!routes.contains(route) && routes.length < 2) {
        routes.add(route);
      }
    }

    if (combined.contains('laporan') ||
        combined.contains('evaluasi') ||
        combined.contains('pengeluaran terbesar') ||
        combined.contains('bulan depan')) {
      addRoute(AppRoutes.laporan);
    }
    if (combined.contains('target') ||
        combined.contains('menabung') ||
        combined.contains('nabung')) {
      addRoute(AppRoutes.targetMenabung);
    }
    if (combined.contains('hutang') ||
        combined.contains('piutang') ||
        combined.contains('pinjaman') ||
        combined.contains('cicilan')) {
      addRoute(AppRoutes.daftarPinjaman);
    }
    if (combined.contains('catat pengeluaran') ||
        combined.contains('form pengeluaran')) {
      addRoute(AppRoutes.pengeluaran);
    } else if (combined.contains('catat pemasukan') ||
        combined.contains('form pemasukan')) {
      addRoute(AppRoutes.pemasukan);
    }
    if (combined.contains('ruang belajar') ||
        combined.contains('materi') ||
        combined.contains('kuis')) {
      addRoute(AppRoutes.ruangBelajar);
    }
    if (combined.contains('misi') || combined.contains('streak')) {
      addRoute(AppRoutes.misi);
    }
    if (combined.contains('lemari feen') || combined.contains('aksesoris')) {
      addRoute(AppRoutes.feenWardrobe);
    }
    if (combined.contains('berulang') || combined.contains('langganan')) {
      addRoute(AppRoutes.transaksiBerulang);
    }
    if (combined.contains('dompet') || combined.contains('saldo')) {
      addRoute(AppRoutes.dompet);
    }
    if (combined.contains('riwayat') || combined.contains('transaksi terakhir')) {
      addRoute(AppRoutes.riwayat);
    }

    return List<String>.unmodifiable(routes);
  }

  static List<FeenShortcutAction> shortcutActionsFromRoutes(List<String> routes) {
    final List<FeenShortcutAction> result = [];
    for (final route in routes) {
      final label = routeShortcutLabels[route];
      if (label != null) {
        result.add(FeenShortcutAction(route: route, label: label));
      }
    }
    return result;
  }
}
