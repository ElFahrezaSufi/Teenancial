import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/category_catalog.dart';
import '../models/dompet_model.dart';
import '../models/transaction_filter.dart';
import '../models/transaction_model.dart';
import '../providers/category_provider.dart';
import '../providers/dompet_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../utils/csv_exporter.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../utils/error_mapper.dart';
import '../utils/pdf_report_builder.dart';
import '../utils/report_calculator.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/transaction/transaction_filter_sheet.dart';

enum ExportFormat { csv, pdf }

typedef PdfBytesGenerator = Future<Uint8List> Function({
  required List<TransactionModel> transactions,
  required List<DompetItem> dompets,
  required TransactionFilter filter,
  CategoryResolver? categoryResolver,
  String? userName,
  String? userEmail,
});

class EksporScreen extends StatefulWidget {
  final TransactionFilter? initialFilter;
  final ExportFormat initialFormat;

  static PdfBytesGenerator? pdfGenerator;

  const EksporScreen({
    super.key,
    this.initialFilter,
    this.initialFormat = ExportFormat.csv,
  });

  @override
  State<EksporScreen> createState() => _EksporScreenState();
}

class _EksporScreenState extends State<EksporScreen> {
  late TransactionFilter _filter;
  late ExportFormat _format;
  late final TextEditingController _queryController;
  bool _showCategories = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ??
        TransactionFilter(periodPreset: HistoryPeriodPreset.monthly);
    _format = widget.initialFormat;
    _queryController = TextEditingController(text: _filter.query);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final txProvider = context.read<TransactionProvider>();
      final dompetProvider = context.read<DompetProvider>();
      final catProvider = Provider.of<CategoryProvider?>(
        context,
        listen: false,
      );
      if (txProvider.transactions.isEmpty && !txProvider.isLoading) {
        txProvider.loadTransactions(silent: true);
      }
      if (dompetProvider.items.isEmpty && !dompetProvider.isLoading) {
        dompetProvider.loadDompets(silent: true);
      }
      if (catProvider != null &&
          catProvider.customCategories.isEmpty &&
          !catProvider.isLoading) {
        catProvider.loadCategories(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomDateRange() async {
    final today = DateHelper.dateOnly(DateTime.now());
    final current = _filter.customRange ??
        DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: today,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: current.start.isAfter(today) ? today : current.start,
        end: current.end.isAfter(today) ? today : current.end,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryGreen,
              onPrimary: Colors.white,
              onSurface: primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _filter = _filter.copyWith(
          periodPreset: HistoryPeriodPreset.custom,
          customRange: picked,
        );
      });
    }
  }

  void _toggleType(TransactionType type, CategoryProvider? catProvider) {
    final nextTypes = Set<TransactionType>.from(_filter.types);
    if (nextTypes.contains(type)) {
      nextTypes.remove(type);
    } else {
      nextTypes.add(type);
    }

    final nextCategories = Set<String>.from(_filter.categoryIds);
    if (nextTypes.isNotEmpty) {
      final allowed = nextTypes
          .expand(
            (t) => catProvider != null
                ? catProvider.categoriesFor(t)
                : CategoryCatalog.getByType(t),
          )
          .map((c) => c.id)
          .toSet();
      nextCategories.removeWhere((id) => !allowed.contains(id));
    }

    setState(() {
      _filter = _filter.copyWith(
        types: nextTypes,
        categoryIds: nextCategories,
      );
    });
  }

  void _toggleDompet(String dompetId) {
    final next = Set<String>.from(_filter.dompetIds);
    if (next.contains(dompetId)) {
      next.remove(dompetId);
    } else {
      next.add(dompetId);
    }
    setState(() {
      _filter = _filter.copyWith(dompetIds: next);
    });
  }

  void _toggleCategory(String categoryId) {
    final next = Set<String>.from(_filter.categoryIds);
    if (next.contains(categoryId)) {
      next.remove(categoryId);
    } else {
      next.add(categoryId);
    }
    setState(() {
      _filter = _filter.copyWith(categoryIds: next);
    });
  }

  void _resetFilters() {
    _queryController.clear();
    setState(() {
      _filter = TransactionFilter(periodPreset: HistoryPeriodPreset.all);
    });
  }

  Future<({Uint8List bytes, String fileName, String mimeType})> _buildPayload({
    required List<TransactionModel> filteredTransactions,
    required List<DompetItem> dompets,
    required CategoryResolver? categoryResolver,
  }) async {
    if (_format == ExportFormat.csv) {
      final bytes = CsvExporter.generateCsvBytes(
        transactions: filteredTransactions,
        dompets: dompets,
        categoryResolver: categoryResolver,
      );
      final fileName = CsvExporter.suggestedFileName(_filter, extension: 'csv');
      return (bytes: bytes, fileName: fileName, mimeType: 'text/csv');
    }

    final userProvider = Provider.of<UserProvider?>(context, listen: false);
    final pdfGen = EksporScreen.pdfGenerator ?? PdfReportBuilder.generatePdfBytes;
    final bytes = await pdfGen(
      transactions: filteredTransactions,
      dompets: dompets,
      filter: _filter,
      categoryResolver: categoryResolver,
      userName: userProvider?.displayName,
      userEmail: userProvider?.profile?.email,
    );
    final fileName = CsvExporter.suggestedFileName(_filter, extension: 'pdf');
    return (bytes: bytes, fileName: fileName, mimeType: 'application/pdf');
  }

  Future<void> _saveToDevice({
    required List<TransactionModel> filteredTransactions,
    required List<DompetItem> dompets,
    required CategoryResolver? categoryResolver,
  }) async {
    if (filteredTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada transaksi yang cocok untuk diekspor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isBusy = true);
    try {
      final payload = await _buildPayload(
        filteredTransactions: filteredTransactions,
        dompets: dompets,
        categoryResolver: categoryResolver,
      );

      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Simpan Laporan Teenancial',
        fileName: payload.fileName,
        bytes: payload.bytes,
      );

      if (savedPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ File ${payload.fileName} berhasil disimpan!'),
            backgroundColor: primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMapper.message(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _shareFile({
    required List<TransactionModel> filteredTransactions,
    required List<DompetItem> dompets,
    required CategoryResolver? categoryResolver,
  }) async {
    if (filteredTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada transaksi yang cocok untuk dibagikan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isBusy = true);
    try {
      final payload = await _buildPayload(
        filteredTransactions: filteredTransactions,
        dompets: dompets,
        categoryResolver: categoryResolver,
      );

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${payload.fileName}');
      await tempFile.writeAsBytes(payload.bytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path, mimeType: payload.mimeType)],
          subject: 'Laporan Keuangan Teenancial (${payload.fileName})',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMapper.message(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final dompetProvider = context.watch<DompetProvider>();
    final catProvider = Provider.of<CategoryProvider?>(context);
    final dompets = dompetProvider.items;

    final filtered = _filter.apply(
      txProvider.transactions,
      categoryResolver: catProvider?.resolve,
    );

    double previewIncome = 0.0;
    double previewExpense = 0.0;
    for (final tx in filtered) {
      if (ReportCalculator.isReportIncome(tx)) {
        previewIncome += tx.amount;
      } else if (ReportCalculator.isReportExpense(tx)) {
        previewExpense += tx.amount;
      }
    }
    final double previewNet = previewIncome - previewExpense;
    final bool isNetPositive = previewNet >= 0;
    final bool canExport = !_isBusy && filtered.isNotEmpty;

    final typesToShowCategories = _filter.types.isNotEmpty
        ? TransactionType.values
            .where((t) => _filter.types.contains(t))
            .toList()
        : TransactionType.values;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: const CustomAppBar(
        title: 'Ekspor Data',
        backIcon: Icons.arrow_back_ios_new,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.4,
            child: Image.asset(
              'assets/images/bg_curve.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionHeader('Format Ekspor'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildFormatOption(
                                format: ExportFormat.csv,
                                title: 'CSV (.csv)',
                                subtitle: 'Tabel Excel / Sheets',
                                icon: Icons.table_chart_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFormatOption(
                                format: ExportFormat.pdf,
                                title: 'PDF (.pdf)',
                                subtitle: 'Laporan + Ringkasan',
                                icon: Icons.picture_as_pdf_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSectionHeader('Filter Data yang Diekspor'),
                            if (_filter.isActive)
                              GestureDetector(
                                onTap: _resetFilters,
                                child: const Text(
                                  'Reset Semua',
                                  style: TextStyle(
                                    color: orangeText,
                                    fontSize: 12,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        CustomCard(
                          backgroundColor: cardBg,
                          borderRadius: 16,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSubLabel('Periode Waktu'),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    HistoryPeriodPreset.values.map((preset) {
                                  final selected =
                                      _filter.periodPreset == preset;
                                  return _buildChip(
                                    label: preset.label,
                                    selected: selected,
                                    icon: preset == HistoryPeriodPreset.custom
                                        ? Icons.date_range_outlined
                                        : null,
                                    onTap: () {
                                      if (preset ==
                                          HistoryPeriodPreset.custom) {
                                        _pickCustomDateRange();
                                      } else {
                                        setState(() {
                                          _filter = _filter.copyWith(
                                            periodPreset: preset,
                                            clearCustomRange: true,
                                          );
                                        });
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                              if (_filter.periodPreset ==
                                      HistoryPeriodPreset.custom &&
                                  _filter.customRange != null) ...[
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap: _pickCustomDateRange,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scaffoldBg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: primaryGreen,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${DateHelper.formatShort(_filter.customRange!.start)} - ${DateHelper.formatShort(_filter.customRange!.end)}',
                                          style: const TextStyle(
                                            color: primaryGreen,
                                            fontSize: 12,
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const Text(
                                          'Ubah',
                                          style: TextStyle(
                                            color: orangeText,
                                            fontSize: 12,
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              _buildSubLabel('Jenis Transaksi'),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: TransactionType.values.map((t) {
                                  return _buildChip(
                                    label: TransactionFilterSheet.typeLabel(t),
                                    selected: _filter.types.contains(t),
                                    onTap: () => _toggleType(t, catProvider),
                                  );
                                }).toList(),
                              ),
                              if (dompets.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _buildSubLabel('Dompet'),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: dompets.map((d) {
                                    return _buildChip(
                                      label: d.nama,
                                      selected:
                                          _filter.dompetIds.contains(d.id),
                                      icon:
                                          Icons.account_balance_wallet_outlined,
                                      onTap: () => _toggleDompet(d.id),
                                    );
                                  }).toList(),
                                ),
                              ],
                              const SizedBox(height: 14),
                              GestureDetector(
                                onTap: () {
                                  setState(
                                    () => _showCategories = !_showCategories,
                                  );
                                },
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _filter.categoryIds.isEmpty
                                          ? 'Kategori (Semua Kategori)'
                                          : 'Kategori (${_filter.categoryIds.length} dipilih)',
                                      style: const TextStyle(
                                        color: primaryGreen,
                                        fontSize: 12,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Icon(
                                      _showCategories
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      color: primaryGreen,
                                    ),
                                  ],
                                ),
                              ),
                              if (_showCategories) ...[
                                const SizedBox(height: 8),
                                ...typesToShowCategories.map((type) {
                                  final cats = catProvider != null
                                      ? catProvider.categoriesFor(type)
                                      : CategoryCatalog.getByType(type);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          TransactionFilterSheet.typeLabel(
                                            type,
                                          ),
                                          style: TextStyle(
                                            color: primaryGreen.withValues(
                                              alpha: 0.7,
                                            ),
                                            fontSize: 11,
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: cats.map((cat) {
                                            return _buildChip(
                                              label: cat.name,
                                              icon: cat.icon,
                                              iconColor: cat.color,
                                              selected: _filter.categoryIds
                                                  .contains(cat.id),
                                              onTap: () =>
                                                  _toggleCategory(cat.id),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              const SizedBox(height: 12),
                              _buildSubLabel('Kata Kunci (Opsional)'),
                              Container(
                                decoration: BoxDecoration(
                                  color: inputBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: primaryGreen,
                                    width: 1.4,
                                  ),
                                ),
                                child: TextField(
                                  controller: _queryController,
                                  onChanged: (val) {
                                    setState(() {
                                      _filter = _filter.copyWith(query: val);
                                    });
                                  },
                                  style: const TextStyle(
                                    color: primaryGreen,
                                    fontSize: 13,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Filter judul, catatan, pihak terkait...',
                                    hintStyle: TextStyle(
                                      color:
                                          primaryGreen.withValues(alpha: 0.5),
                                      fontSize: 12,
                                      fontFamily: 'Inter',
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: primaryGreen,
                                      size: 18,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildSectionHeader('Pratinjau Hasil Ekspor'),
                        const SizedBox(height: 8),
                        CustomCard(
                          backgroundColor: const Color(0xFFF8FFE8),
                          borderRadius: 16,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildPreviewRow(
                                'Transaksi Cocok',
                                '${filtered.length} transaksi',
                                isBold: true,
                              ),
                              const SizedBox(height: 6),
                              _buildPreviewRow(
                                'Total Pemasukan',
                                '+ ${Formatters.rupiah(previewIncome)}',
                                valueColor: primaryGreen,
                              ),
                              const SizedBox(height: 6),
                              _buildPreviewRow(
                                'Total Pengeluaran',
                                '- ${Formatters.rupiah(previewExpense)}',
                                valueColor: const Color(0xFFC62828),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Divider(
                                  height: 1,
                                  color: primaryGreen.withValues(alpha: 0.2),
                                ),
                              ),
                              _buildPreviewRow(
                                'Selisih Bersih',
                                '${isNetPositive ? '+' : '-'} ${Formatters.rupiah(previewNet.abs())}',
                                isBold: true,
                                valueColor: isNetPositive
                                    ? primaryGreen
                                    : const Color(0xFFC62828),
                              ),
                              if (filtered.isEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryGreen.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 16,
                                        color: primaryGreen,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Tidak ada transaksi yang cocok dengan filter. Sesuaikan filter untuk mengekspor data.',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: primaryGreen,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  decoration: BoxDecoration(
                    color: scaffoldBg,
                    border: Border(
                      top: BorderSide(
                        color: primaryGreen.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: canExport
                              ? () => _shareFile(
                                    filteredTransactions: filtered,
                                    dompets: dompets,
                                    categoryResolver: catProvider?.resolve,
                                  )
                              : null,
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text(
                            'Bagikan',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryGreen,
                            disabledForegroundColor:
                                primaryGreen.withValues(alpha: 0.4),
                            side: BorderSide(
                              color: canExport
                                  ? primaryGreen
                                  : primaryGreen.withValues(alpha: 0.3),
                              width: 1.6,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: canExport
                              ? () => _saveToDevice(
                                    filteredTransactions: filtered,
                                    dompets: dompets,
                                    categoryResolver: catProvider?.resolve,
                                  )
                              : null,
                          icon: const Icon(Icons.save_alt_rounded, size: 19),
                          label: Text(
                            _isBusy ? 'Memproses...' : 'Simpan ke Perangkat',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                primaryGreen.withValues(alpha: 0.35),
                            disabledForegroundColor:
                                Colors.white.withValues(alpha: 0.8),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: primaryGreen,
        fontSize: 14,
        fontFamily: 'Inter',
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildSubLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: primaryGreen,
          fontSize: 12,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildFormatOption({
    required ExportFormat format,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _format == format;
    return GestureDetector(
      onTap: () => setState(() => _format = format),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? primaryGreen : cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryGreen, width: 1.6),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : primaryGreen,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? Colors.white : primaryGreen,
                      fontSize: 13.5,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.85)
                          : primaryGreen.withValues(alpha: 0.7),
                      fontSize: 10.5,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? primaryGreen : scaffoldBg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: primaryGreen, width: 1.3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected ? Colors.white : (iconColor ?? primaryGreen),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : primaryGreen,
                fontSize: 11.5,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewRow(
    String label,
    String value, {
    Color valueColor = primaryGreen,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: primaryGreen.withValues(alpha: 0.8),
            fontSize: 12,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: isBold ? 13.5 : 12.5,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
