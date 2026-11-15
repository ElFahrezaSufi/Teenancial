class AppConstants {
  AppConstants._();

  // Cloudinary Configuration
  static const String cloudinaryCloudName = 'vsgjbngi';
  static const String cloudinaryUploadPreset = 'Teenancial';
  static const String cloudinaryUploadUrl =
      'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload';

  // SharedPreferences Keys
  static const String prefHasSeenGetStarted = 'has_seen_get_started';
  static const String prefRiwayatFilterIndex = 'riwayat_filter_index';

  // Firestore Collection Names
  static const String usersCollection = 'users';
  static const String walletsSubcollection = 'wallets';
  static const String transactionsSubcollection = 'transactions';
  static const String contactsSubcollection = 'contacts';
  static const String targetsSubcollection = 'targets';
  static const String categoriesSubcollection = 'categories';
  static const String recurringSubcollection = 'recurring';
  static const String belajarLevelsCollection = 'belajar_levels';
  static const String belajarModulesCollection = 'belajar_modules';

  // Default Wallet for New Accounts
  static const String defaultNewWalletId = 'd1';
  static const String defaultNewWalletName = 'Dompet Tunai';
  static const double defaultNewWalletBalance = 0.0;
}
