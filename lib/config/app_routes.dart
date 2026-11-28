class AppRoutes {
  AppRoutes._();

  // Entry & Auth Routes
  static const String splash = '/splash';
  static const String getStarted = '/get_started';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot_password';
  static const String verifyEmail = '/verify_email';

  // Main Shell Bottom Navigation Routes
  static const String home = '/home';
  static const String dompet = '/dompet';
  static const String riwayat = '/riwayat';
  static const String profile = '/profile';

  // Feature Sub-Routes
  static const String gantiPassword = '/ganti_password';
  static const String pemasukan = '/pemasukan';
  static const String pengeluaran = '/pengeluaran';
  static const String pinjaman = '/pinjaman';
  static const String daftarPinjaman = '/daftar_pinjaman';
  static const String transfer = '/transfer';
  static const String tambahDompet = '/tambah_dompet';
  static const String targetMenabung = '/target_menabung';
  static const String buatTarget = '/buat_target';
  static const String ruangBelajar = '/ruang_belajar';
  static const String semuaAktivitas = '/semua_aktivitas';
  static const String tanyaFeen = '/tanya_feen';
  static const String feenWardrobe = '/feen_wardrobe';
  static const String kategori = '/kategori';
  static const String laporan = '/laporan';
  static const String transaksiBerulang = '/transaksi_berulang';
  static const String buatBerulang = '/buat_berulang';
  static const String ekspor = '/ekspor';
  static const String misi = '/misi';
  static const String kontak = '/kontak';
  static const String detailKontak = '/detail_kontak';

  static const Set<String> authRoutes = {
    getStarted,
    login,
    signup,
    forgotPassword,
  };
}
