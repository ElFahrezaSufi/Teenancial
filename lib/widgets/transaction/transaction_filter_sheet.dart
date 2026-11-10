import 'package:flutter/material.dart';
import '../../data/category_catalog.dart';
import '../../models/dompet_model.dart';
import '../../models/transaction_filter.dart';
import '../../models/transaction_model.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_helper.dart';

/// Bottom sheet untuk memilih kriteria filter (periode/rentang tanggal, jenis,
/// kategori, dan dompet) pada halaman Semua Aktivitas.
class TransactionFilterSheet extends StatefulWidget {
  final TransactionFilter initialFilter;
  final List<DompetItem> dompets;

  const TransactionFilterSheet({
    super.key,
    required this.initialFilter,
    required this.dompets,
  });

  static Future<TransactionFilter?> show(
    BuildContext context, {
    required TransactionFilter initialFilter,
    required List<DompetItem> dompets,
  }) {
    return showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TransactionFilterSheet(
        initialFilter: initialFilter,
        dompets: dompets,
      ),
    );
  }

  static String typeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return 'Pemasukan';
      case TransactionType.expense:
        return 'Pengeluaran';
      case TransactionType.transfer:
        return 'Transfer';
      case TransactionType.debt:
        return 'Hutang';
      case TransactionType.receivable:
        return 'Piutang';
    }
  }

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  late Set<TransactionType> _selectedTypes;
  late Set<String> _selectedCategoryIds;
  late Set<String> _selectedDompetIds;
  late HistoryPeriodPreset _periodPreset;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _selectedTypes = Set<TransactionType>.from(widget.initialFilter.types);
    _selectedCategoryIds = Set<String>.from(widget.initialFilter.categoryIds);
    _selectedDompetIds = Set<String>.from(widget.initialFilter.dompetIds);
    _periodPreset = widget.initialFilter.periodPreset;
    _customRange = widget.initialFilter.customRange;
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final today = DateHelper.dateOnly(now);
    final initialRange = _customRange ??
        DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: initialRange.start.isAfter(today) ? today : initialRange.start,
        end: initialRange.end.isAfter(today) ? today : initialRange.end,
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
        _periodPreset = HistoryPeriodPreset.custom;
        _customRange = picked;
      });
    }
  }

  void _toggleType(TransactionType type) {
    setState(() {
      if (_selectedTypes.contains(type)) {
        _selectedTypes.remove(type);
      } else {
        _selectedTypes.add(type);
      }
      if (_selectedTypes.isNotEmpty) {
        final allowedCategoryIds = _selectedTypes
            .expand((t) => CategoryCatalog.getByType(t))
            .map((c) => c.id)
            .toSet();
        _selectedCategoryIds.removeWhere(
          (id) => !allowedCategoryIds.contains(id),
        );
      }
    });
  }

  void _toggleCategory(String categoryId) {
    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
    });
  }

  void _toggleDompet(String dompetId) {
    setState(() {
      if (_selectedDompetIds.contains(dompetId)) {
        _selectedDompetIds.remove(dompetId);
      } else {
        _selectedDompetIds.add(dompetId);
      }
    });
  }

  void _resetAll() {
    setState(() {
      _selectedTypes.clear();
      _selectedCategoryIds.clear();
      _selectedDompetIds.clear();
      _periodPreset = HistoryPeriodPreset.all;
      _customRange = null;
    });
  }

  void _apply() {
    final effectivePreset =
        (_periodPreset == HistoryPeriodPreset.custom && _customRange == null)
            ? HistoryPeriodPreset.all
            : _periodPreset;
    final result = widget.initialFilter.copyWith(
      types: _selectedTypes,
      categoryIds: _selectedCategoryIds,
      dompetIds: _selectedDompetIds,
      periodPreset: effectivePreset,
      customRange: _customRange,
      clearCustomRange: effectivePreset != HistoryPeriodPreset.custom,
    );
    Navigator.of(context).pop(result);
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: primaryGreen,
          fontSize: 13,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSelectableChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primaryGreen : cardBg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: primaryGreen,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : primaryGreen,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : primaryGreen,
                fontSize: 12,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typesToShowCategories = _selectedTypes.isNotEmpty
        ? TransactionType.values
            .where((t) => _selectedTypes.contains(t))
            .toList()
        : TransactionType.values;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: primaryGreen.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Aktivitas',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 18,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextButton(
                    onPressed: _resetAll,
                    child: const Text(
                      'Reset Semua',
                      style: TextStyle(
                        color: orangeText,
                        fontSize: 13,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Periode Waktu'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: HistoryPeriodPreset.values.map((preset) {
                          final isSelected = _periodPreset == preset;
                          return _buildSelectableChip(
                            label: preset.label,
                            selected: isSelected,
                            icon: preset == HistoryPeriodPreset.custom
                                ? Icons.date_range_outlined
                                : null,
                            onTap: () {
                              if (preset == HistoryPeriodPreset.custom) {
                                _pickCustomDateRange();
                              } else {
                                setState(() {
                                  _periodPreset = preset;
                                  _customRange = null;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                      if (_periodPreset == HistoryPeriodPreset.custom &&
                          _customRange != null) ...[
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _pickCustomDateRange,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: primaryGreen, width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 15,
                                      color: primaryGreen,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${DateHelper.formatShort(_customRange!.start)} - ${DateHelper.formatShort(_customRange!.end)}',
                                      style: const TextStyle(
                                        color: primaryGreen,
                                        fontSize: 13,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
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
                      const SizedBox(height: 18),
                      _buildSectionTitle('Jenis Transaksi'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: TransactionType.values.map((t) {
                          return _buildSelectableChip(
                            label: TransactionFilterSheet.typeLabel(t),
                            selected: _selectedTypes.contains(t),
                            onTap: () => _toggleType(t),
                          );
                        }).toList(),
                      ),
                      if (widget.dompets.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _buildSectionTitle('Dompet'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.dompets.map((d) {
                            return _buildSelectableChip(
                              label: d.nama,
                              selected: _selectedDompetIds.contains(d.id),
                              icon: Icons.account_balance_wallet_outlined,
                              onTap: () => _toggleDompet(d.id),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _buildSectionTitle('Kategori'),
                      ...typesToShowCategories.map((type) {
                        final cats = CategoryCatalog.getByType(type);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                TransactionFilterSheet.typeLabel(type),
                                style: TextStyle(
                                  color: primaryGreen.withValues(alpha: 0.75),
                                  fontSize: 11,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: cats.map((cat) {
                                  return _buildSelectableChip(
                                    label: cat.name,
                                    icon: cat.icon,
                                    selected:
                                        _selectedCategoryIds.contains(cat.id),
                                    onTap: () => _toggleCategory(cat.id),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryGreen,
                        side:
                            const BorderSide(color: primaryGreen, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: const Text(
                        'Terapkan Filter',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
