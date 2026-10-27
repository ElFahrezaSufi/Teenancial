/// Konstanta tingkat aplikasi.
class AppConfig {
  AppConfig._();

  static const String appName = 'Teenancial';

  /// Locale untuk pemformatan tanggal/angka.
  static const String locale = 'id_ID';

  /// Versi format data yang disimpan. Naikkan saat struktur JSON berubah
  /// agar migrasi bisa dilakukan.
  static const int storageSchemaVersion = 1;

  /// Akun contoh yang otomatis dibuat saat pertama kali aplikasi dibuka.
  static const String demoUserEmail = 'dummy@teenancial.com';
}
