import 'package:cloud_firestore/cloud_firestore.dart';

/// Catatan satu kali pembayaran cicilan atau pelunasan pada transaksi pinjaman
/// (hutang maupun piutang).
class LoanPayment {
  final String id;
  final double amount;
  final DateTime date;
  final String dompetId;
  final String? note;

  const LoanPayment({
    required this.id,
    required this.amount,
    required this.date,
    required this.dompetId,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'dompetId': dompetId,
      if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
    };
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return DateTime.now();
  }

  factory LoanPayment.fromMap(Map<String, dynamic> map) {
    final rawNote = (map['note'] as String?)?.trim();
    return LoanPayment(
      id: (map['id'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: _parseDate(map['date']),
      dompetId: (map['dompetId'] as String?) ?? '',
      note: (rawNote != null && rawNote.isNotEmpty) ? rawNote : null,
    );
  }

  LoanPayment copyWith({
    String? id,
    double? amount,
    DateTime? date,
    String? dompetId,
    String? note,
    bool clearNote = false,
  }) {
    return LoanPayment(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      dompetId: dompetId ?? this.dompetId,
      note: clearNote ? null : (note ?? this.note),
    );
  }
}
