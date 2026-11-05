import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/category_catalog.dart';

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
  final String? counterpartyName; // Nama pihak terkait untuk hutang/piutang
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
    this.counterpartyName,
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
      'counterpartyName': counterpartyName,
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
    final rawCategoryId = (map['categoryId'] as String?)?.trim() ?? '';

    return TransactionModel(
      id: docId ?? (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: _parseDateTime(map['date']) ?? DateTime.now(),
      notes: (map['notes'] as String?) ?? '',
      categoryId: rawCategoryId.isNotEmpty
          ? rawCategoryId
          : CategoryCatalog.defaultCategoryIdForType(parsedType),
      type: parsedType,
      dompetId: (map['dompetId'] as String?) ?? '',
      destinationDompetId: map['destinationDompetId'] as String?,
      dueDate: _parseDateTime(map['dueDate']),
      contactId: map['contactId'] as String?,
      counterpartyName: map['counterpartyName'] as String?,
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
    bool clearDestinationDompetId = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? contactId,
    bool clearContactId = false,
    String? counterpartyName,
    bool clearCounterpartyName = false,
    bool? isPaid,
    String? paidDompetId,
    bool clearPaidDompetId = false,
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
      destinationDompetId: clearDestinationDompetId
          ? null
          : (destinationDompetId ?? this.destinationDompetId),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      contactId: clearContactId ? null : (contactId ?? this.contactId),
      counterpartyName: clearCounterpartyName
          ? null
          : (counterpartyName ?? this.counterpartyName),
      isPaid: isPaid ?? this.isPaid,
      paidDompetId:
          clearPaidDompetId ? null : (paidDompetId ?? this.paidDompetId),
    );
  }
}
