import 'package:cloud_firestore/cloud_firestore.dart';

export 'category_model.dart';

enum TransactionType { income, expense, transfer, debt, receivable }

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String notes;
  final String categoryId;
  final TransactionType type;
  final String dompetId; // Dompet sumber (mandatory)
  final String? destinationDompetId; // Dompet tujuan khusus Transfer
  final DateTime? dueDate; // Batas waktu untuk pinjaman/piutang
  final String? contactId; // ID kontak terkait (teman/tujuan)
  final bool isPaid; // Status pelunasan (khusus hutang/piutang)
  final String? paidDompetId; // Dompet yang digunakan saat pelunasan pinjaman

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    this.notes = '',
    required this.categoryId,
    required this.type,
    required this.dompetId,
    this.destinationDompetId,
    this.dueDate,
    this.contactId,
    this.isPaid = false,
    this.paidDompetId,
  });

  /// Menghitung kontribusi bersih transaksi ini terhadap masing-masing dompet.
  /// Memastikan sinkronisasi saldo tetap konsisten saat tambah, ubah, hapus, & pelunasan.
  Map<String, double> walletEffects() {
    final effects = <String, double>{};

    void addDelta(String walletId, double delta) {
      if (walletId.isEmpty || delta == 0) return;
      effects[walletId] = (effects[walletId] ?? 0.0) + delta;
    }

    switch (type) {
      case TransactionType.income:
        addDelta(dompetId, amount);
        break;
      case TransactionType.expense:
        addDelta(dompetId, -amount);
        break;
      case TransactionType.transfer:
        addDelta(dompetId, -amount);
        if (destinationDompetId != null) {
          addDelta(destinationDompetId!, amount);
        }
        break;
      case TransactionType.debt:
        addDelta(dompetId, amount);
        if (isPaid) {
          addDelta(paidDompetId ?? dompetId, -amount);
        }
        break;
      case TransactionType.receivable:
        addDelta(dompetId, -amount);
        if (isPaid) {
          addDelta(paidDompetId ?? dompetId, amount);
        }
        break;
    }

    return effects;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'categoryId': categoryId,
      'type': type.name,
      'dompetId': dompetId,
      'destinationDompetId': destinationDompetId,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'contactId': contactId,
      'isPaid': isPaid,
      'paidDompetId': paidDompetId,
    };
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }

  factory TransactionModel.fromMap(
    Map<String, dynamic> map, {
    String? docId,
  }) {
    final typeStr = (map['type'] as String?) ?? TransactionType.expense.name;
    final parsedType = TransactionType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => TransactionType.expense,
    );

    return TransactionModel(
      id: docId ?? (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: _parseDateTime(map['date']) ?? DateTime.now(),
      notes: (map['notes'] as String?) ?? '',
      categoryId: (map['categoryId'] as String?) ?? 'c6',
      type: parsedType,
      dompetId: (map['dompetId'] as String?) ?? '',
      destinationDompetId: map['destinationDompetId'] as String?,
      dueDate: _parseDateTime(map['dueDate']),
      contactId: map['contactId'] as String?,
      isPaid: map['isPaid'] == true,
      paidDompetId: map['paidDompetId'] as String?,
    );
  }

  TransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    String? notes,
    String? categoryId,
    TransactionType? type,
    String? dompetId,
    String? destinationDompetId,
    DateTime? dueDate,
    String? contactId,
    bool? isPaid,
    String? paidDompetId,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      dompetId: dompetId ?? this.dompetId,
      destinationDompetId: destinationDompetId ?? this.destinationDompetId,
      dueDate: dueDate ?? this.dueDate,
      contactId: contactId ?? this.contactId,
      isPaid: isPaid ?? this.isPaid,
      paidDompetId: paidDompetId ?? this.paidDompetId,
    );
  }
}
