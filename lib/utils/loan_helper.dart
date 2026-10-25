import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/transaction_model.dart';
import '../theme/app_colors.dart';

/// Informasi status jatuh tempo suatu pinjaman (label + warna).
class LoanDueInfo {
  final String label;
  final Color color;
  final bool isOverdue;

  const LoanDueInfo({
    required this.label,
    required this.color,
    this.isOverdue = false,
  });
}

class LoanHelper {
  static const Color overdueColor = Color(0xFFD64545);

  static bool isLoan(TransactionModel t) =>
      t.type == TransactionType.debt || t.type == TransactionType.receivable;

  static String formatDueDate(DateTime date) =>
      DateFormat('dd MMM yyyy', 'id_ID').format(date);

  /// Selisih hari dari hari ini ke batas waktu (negatif = terlambat).
  /// Dibandingkan berdasarkan tanggal saja (tanpa jam).
  static int daysUntilDue(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  /// Mengembalikan null jika transaksi bukan pinjaman atau tidak punya batas waktu
  /// dan belum lunas.
  static LoanDueInfo? describe(TransactionModel t) {
    if (!isLoan(t)) return null;

    if (t.isPaid) {
      return const LoanDueInfo(label: 'Lunas', color: primaryGreen);
    }
    if (t.dueDate == null) return null;

    final days = daysUntilDue(t.dueDate!);
    if (days < 0) {
      return LoanDueInfo(
        label: 'Terlambat ${-days} hari',
        color: overdueColor,
        isOverdue: true,
      );
    }
    if (days == 0) {
      return const LoanDueInfo(label: 'Jatuh tempo hari ini', color: orangeText);
    }
    if (days <= 3) {
      return LoanDueInfo(label: '$days hari lagi', color: orangeText);
    }
    return LoanDueInfo(label: '$days hari lagi', color: primaryGreen);
  }

  /// Mengambil nama lawan transaksi dari judul ("Hutang dari X" / "Piutang ke X").
  static String nameFromTitle(String title) {
    return title
        .replaceFirst(RegExp(r'^(Hutang dari|Piutang ke)\s+'), '')
        .trim();
  }
}
