enum TransactionType { food, transport, income, entertainment, other }

enum JenisDompet { cash, accounts, card }

extension JenisDompetLabel on JenisDompet {
  String get label {
    switch (this) {
      case JenisDompet.cash:
        return 'Cash';
      case JenisDompet.accounts:
        return 'Accounts';
      case JenisDompet.card:
        return 'Card';
    }
  }
}

class DompetItem {
  final String id;
  JenisDompet jenis;
  String nama;
  double jumlah;
  String? catatan;

  DompetItem({
    required this.id,
    required this.jenis,
    required this.nama,
    required this.jumlah,
    this.catatan,
  });
}

class Category {
  final String id;
  final String nama;
  final bool isExpense;
  final TransactionType type;
  final bool system;

  const Category({
    required this.id,
    required this.nama,
    required this.isExpense,
    required this.type,
    this.system = false,
  });
}

class AppTransaction {
  final String id;
  final String walletId;
  final String categoryId;
  final bool isExpense;
  final double amount;
  final String note;
  final DateTime date;

  const AppTransaction({
    required this.id,
    required this.walletId,
    required this.categoryId,
    required this.isExpense,
    required this.amount,
    required this.note,
    required this.date,
  });

  AppTransaction copyWith({
    String? walletId,
    String? categoryId,
    bool? isExpense,
    double? amount,
    String? note,
    DateTime? date,
  }) {
    return AppTransaction(
      id: id,
      walletId: walletId ?? this.walletId,
      categoryId: categoryId ?? this.categoryId,
      isExpense: isExpense ?? this.isExpense,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      date: date ?? this.date,
    );
  }
}
