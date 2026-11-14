import 'package:flutter/material.dart';
import '../models/transaction_model.dart';

class CategoryCatalog {
  CategoryCatalog._();

  static const List<CategoryModel> categories = [
    // Income
    CategoryModel(
      id: 'c1',
      name: 'Uang Jajan',
      type: TransactionType.income,
      icon: Icons.attach_money,
      iconKey: 'money',
      colorValue: 0xFF627931,
    ),
    CategoryModel(
      id: 'c2',
      name: 'Hadiah',
      type: TransactionType.income,
      icon: Icons.card_giftcard,
      iconKey: 'gift',
      colorValue: 0xFFE18151,
    ),
    CategoryModel(
      id: 'c20',
      name: 'Gaji / Upah',
      type: TransactionType.income,
      icon: Icons.work_outline,
      iconKey: 'work',
      colorValue: 0xFF2E7D6B,
    ),
    CategoryModel(
      id: 'c21',
      name: 'Beasiswa',
      type: TransactionType.income,
      icon: Icons.workspace_premium,
      iconKey: 'scholarship',
      colorValue: 0xFFD9A441,
    ),
    CategoryModel(
      id: 'c19',
      name: 'Lainnya',
      type: TransactionType.income,
      icon: Icons.category,
      iconKey: 'category',
      colorValue: 0xFF78909C,
    ),
    // Expense
    CategoryModel(
      id: 'c3',
      name: 'Makanan',
      type: TransactionType.expense,
      icon: Icons.restaurant,
      iconKey: 'food',
      colorValue: 0xFFE18151,
    ),
    CategoryModel(
      id: 'c4',
      name: 'Transportasi',
      type: TransactionType.expense,
      icon: Icons.directions_bus,
      iconKey: 'bus',
      colorValue: 0xFF5C6BC0,
    ),
    CategoryModel(
      id: 'c5',
      name: 'Hiburan',
      type: TransactionType.expense,
      icon: Icons.sports_esports,
      iconKey: 'game',
      colorValue: 0xFF7E57C2,
    ),
    CategoryModel(
      id: 'c22',
      name: 'Pendidikan',
      type: TransactionType.expense,
      icon: Icons.menu_book_outlined,
      iconKey: 'book',
      colorValue: 0xFF2E7D6B,
    ),
    CategoryModel(
      id: 'c23',
      name: 'Belanja',
      type: TransactionType.expense,
      icon: Icons.shopping_bag_outlined,
      iconKey: 'shopping',
      colorValue: 0xFFEC407A,
    ),
    CategoryModel(
      id: 'c24',
      name: 'Tagihan & Kuota',
      type: TransactionType.expense,
      icon: Icons.wifi_rounded,
      iconKey: 'wifi',
      colorValue: 0xFFD9A441,
    ),
    CategoryModel(
      id: 'c25',
      name: 'Kesehatan',
      type: TransactionType.expense,
      icon: Icons.medical_services_outlined,
      iconKey: 'health',
      colorValue: 0xFF26A69A,
    ),
    CategoryModel(
      id: 'c6',
      name: 'Lainnya',
      type: TransactionType.expense,
      icon: Icons.category,
      iconKey: 'category',
      colorValue: 0xFF78909C,
    ),
    // Transfer
    CategoryModel(
      id: 'c26',
      name: 'Pindah Saldo / Top-Up',
      type: TransactionType.transfer,
      icon: Icons.account_balance_outlined,
      iconKey: 'topup',
      colorValue: 0xFF2E7D6B,
    ),
    CategoryModel(
      id: 'c7',
      name: 'Transfer Teman',
      type: TransactionType.transfer,
      icon: Icons.send,
      iconKey: 'send',
      colorValue: 0xFFE18151,
    ),
    // 'c8' dipertahankan di katalog untuk kompatibilitas mundur transaksi lama,
    // namun disembunyikan dari pilihan Transfer baru agar pelunasan hutang
    // dilakukan melalui Daftar Pinjaman.
    CategoryModel(
      id: 'c8',
      name: 'Bayar Hutang',
      type: TransactionType.transfer,
      icon: Icons.payment,
      iconKey: 'payment',
      colorValue: 0xFF8D6E63,
    ),
    CategoryModel(
      id: 'c9',
      name: 'Donasi',
      type: TransactionType.transfer,
      icon: Icons.volunteer_activism,
      iconKey: 'charity',
      colorValue: 0xFF26A69A,
    ),
    CategoryModel(
      id: 'c10',
      name: 'Transfer Lainnya',
      type: TransactionType.transfer,
      icon: Icons.swap_horiz,
      iconKey: 'swap',
      colorValue: 0xFF78909C,
    ),
    // Debt (Hutang)
    CategoryModel(
      id: 'c11',
      name: 'Teman Sekolah',
      type: TransactionType.debt,
      icon: Icons.school,
      iconKey: 'school',
      colorValue: 0xFF5C6BC0,
    ),
    CategoryModel(
      id: 'c12',
      name: 'Keluarga',
      type: TransactionType.debt,
      icon: Icons.family_restroom,
      iconKey: 'family',
      colorValue: 0xFF2E7D6B,
    ),
    CategoryModel(
      id: 'c13',
      name: 'Mendesak',
      type: TransactionType.debt,
      icon: Icons.warning_amber,
      iconKey: 'warning',
      colorValue: 0xFFE18151,
    ),
    CategoryModel(
      id: 'c14',
      name: 'Hutang Lainnya',
      type: TransactionType.debt,
      icon: Icons.account_balance_wallet,
      iconKey: 'wallet',
      colorValue: 0xFF78909C,
    ),
    // Receivable (Piutang)
    CategoryModel(
      id: 'c15',
      name: 'Teman Sekolah',
      type: TransactionType.receivable,
      icon: Icons.school,
      iconKey: 'school',
      colorValue: 0xFF5C6BC0,
    ),
    CategoryModel(
      id: 'c16',
      name: 'Keluarga',
      type: TransactionType.receivable,
      icon: Icons.family_restroom,
      iconKey: 'family',
      colorValue: 0xFF2E7D6B,
    ),
    CategoryModel(
      id: 'c17',
      name: 'Mendesak',
      type: TransactionType.receivable,
      icon: Icons.warning_amber,
      iconKey: 'warning',
      colorValue: 0xFFE18151,
    ),
    CategoryModel(
      id: 'c18',
      name: 'Piutang Lainnya',
      type: TransactionType.receivable,
      icon: Icons.account_balance_wallet,
      iconKey: 'wallet',
      colorValue: 0xFF78909C,
    ),
  ];

  static String defaultCategoryIdForType(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return 'c19';
      case TransactionType.expense:
        return 'c6';
      case TransactionType.transfer:
        return 'c10';
      case TransactionType.debt:
        return 'c14';
      case TransactionType.receivable:
        return 'c18';
    }
  }

  static CategoryModel getById(String id, {TransactionType? fallbackType}) {
    return categories.firstWhere(
      (cat) => cat.id == id,
      orElse: () {
        if (fallbackType != null) {
          final fallbackId = defaultCategoryIdForType(fallbackType);
          return categories.firstWhere(
            (cat) => cat.id == fallbackId,
            orElse: () => categories.last,
          );
        }
        return categories.last;
      },
    );
  }

  static List<CategoryModel> getByType(TransactionType type) {
    return categories
        .where((c) => c.type == type && c.id != 'c8')
        .toList();
  }

  /// Menggabungkan kategori bawaan dan kategori kustom pada `type` tertentu,
  /// dengan urutan: kategori bawaan (selain "Lainnya") -> kategori kustom ->
  /// kategori bawaan "Lainnya" di paling bawah.
  static List<CategoryModel> mergeWithCustom(
    TransactionType type,
    Iterable<CategoryModel> customCategories,
  ) {
    final builtIns = getByType(type);
    final leadingBuiltIns =
        builtIns.where((c) => !c.isDefaultFallback).toList();
    final trailingBuiltIns =
        builtIns.where((c) => c.isDefaultFallback).toList();
    final customsForType =
        customCategories.where((c) => c.type == type).toList();

    return [
      ...leadingBuiltIns,
      ...customsForType,
      ...trailingBuiltIns,
    ];
  }

  /// Mencari kategori berdasarkan `id` dari daftar kustom maupun katalog bawaan,
  /// dan jatuh ke kategori bawaan "Lainnya" jika tidak ditemukan.
  static CategoryModel resolveWithCustom(
    String id,
    Iterable<CategoryModel> customCategories, {
    TransactionType? fallbackType,
  }) {
    for (final custom in customCategories) {
      if (custom.id == id) return custom;
    }
    return getById(id, fallbackType: fallbackType);
  }
}
