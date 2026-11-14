import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../data/category_catalog.dart';
import '../models/dompet_model.dart';
import '../models/transaction_filter.dart';
import '../models/transaction_model.dart';
import 'csv_exporter.dart';
import 'currency_formatter.dart';
import 'date_helper.dart';
import 'report_calculator.dart';

class PdfReportBuilder {
  PdfReportBuilder._();

  static const PdfColor _brandGreen = PdfColor.fromInt(0xFF3E4F22);
  static const PdfColor _cardCream = PdfColor.fromInt(0xFFE7EFD0);
  static const PdfColor _lightBg = PdfColor.fromInt(0xFFF6F8EE);
  static const PdfColor _accentOrange = PdfColor.fromInt(0xFFD96B27);
  static const PdfColor _expenseRed = PdfColor.fromInt(0xFFC62828);
  static const PdfColor _mutedText = PdfColor.fromInt(0xFF5A6B42);

  /// Menghapus emoji dan simbol di luar Basic Multilingual Plane / blok piksel
  /// yang tidak didukung oleh font Inter agar tidak muncul kotak kosong (tofu) di PDF.
  static String sanitizePdfText(String input) {
    if (input.isEmpty) return '';
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final isEmojiOrSupplementary = rune > 0xFFFF ||
          (rune >= 0x2600 && rune <= 0x27BF) ||
          (rune >= 0xFE00 && rune <= 0xFE0F);
      if (!isEmojiOrSupplementary) {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static Future<pw.ThemeData> _loadPdfTheme() async {
    try {
      final regData =
          await rootBundle.load('assets/fonts/Inter_24pt-Regular.ttf');
      final semiData =
          await rootBundle.load('assets/fonts/Inter_24pt-SemiBold.ttf');
      final boldData =
          await rootBundle.load('assets/fonts/Inter_24pt-Bold.ttf');

      final regular = pw.Font.ttf(regData);
      final semiBold = pw.Font.ttf(semiData);
      final bold = pw.Font.ttf(boldData);

      return pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        italic: semiBold,
        boldItalic: bold,
      );
    } catch (_) {
      return pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );
    }
  }

  static String _describeFilterPeriod(TransactionFilter filter) {
    if (filter.periodPreset == HistoryPeriodPreset.custom &&
        filter.customRange != null) {
      return '${DateHelper.formatShort(filter.customRange!.start)} - ${DateHelper.formatShort(filter.customRange!.end)}';
    }
    return filter.periodPreset.label;
  }

  static List<CategoryBreakdownItem> _aggregateCategories(
    List<TransactionModel> transactions,
    bool Function(TransactionModel) predicate,
    CategoryResolver resolve,
  ) {
    final Map<String, ({double amount, int count, TransactionType sampleType})>
        buckets = {};
    double total = 0.0;

    for (final tx in transactions) {
      if (!predicate(tx)) continue;
      total += tx.amount;
      final existing = buckets[tx.categoryId];
      if (existing == null) {
        buckets[tx.categoryId] = (
          amount: tx.amount,
          count: 1,
          sampleType: tx.type,
        );
      } else {
        buckets[tx.categoryId] = (
          amount: existing.amount + tx.amount,
          count: existing.count + 1,
          sampleType: existing.sampleType,
        );
      }
    }

    if (buckets.isEmpty || total <= 0) return const [];

    final entries = buckets.entries.toList()
      ..sort((a, b) => b.value.amount.compareTo(a.value.amount));

    return entries.map((e) {
      final cat = resolve(e.key, fallbackType: e.value.sampleType);
      return CategoryBreakdownItem(
        categoryId: cat.id,
        categoryName: sanitizePdfText(cat.name),
        icon: cat.icon,
        color: cat.color,
        amount: e.value.amount,
        percentage: (e.value.amount / total) * 100.0,
        transactionCount: e.value.count,
      );
    }).toList(growable: false);
  }

  static Future<Uint8List> generatePdfBytes({
    required List<TransactionModel> transactions,
    required List<DompetItem> dompets,
    required TransactionFilter filter,
    CategoryResolver? categoryResolver,
    DateTime? generatedAt,
  }) async {
    final theme = await _loadPdfTheme();
    final resolveCategory = categoryResolver ?? CategoryCatalog.getById;
    final Map<String, String> walletNames = {
      for (final d in dompets) d.id: sanitizePdfText(d.nama),
    };

    final sorted = List<TransactionModel>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    double totalIncome = 0.0;
    double totalExpense = 0.0;
    for (final tx in sorted) {
      if (ReportCalculator.isReportIncome(tx)) {
        totalIncome += tx.amount;
      } else if (ReportCalculator.isReportExpense(tx)) {
        totalExpense += tx.amount;
      }
    }
    final double netCashflow = totalIncome - totalExpense;

    final expenseCategories = _aggregateCategories(
      sorted,
      ReportCalculator.isReportExpense,
      resolveCategory,
    );

    final now = generatedAt ?? DateTime.now();
    final generatedStamp = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(now);
    final dateCellFmt = DateFormat('dd/MM/yyyy HH:mm');

    final pdf = pw.Document(
      title: 'Laporan Keuangan Teenancial',
      author: 'Teenancial',
      theme: theme,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 36),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: _brandGreen, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Teenancial - Pencatat Keuangan Remaja',
                style: const pw.TextStyle(fontSize: 8.5, color: _mutedText),
              ),
              pw.Text(
                'Halaman ${context.pageNumber} dari ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: _brandGreen,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        build: (context) => [
          // 1. HEADER BANNER
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: _brandGreen,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TEENANCIAL',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Laporan Keuangan & Riwayat Aktivitas',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Periode: ${sanitizePdfText(_describeFilterPeriod(filter))}',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Dicetak: ${sanitizePdfText(generatedStamp)}',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 8.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // 2. KOTAK RINGKASAN EKSEKUTIF
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildSummaryBox(
                  label: 'Total Pemasukan',
                  value: '+ ${Formatters.rupiah(totalIncome)}',
                  valueColor: _brandGreen,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildSummaryBox(
                  label: 'Total Pengeluaran',
                  value: '- ${Formatters.rupiah(totalExpense)}',
                  valueColor: _expenseRed,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildSummaryBox(
                  label: netCashflow >= 0
                      ? 'Selisih Bersih (Surplus)'
                      : 'Selisih Bersih (Defisit)',
                  value:
                      '${netCashflow >= 0 ? '+' : '-'} ${Formatters.rupiah(netCashflow.abs())}',
                  valueColor: netCashflow >= 0 ? _brandGreen : _expenseRed,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // 3. PROPORSI PENGELUARAN PER KATEGORI
          if (expenseCategories.isNotEmpty) ...[
            pw.Text(
              'Proporsi Pengeluaran per Kategori',
              style: const pw.TextStyle(
                color: _brandGreen,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: _lightBg,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: _brandGreen, width: 0.6),
              ),
              child: pw.Column(
                children: expenseCategories.take(8).map((cat) {
                  final barWidthFactor =
                      (cat.percentage / 100.0).clamp(0.02, 1.0);
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              '${cat.categoryName} (${cat.transactionCount}x)',
                              style: const pw.TextStyle(
                                color: _brandGreen,
                                fontSize: 9.5,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              '${Formatters.rupiah(cat.amount)} (${cat.percentage.toStringAsFixed(1)}%)',
                              style: const pw.TextStyle(
                                color: _brandGreen,
                                fontSize: 9.5,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 3),
                        pw.Container(
                          height: 5,
                          width: 480 * barWidthFactor,
                          decoration: pw.BoxDecoration(
                            color: _accentOrange,
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // 4. TABEL RIWAYAT TRANSAKSI
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Daftar Transaksi (${sorted.length} item)',
                style: const pw.TextStyle(
                  color: _brandGreen,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: const pw.TextStyle(
              color: PdfColors.white,
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: const pw.BoxDecoration(color: _brandGreen),
            cellStyle: const pw.TextStyle(color: _brandGreen, fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 5,
            ),
            oddRowDecoration: const pw.BoxDecoration(color: _lightBg),
            columnWidths: {
              0: const pw.FixedColumnWidth(72),
              1: const pw.FixedColumnWidth(66),
              2: const pw.FlexColumnWidth(2.2),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.3),
              5: const pw.FixedColumnWidth(78),
            },
            headers: const [
              'Tanggal',
              'Jenis',
              'Judul & Catatan',
              'Kategori',
              'Dompet',
              'Nominal',
            ],
            data: sorted.map((tx) {
              final cat = resolveCategory(tx.categoryId, fallbackType: tx.type);
              final srcWallet = walletNames[tx.dompetId] ?? tx.dompetId;
              final isInternal = tx.type == TransactionType.transfer &&
                  tx.destinationDompetId != null &&
                  tx.destinationDompetId!.trim().isNotEmpty;
              final dstWallet = isInternal
                  ? (walletNames[tx.destinationDompetId!] ??
                      tx.destinationDompetId!)
                  : null;
              final walletCell =
                  dstWallet != null ? '$srcWallet -> $dstWallet' : srcWallet;

              final cleanTitle = sanitizePdfText(tx.title);
              final cleanNotes = sanitizePdfText(tx.notes);
              final titleCell = cleanNotes.isNotEmpty && cleanNotes != cleanTitle
                  ? '$cleanTitle ($cleanNotes)'
                  : cleanTitle;

              final isOutflow = tx.type == TransactionType.expense ||
                  tx.type == TransactionType.receivable ||
                  (tx.type == TransactionType.transfer && !isInternal);
              final sign = isInternal ? '' : (isOutflow ? '- ' : '+ ');

              return [
                dateCellFmt.format(tx.date),
                CsvExporter.typeLabelForExport(tx),
                titleCell,
                sanitizePdfText(cat.name),
                walletCell,
                '$sign${Formatters.rupiah(tx.amount)}',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryBox({
    required String label,
    required String value,
    required PdfColor valueColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _cardCream,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _brandGreen, width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              color: _mutedText,
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: valueColor,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
