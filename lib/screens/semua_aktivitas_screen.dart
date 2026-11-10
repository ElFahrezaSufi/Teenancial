import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/category_catalog.dart';
import '../models/dompet_model.dart';
import '../models/transaction_filter.dart';
import '../providers/dompet_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../utils/transaction_actions.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/transaction/paged_transaction_list.dart';
import '../widgets/transaction/transaction_filter_sheet.dart';

/// Argumen navigasi opsional menuju [SemuaAktivitasScreen].
class SemuaAktivitasArgs {
  final int filterIndex;
  final bool autoFocusSearch;

  const SemuaAktivitasArgs({
    required this.filterIndex,
    this.autoFocusSearch = false,
  });
}

class SemuaAktivitasScreen extends StatefulWidget {
  final int filterIndex;
  final bool autoFocusSearch;

  const SemuaAktivitasScreen({
    super.key,
    this.filterIndex = 0,
    this.autoFocusSearch = false,
  });

  @override
  State<SemuaAktivitasScreen> createState() => _SemuaAktivitasScreenState();
}

class _SemuaAktivitasScreenState extends State<SemuaAktivitasScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late TransactionFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = TransactionFilter.fromFilterIndex(widget.filterIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final dompetProvider = context.read<DompetProvider>();
      if (dompetProvider.items.isEmpty && !dompetProvider.isLoading) {
        dompetProvider.loadDompets();
      }
      if (widget.autoFocusSearch) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _openFilterSheet(List<DompetItem> dompets) async {
    FocusScope.of(context).unfocus();
    final updated = await TransactionFilterSheet.show(
      context,
      initialFilter: _filter,
      dompets: dompets,
    );
    if (updated != null && mounted) {
      setState(() {
        _filter = updated.copyWith(query: _searchController.text);
      });
    }
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _filter = TransactionFilter(periodPreset: HistoryPeriodPreset.all);
    });
  }

  String _periodChipLabel() {
    if (_filter.periodPreset == HistoryPeriodPreset.custom &&
        _filter.customRange != null) {
      return '${DateHelper.formatShort(_filter.customRange!.start)} - ${DateHelper.formatShort(_filter.customRange!.end)}';
    }
    return _filter.periodPreset.label;
  }

  List<Widget> _buildActiveFilterChips(List<DompetItem> dompets) {
    final chips = <Widget>[];

    if (_filter.periodPreset != HistoryPeriodPreset.all) {
      chips.add(
        _ActiveChip(
          label: _periodChipLabel(),
          onRemove: () {
            setState(() {
              _filter = _filter.copyWith(
                periodPreset: HistoryPeriodPreset.all,
                clearCustomRange: true,
              );
            });
          },
        ),
      );
    }

    for (final t in _filter.types) {
      chips.add(
        _ActiveChip(
          label: TransactionFilterSheet.typeLabel(t),
          onRemove: () {
            final next = Set.of(_filter.types)..remove(t);
            setState(() => _filter = _filter.copyWith(types: next));
          },
        ),
      );
    }

    for (final dompetId in _filter.dompetIds) {
      final matches = dompets.where((d) => d.id == dompetId);
      final name = matches.isNotEmpty ? matches.first.nama : 'Dompet';
      chips.add(
        _ActiveChip(
          label: name,
          onRemove: () {
            final next = Set.of(_filter.dompetIds)..remove(dompetId);
            setState(() => _filter = _filter.copyWith(dompetIds: next));
          },
        ),
      );
    }

    for (final catId in _filter.categoryIds) {
      final cat = CategoryCatalog.getById(catId);
      chips.add(
        _ActiveChip(
          label: cat.name,
          onRemove: () {
            final next = Set.of(_filter.categoryIds)..remove(catId);
            setState(() => _filter = _filter.copyWith(categoryIds: next));
          },
        ),
      );
    }

    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final dompetProvider = context.watch<DompetProvider>();
    final dompets = dompetProvider.items;

    final filteredTransactions = _filter.apply(txProvider.transactions);
    final activeChips = _buildActiveFilterChips(dompets);
    final int activeBadgeCount = _filter.activeFilterCount;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: CustomAppBar(
        title: 'Semua Aktivitas',
        backIcon: Icons.arrow_back_ios_new,
        onBack: () => context.pop(true),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.4,
            child: Image.asset(
              'assets/images/bg_curve.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: primaryGreen,
                              width: 1.8,
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: (value) {
                              setState(() {
                                _filter = _filter.copyWith(query: value);
                              });
                            },
                            style: const TextStyle(
                              color: primaryGreen,
                              fontSize: 14,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Cari judul, catatan, kategori, nominal...',
                              hintStyle: TextStyle(
                                color: primaryGreen.withValues(alpha: 0.5),
                                fontSize: 13,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: primaryGreen,
                                size: 20,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        color: primaryGreen,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _filter = _filter.copyWith(query: '');
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _openFilterSheet(dompets),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              height: 48,
                              width: 48,
                              decoration: BoxDecoration(
                                color: activeBadgeCount > 0
                                    ? primaryGreen
                                    : cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: primaryGreen,
                                  width: 1.8,
                                ),
                              ),
                              child: Icon(
                                Icons.tune_rounded,
                                color: activeBadgeCount > 0
                                    ? Colors.white
                                    : primaryGreen,
                                size: 22,
                              ),
                            ),
                            if (activeBadgeCount > 0)
                              Positioned(
                                top: -5,
                                right: -5,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: orangeText,
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: scaffoldBg,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    '$activeBadgeCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w800,
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
                if (activeChips.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        ...activeChips.map(
                          (chip) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: chip,
                          ),
                        ),
                        if (activeChips.length > 1)
                          GestureDetector(
                            onTap: _clearAllFilters,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                'Reset',
                                style: TextStyle(
                                  color: orangeText,
                                  fontSize: 12,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: filteredTransactions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 52,
                                  color: primaryGreen.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _filter.isActive
                                      ? 'Tidak ada transaksi yang cocok dengan pencarian atau filter.'
                                      : 'Tidak ada aktivitas tercatat.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: primaryGreen,
                                    fontSize: 14,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_filter.isActive) ...[
                                  const SizedBox(height: 14),
                                  OutlinedButton.icon(
                                    onPressed: _clearAllFilters,
                                    icon: const Icon(
                                      Icons.filter_alt_off_outlined,
                                      size: 18,
                                      color: primaryGreen,
                                    ),
                                    label: const Text(
                                      'Hapus Filter',
                                      style: TextStyle(
                                        color: primaryGreen,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: primaryGreen,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : PagedTransactionList(
                          transactions: filteredTransactions,
                          formatCurrency: Formatters.rupiah,
                          onEdit: (item) =>
                              TransactionActions.edit(context, item),
                          onDelete: (id) =>
                              TransactionActions.delete(context, id),
                          onRefresh: () => context
                              .read<TransactionProvider>()
                              .loadTransactions(silent: true),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveChip({
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 6, top: 5, bottom: 5),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: primaryGreen, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: primaryGreen,
              fontSize: 11,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 15,
              color: primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}
