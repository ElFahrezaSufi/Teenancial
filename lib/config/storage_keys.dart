/// Semua kunci SharedPreferences dikumpulkan di sini agar tidak ada
/// string "ajaib" tersebar di kode.
class StorageKeys {
  StorageKeys._();

  // ---- Global (tidak terikat user) ----
  static const String users = 'users';
  static const String activeUserId = 'active_user_id';
  static const String schemaVersion = 'schema_version';

  // ---- Kunci lama (sebelum migrasi ke UserModel + UUID) ----
  static const String legacyUsers = 'mock_users';
  static const String legacyActiveEmail = 'active_user_email';

  // ---- Per user: diawali "u:{userId}:" agar data antar akun terpisah ----
  static String _scoped(String userId, String name) => 'u:$userId:$name';

  static String dompets(String userId) => _scoped(userId, 'dompets');
  static String transactions(String userId) => _scoped(userId, 'transactions');
  static String contacts(String userId) => _scoped(userId, 'contacts');
  static String targets(String userId) => _scoped(userId, 'targets');
  static String progress(String userId) => _scoped(userId, 'progress');
  static String seeded(String userId) => _scoped(userId, 'seeded');
}
