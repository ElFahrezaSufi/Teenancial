import 'package:material_ui/material_ui.dart';
import '../models/transaction_model.dart';
import '../theme/app_colors.dart';
import 'date_helper.dart';

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

  static String formatDueDate(DateTime date) => DateHelper.formatShort(date);

  /// Selisih hari dari hari ini ke batas waktu (negatif = terlambat).
  /// Dibandingkan berdasarkan tanggal saja (tanpa jam).
  static int daysUntilDue(DateTime dueDate, {DateTime? now}) {
    final current = now ?? DateTime.now();
    return DateHelper.daysBetween(current, dueDate);
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
      return const LoanDueInfo(
        label: 'Jatuh tempo hari ini',
        color: orangeText,
      );
    }
    if (days <= 3) {
      return LoanDueInfo(label: '$days hari lagi', color: orangeText);
    }
    return LoanDueInfo(label: '$days hari lagi', color: primaryGreen);
  }

  /// Mengambil nama pihak lawan transaksi pinjaman dengan urutan prioritas:
  /// 1. Nama dari daftar kontak (`contactName`),
  /// 2. Field eksplisit `counterpartyName` pada dokumen transaksi,
  /// 3. Fallback parsing dari `title` ("Hutang dari X" / "Piutang ke X").
  static String counterpartyName(
    TransactionModel t, {
    String? contactName,
  }) {
    if (contactName != null && contactName.trim().isNotEmpty) {
      return contactName.trim();
    }
    if (t.counterpartyName != null && t.counterpartyName!.trim().isNotEmpty) {
      return t.counterpartyName!.trim();
    }
    return nameFromTitle(t.title);
  }

  /// Mengambil nama lawan transaksi dari judul ("Hutang dari X" / "Piutang ke X").
  static String nameFromTitle(String title) {
    return title
        .replaceFirst(RegExp(r'^(Hutang dari|Piutang ke)\s+'), '')
        .trim();
  }

  /// Bernilai `true` apabila pinjaman langsung dilunasi penuh tanpa cicilan
  /// bertahap (1 kali pembayaran lunas penuh atau data legacy lunas langsung).
  static bool isDirectFullSettlement(TransactionModel t) {
    return isLoan(t) && t.isPaid && t.payments.length <= 1;
  }

  /// Label badge pembayaran di kartu pinjaman:
  /// - `null` bila belum ada pembayaran dan belum lunas.
  /// - `'Bayar Penuh'` bila langsung dilunasi dalam 1 kali bayar penuh.
  /// - `'Nx cicilan'` bila dicicil bertahap (parsial atau lunas >= 2x bayar).
  static String? paymentBadgeLabel(TransactionModel t) {
    if (!isLoan(t)) return null;
    if (t.payments.isEmpty) {
      return t.isPaid ? 'Bayar Penuh' : null;
    }
    if (isDirectFullSettlement(t)) {
      return 'Bayar Penuh';
    }
    return '${t.payments.length}x cicilan';
  }

  /// Label menu/tindakan riwayat pembayaran pada kartu pinjaman.
  static String paymentHistoryLabel(TransactionModel t) {
    if (isDirectFullSettlement(t)) {
      return 'Detail Pelunasan';
    }
    return t.payments.isNotEmpty
        ? 'Riwayat Cicilan (${t.payments.length})'
        : 'Detail Pelunasan';
  }
}
