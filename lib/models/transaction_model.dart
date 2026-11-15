import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/category_catalog.dart';
import 'loan_payment.dart';

export 'category_model.dart';
export 'loan_payment.dart';

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
  final List<LoanPayment> payments; // Riwayat cicilan pinjaman/piutang
  final bool isAdjustment; // Penanda transaksi penyesuaian saldo otomatis saat edit dompet
  final String? recurringId; // ID template transaksi berulang (jika dibuat otomatis)

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
    List<LoanPayment> payments = const [],
    this.isAdjustment = false,
    this.recurringId,
  }) : payments = List<LoanPayment>.unmodifiable(payments);

  /// Menentukan apakah transaksi ini merupakan penyesuaian saldo otomatis
  /// (mendukung flag `isAdjustment` baru maupun catatan penyesuaian lama).
  bool get isBalanceAdjustment =>
      isAdjustment || notes == 'Penyesuaian saldo otomatis saat edit dompet';

  /// Menentukan apakah transaksi ini dapat diedit dari Riwayat maupun Daftar Pinjaman.
  /// Pinjaman yang sudah lunas tidak dapat diedit (hanya dapat dihapus).
  bool get isEditable {
    switch (type) {
      case TransactionType.income:
      case TransactionType.expense:
      case TransactionType.transfer:
        return true;
      case TransactionType.debt:
      case TransactionType.receivable:
        return !isPaid;
    }
  }

  /// Total nominal yang sudah dibayar/diterima untuk transaksi pinjaman.
  /// Kompatibel mundur dengan dokumen pinjaman lunas lama yang belum memiliki `payments`.
  double get paidAmount {
    if (payments.isNotEmpty) {
      return payments.fold(0.0, (double total, p) => total + p.amount);
    }
    return isPaid ? amount : 0.0;
  }

  /// Sisa tagihan pinjaman yang belum dibayar/diterima.
  double get remainingAmount {
    if (isPaid && payments.isEmpty) return 0.0;
    return (amount - paidAmount).clamp(0.0, double.infinity);
  }

  /// Menambahkan satu pembayaran cicilan baru dan memperbarui status `isPaid`
  /// secara otomatis apabila total cicilan telah mencapai `amount`.
  TransactionModel withPayment(LoanPayment payment) {
    if (type != TransactionType.debt && type != TransactionType.receivable) {
      throw Exception('Cicilan hanya berlaku untuk transaksi pinjaman');
    }
    if (isPaid || remainingAmount <= 0.0001) {
      throw Exception('Pinjaman ini sudah lunas');
    }
    if (payment.amount <= 0) {
      throw Exception('Nominal cicilan harus lebih dari Rp 0');
    }
    if (payment.amount > remainingAmount + 0.0001) {
      throw Exception('Nominal cicilan melebihi sisa tagihan');
    }

    final double normalizedAmount = payment.amount > remainingAmount
        ? remainingAmount
        : payment.amount;
    final normalizedPayment = payment.copyWith(amount: normalizedAmount);

    final updatedPayments = [...payments, normalizedPayment]
      ..sort((a, b) => a.date.compareTo(b.date));
    final double totalPaid =
        updatedPayments.fold(0.0, (double total, p) => total + p.amount);
    final bool nowPaid = totalPaid + 0.0001 >= amount;

    return copyWith(
      payments: updatedPayments,
      isPaid: nowPaid,
      paidDompetId: nowPaid ? normalizedPayment.dompetId : paidDompetId,
    );
  }

  /// Membatalkan/menghapus satu cicilan berdasarkan [paymentId] dan membuka
  /// kembali status pinjaman menjadi belum lunas bila total cicilan < `amount`.
  TransactionModel withoutPayment(String paymentId) {
    if (type != TransactionType.debt && type != TransactionType.receivable) {
      throw Exception('Operasi ini hanya berlaku untuk transaksi pinjaman');
    }
    final index = payments.indexWhere((p) => p.id == paymentId);
    if (index == -1) {
      throw Exception('Data cicilan tidak ditemukan');
    }

    final updatedPayments = [
      ...payments.sublist(0, index),
      ...payments.sublist(index + 1),
    ];
    final double totalPaid =
        updatedPayments.fold(0.0, (double total, p) => total + p.amount);
    final bool stillPaid = amount > 0 && totalPaid + 0.0001 >= amount;

    return copyWith(
      payments: updatedPayments,
      isPaid: stillPaid,
      paidDompetId: stillPaid && updatedPayments.isNotEmpty
          ? updatedPayments.last.dompetId
          : null,
      clearPaidDompetId: !stillPaid,
    );
  }

  /// Menghitung kontribusi bersih transaksi ini terhadap masing-masing dompet.
  /// Memastikan sinkronisasi saldo tetap konsisten saat tambah, ubah, hapus, & pelunasan/cicilan.
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
        if (payments.isNotEmpty) {
          for (final p in payments) {
            addDelta(p.dompetId, -p.amount);
          }
        } else if (isPaid) {
          addDelta(paidDompetId ?? dompetId, -amount);
        }
        break;
      case TransactionType.receivable:
        addDelta(dompetId, -amount);
        if (payments.isNotEmpty) {
          for (final p in payments) {
            addDelta(p.dompetId, p.amount);
          }
        } else if (isPaid) {
          addDelta(paidDompetId ?? dompetId, amount);
        }
        break;
    }

    return effects;
  }

  /// Mengembalikan daftar peristiwa perubahan saldo gabungan seluruh dompet
  /// beserta tanggal terjadinya (untuk grafik Tren Saldo di Riwayat).
  List<({DateTime date, double delta})> balanceEvents() {
    switch (type) {
      case TransactionType.income:
        return [(date: date, delta: amount)];
      case TransactionType.expense:
        return [(date: date, delta: -amount)];
      case TransactionType.transfer:
        if (destinationDompetId != null && destinationDompetId!.isNotEmpty) {
          return [(date: date, delta: 0.0)];
        }
        return [(date: date, delta: -amount)];
      case TransactionType.debt:
        final events = <({DateTime date, double delta})>[
          (date: date, delta: amount),
        ];
        if (payments.isNotEmpty) {
          for (final p in payments) {
            events.add((date: p.date, delta: -p.amount));
          }
        } else if (isPaid) {
          events.add((date: date, delta: -amount));
        }
        return events;
      case TransactionType.receivable:
        final events = <({DateTime date, double delta})>[
          (date: date, delta: -amount),
        ];
        if (payments.isNotEmpty) {
          for (final p in payments) {
            events.add((date: p.date, delta: p.amount));
          }
        } else if (isPaid) {
          events.add((date: date, delta: amount));
        }
        return events;
    }
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
      'payments': payments.map((p) => p.toMap()).toList(),
      'isAdjustment': isAdjustment,
      'recurringId': recurringId,
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

    final rawPayments = map['payments'];
    final List<LoanPayment> parsedPayments = [];
    if (rawPayments is Iterable) {
      for (final item in rawPayments) {
        if (item is Map) {
          parsedPayments.add(
            LoanPayment.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
      parsedPayments.sort((a, b) => a.date.compareTo(b.date));
    }

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
      payments: parsedPayments,
      isAdjustment: map['isAdjustment'] == true,
      recurringId: map['recurringId'] as String?,
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
    List<LoanPayment>? payments,
    bool? isAdjustment,
    String? recurringId,
    bool clearRecurringId = false,
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
      payments: payments ?? this.payments,
      isAdjustment: isAdjustment ?? this.isAdjustment,
      recurringId: clearRecurringId ? null : (recurringId ?? this.recurringId),
    );
  }
}
