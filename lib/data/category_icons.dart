import 'package:flutter/material.dart';

/// Katalog ikon dan warna palet bertipe konstanta untuk kategori transaksi
/// (baik bawaan maupun kustom).
///
/// Menggunakan kunci string menuju `Icons.*` konstanta agar *icon tree-shaking*
/// saat `flutter build apk --release` tetap aman dan tidak merusak ikon.
class CategoryIcons {
  CategoryIcons._();

  static const Map<String, IconData> icons = {
    'money': Icons.attach_money,
    'gift': Icons.card_giftcard,
    'work': Icons.work_outline,
    'scholarship': Icons.workspace_premium,
    'savings': Icons.savings_outlined,
    'sell': Icons.storefront_outlined,
    'food': Icons.restaurant,
    'drink': Icons.local_cafe_outlined,
    'bus': Icons.directions_bus,
    'fuel': Icons.local_gas_station_outlined,
    'game': Icons.sports_esports,
    'movie': Icons.movie_outlined,
    'music': Icons.music_note_outlined,
    'shopping': Icons.shopping_bag_outlined,
    'cart': Icons.shopping_cart_outlined,
    'book': Icons.menu_book_outlined,
    'school': Icons.school,
    'wifi': Icons.wifi_rounded,
    'phone': Icons.phone_android_rounded,
    'receipt': Icons.receipt_long_outlined,
    'health': Icons.medical_services_outlined,
    'sport': Icons.fitness_center_rounded,
    'home': Icons.home_outlined,
    'pet': Icons.pets_outlined,
    'send': Icons.send,
    'swap': Icons.swap_horiz,
    'topup': Icons.account_balance_outlined,
    'charity': Icons.volunteer_activism,
    'family': Icons.family_restroom,
    'warning': Icons.warning_amber,
    'wallet': Icons.account_balance_wallet,
    'payment': Icons.payment,
    'category': Icons.category,
  };

  /// Daftar kunci ikon yang ditampilkan pada pemilih ikon kategori kustom.
  static List<String> get selectableKeys => icons.keys.toList(growable: false);

  /// Palet 10 warna ARGB yang selaras dengan tema Teenancial untuk lencana
  /// kategori dan irisan grafik laporan keuangan.
  static const List<int> palette = [
    0xFF627931, // Primary Green
    0xFFE18151, // Warm Orange
    0xFF2E7D6B, // Teal Green
    0xFFD9A441, // Golden Amber
    0xFF5C6BC0, // Indigo Blue
    0xFFEC407A, // Rose Pink
    0xFF26A69A, // Mint Teal
    0xFF8D6E63, // Earth Brown
    0xFF7E57C2, // Soft Purple
    0xFF78909C, // Slate Grey
  ];

  static IconData iconForKey(
    String? key, {
    IconData fallback = Icons.category,
  }) {
    if (key == null || key.isEmpty) return fallback;
    return icons[key] ?? fallback;
  }

  static String keyForIcon(IconData icon) {
    for (final entry in icons.entries) {
      if (entry.value.codePoint == icon.codePoint) {
        return entry.key;
      }
    }
    return 'category';
  }
}
