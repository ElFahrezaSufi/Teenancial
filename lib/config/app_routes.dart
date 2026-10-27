/// Path rute terpusat agar tidak ada string path tersebar di kode.
class AppRoutes {
  AppRoutes._();

  // Auth & onboarding
  static const String splash = '/splash';
  static const String getStarted = '/get_started';
  static const String login = '/login';
  static const String signup = '/signup';

  // Tab utama (shell)
  static const String home = '/home';
  static const String dompet = '/dompet';
  static const String riwayat = '/riwayat';
  static const String profile = '/profile';

  /// Rute yang boleh dibuka tanpa login.
  static const Set<String> publicRoutes = {splash, getStarted, login, signup};

  /// Rute yang tidak relevan lagi bila pengguna sudah login.
  static const Set<String> authOnlyRoutes = {getStarted, login, signup};
}
