import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../data/category_catalog.dart';
import '../models/dompet_model.dart';
import '../models/transaction_filter.dart';
import '../models/transaction_model.dart';
import 'currency_formatter.dart';
import 'loan_helper.dart';

class CsvExporter {
  CsvExporter._();

  static const String delimiter = ';';
  static const String lineEnding = '\r\n';
  static const List<int> utf8Bom = [0xEF, 0xBB, 0xBF];

  static const List<String> headers = [
    'Tanggal',
    'Jenis',
    'Judul',
    'Kategori',
    'Nominal (Rp)',
    'Dompet Sumber',
    'Dompet Tujuan',
    'Pihak Terkait',
    'Status Pinjaman',
    'Catatan',
    'Sumber Pencatatan',
  ];

  static final Set<String> _formulaPrefixes = {'=', '+', '-', '@', '\t', '\r'};

  /// Melakukan sanitasi CSV Injection (awalan `=`, `+`, `-`, `@`) dan
  /// pengutipan sesuai RFC 4180 untuk delimiter titik-koma (`;`).
  static String escapeCell(String raw, {bool isNumeric = false}) {
    if (raw.isEmpty) return '';

    String value = raw;
    if (!isNumeric) {
      final trimmedLeft = value.trimLeft();
      if (trimmedLeft.isNotEmpty &&
          _formulaPrefixes.contains(trimmedLeft[0])) {
        value = "'$value";
      }
    }

    final bool needsQuotes = value.contains(delimiter) ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');

    if (!needsQuotes) return value;
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  static String typeLabelForExport(TransactionModel tx) {
    switch (tx.type) {
      case TransactionType.income:
        return 'Pemasukan';
      case TransactionType.expense:
        return 'Pengeluaran';
      case TransactionType.transfer:
        final isInternal = tx.destinationDompetId != null &&
            tx.destinationDompetId!.trim().isNotEmpty;
        return isInternal ? 'Transfer Internal' : 'Transfer Keluar';
      case TransactionType.debt:
        return 'Hutang';
      case TransactionType.receivable:
        return 'Piutang';
    }
  }

  static String loanStatusLabel(TransactionModel tx) {
    if (tx.type != TransactionType.debt &&
        tx.type != TransactionType.receivable) {
      return '-';
    }
    if (tx.isPaid) return 'Lunas';
    if (tx.paidAmount > 0) {
      return 'Dicicil (Sisa ${Formatters.rupiah(tx.remainingAmount)})';
    }
    return 'Belum Lunas';
  }

  static String originLabel(TransactionModel tx) {
    if (tx.isBalanceAdjustment) return 'Penyesuaian Saldo';
    if (tx.recurringId != null && tx.recurringId!.trim().isNotEmpty) {
      return 'Berulang';
    }
    return 'Manual';
  }

  static String generateCsvString({
    required List<TransactionModel> transactions,
    required List<DompetItem> dompets,
    CategoryResolver? categoryResolver,
  }) {
    final resolveCategory = categoryResolver ?? CategoryCatalog.getById;
    final Map<String, String> walletNames = {
      for (final d in dompets) d.id: d.nama,
    };
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

    final sorted = List<TransactionModel>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    final buffer = StringBuffer();
    buffer.write(headers.map(escapeCell).join(delimiter));
    buffer.write(lineEnding);

    for (final tx in sorted) {
      final cat = resolveCategory(tx.categoryId, fallbackType: tx.type);
      final srcWallet = walletNames[tx.dompetId] ?? tx.dompetId;
      final dstWallet = (tx.destinationDompetId != null &&
              tx.destinationDompetId!.trim().isNotEmpty)
          ? (walletNames[tx.destinationDompetId!] ?? tx.destinationDompetId!)
          : '-';

      String counterparty = tx.counterpartyName?.trim() ?? '';
      if (counterparty.isEmpty && LoanHelper.isLoan(tx)) {
        counterparty = LoanHelper.counterpartyName(tx);
      }
      if (counterparty.isEmpty) {
        counterparty = '-';
      }

      final amountStr = tx.amount == tx.amount.roundToDouble()
          ? tx.amount.toStringAsFixed(0)
          : tx.amount.toStringAsFixed(2);

      final row = [
        escapeCell(dateFmt.format(tx.date)),
        escapeCell(typeLabelForExport(tx)),
        escapeCell(tx.title),
        escapeCell(cat.name),
        escapeCell(amountStr, isNumeric: true),
        escapeCell(srcWallet),
        escapeCell(dstWallet),
        escapeCell(counterparty),
        escapeCell(loanStatusLabel(tx)),
        escapeCell(tx.notes),
        escapeCell(originLabel(tx)),
      ];

      buffer.write(row.join(delimiter));
      buffer.write(lineEnding);
    }

    return buffer.toString();
  }

  /// Menghasilkan byte CSV lengkap dengan UTF-8 BOM (`0xEF, 0xBB, 0xBF`) di awal
  /// agar langsung terbaca rapi saat dibuka di Microsoft Excel maupun Google Sheets.
  static Uint8List generateCsvBytes({
    required List<TransactionModel> transactions,
    required List<DompetItem> dompets,
    CategoryResolver? categoryResolver,
  }) {
    final content = generateCsvString(
      transactions: transactions,
      dompets: dompets,
      categoryResolver: categoryResolver,
    );
    final bodyBytes = utf8.encode(content);
    final result = Uint8List(utf8Bom.length + bodyBytes.length);
    result.setRange(0, utf8Bom.length, utf8Bom);
    result.setRange(utf8Bom.length, result.length, bodyBytes);
    return result;
  }

  static String suggestedFileName(
    TransactionFilter filter, {
    String extension = 'csv',
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(effectiveNow);
    final periodSlug = filter.periodPreset.name;
    return 'teenancial_${periodSlug}_$stamp.$extension';
  }
}
