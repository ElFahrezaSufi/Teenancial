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
    ),
    CategoryModel(
      id: 'c2',
      name: 'Hadiah',
      type: TransactionType.income,
      icon: Icons.card_giftcard,
    ),
    CategoryModel(
      id: 'c19',
      name: 'Lainnya',
      type: TransactionType.income,
      icon: Icons.category,
    ),
    // Expense
    CategoryModel(
      id: 'c3',
      name: 'Makanan',
      type: TransactionType.expense,
      icon: Icons.restaurant,
    ),
    CategoryModel(
      id: 'c4',
      name: 'Transportasi',
      type: TransactionType.expense,
      icon: Icons.directions_bus,
    ),
    CategoryModel(
      id: 'c5',
      name: 'Hiburan',
      type: TransactionType.expense,
      icon: Icons.sports_esports,
    ),
    CategoryModel(
      id: 'c6',
      name: 'Lainnya',
      type: TransactionType.expense,
      icon: Icons.category,
    ),
    // Transfer
    CategoryModel(
      id: 'c7',
      name: 'Transfer Teman',
      type: TransactionType.transfer,
      icon: Icons.send,
    ),
    // 'c8' dipertahankan di katalog untuk kompatibilitas mundur transaksi lama,
    // namun disembunyikan dari pilihan Transfer baru agar pelunasan hutang
    // dilakukan melalui Daftar Pinjaman.
    CategoryModel(
      id: 'c8',
      name: 'Bayar Hutang',
      type: TransactionType.transfer,
      icon: Icons.payment,
    ),
    CategoryModel(
      id: 'c9',
      name: 'Donasi',
      type: TransactionType.transfer,
      icon: Icons.volunteer_activism,
    ),
    CategoryModel(
      id: 'c10',
      name: 'Transfer Lainnya',
      type: TransactionType.transfer,
      icon: Icons.swap_horiz,
    ),
    // Debt (Hutang)
    CategoryModel(
      id: 'c11',
      name: 'Teman Sekolah',
      type: TransactionType.debt,
      icon: Icons.school,
    ),
    CategoryModel(
      id: 'c12',
      name: 'Keluarga',
      type: TransactionType.debt,
      icon: Icons.family_restroom,
    ),
    CategoryModel(
      id: 'c13',
      name: 'Mendesak',
      type: TransactionType.debt,
      icon: Icons.warning_amber,
    ),
    CategoryModel(
      id: 'c14',
      name: 'Hutang Lainnya',
      type: TransactionType.debt,
      icon: Icons.account_balance_wallet,
    ),
    // Receivable (Piutang)
    CategoryModel(
      id: 'c15',
      name: 'Teman Sekolah',
      type: TransactionType.receivable,
      icon: Icons.school,
    ),
    CategoryModel(
      id: 'c16',
      name: 'Keluarga',
      type: TransactionType.receivable,
      icon: Icons.family_restroom,
    ),
    CategoryModel(
      id: 'c17',
      name: 'Mendesak',
      type: TransactionType.receivable,
      icon: Icons.warning_amber,
    ),
    CategoryModel(
      id: 'c18',
      name: 'Piutang Lainnya',
      type: TransactionType.receivable,
      icon: Icons.account_balance_wallet,
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
}
