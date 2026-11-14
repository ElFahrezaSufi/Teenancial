import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../data/category_catalog.dart';
import '../models/dompet_model.dart';
import '../models/recurring_model.dart';
import '../models/transaction_model.dart';
import '../providers/category_provider.dart';
import '../providers/dompet_provider.dart';
import '../providers/recurring_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../utils/error_mapper.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/common/custom_filter_chip.dart';
import '../widgets/common/primary_button.dart';
import 'buat_berulang_screen.dart';

class TransaksiBerulangScreen extends StatefulWidget {
  final TransactionType? initialType;

  const TransaksiBerulangScreen({
    super.key,
    this.initialType,
  });

  @override
  State<TransaksiBerulangScreen> createState() =>
      _TransaksiBerulangScreenState();
}

class _TransaksiBerulangScreenState extends State<TransaksiBerulangScreen> {
  TransactionType? _selectedFilterType;

  bool get _isLockedToType => widget.initialType != null;

  static const List<TransactionType?> _riwayatTabs = [
    null,
    TransactionType.income,
    TransactionType.expense,
    TransactionType.transfer,
  ];

  static String _typeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return 'Pemasukan';
      case TransactionType.expense:
        return 'Pengeluaran';
      case TransactionType.transfer:
        return 'Transfer';
      default:
        return 'Transaksi';
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedFilterType = widget.initialType;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final recProvider = context.read<RecurringProvider>();
      if (recProvider.items.isEmpty && !recProvider.isLoading) {
        recProvider.loadRecurring();
      } else {
        recProvider.loadRecurring(silent: true);
      }
      final dompetProvider = context.read<DompetProvider>();
      if (dompetProvider.items.isEmpty && !dompetProvider.isLoading) {
        dompetProvider.loadDompets(silent: true);
      }
    });
  }

  Future<void> _confirmDelete(RecurringModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: scaffoldBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Hapus Jadwal Berulang?',
          style: TextStyle(
            color: primaryGreen,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Jadwal "${item.title}" akan dihapus dan tidak akan membuat transaksi otomatis lagi. Transaksi yang sudah tercatat di Riwayat tetap aman.',
          style: const TextStyle(
            color: primaryGreen,
            fontSize: 13,
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: primaryGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Hapus',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<RecurringProvider>().deleteRecurring(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Jadwal berulang berhasil dihapus'),
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
    }
  }

  Future<void> _toggleActive(RecurringModel item) async {
    try {
      await context
          .read<RecurringProvider>()
          .toggleActive(item.id, !item.isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !item.isActive
                  ? '✅ Jadwal "${item.title}" diaktifkan kembali'
                  : '⏸️ Jadwal "${item.title}" dijeda sementara',
            ),
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
    }
  }

  String _resolveWalletRouteLabel(
    RecurringModel item,
    List<DompetItem> dompets,
  ) {
    final srcMatches = dompets.where((d) => d.id == item.dompetId);
    final srcName = srcMatches.isNotEmpty ? srcMatches.first.nama : 'Dompet';

    if (item.type == TransactionType.transfer) {
      if (item.isInternalTransfer) {
        final dstMatches =
            dompets.where((d) => d.id == item.destinationDompetId);
        final dstName =
            dstMatches.isNotEmpty ? dstMatches.first.nama : 'Dompet Tujuan';
        return '$srcName → $dstName';
      }
      final target = (item.counterpartyName != null &&
              item.counterpartyName!.trim().isNotEmpty)
          ? item.counterpartyName!.trim()
          : 'Penerima';
      return '$srcName → $target';
    }
    return srcName;
  }

  @override
  Widget build(BuildContext context) {
    final recProvider = context.watch<RecurringProvider>();
    final dompetProvider = context.watch<DompetProvider>();
    final catProvider = Provider.of<CategoryProvider?>(context);
    final dompets = dompetProvider.items;

    final effectiveFilterType =
        _isLockedToType ? widget.initialType : _selectedFilterType;

    final activeItems = effectiveFilterType == null
        ? recProvider.activeItems
        : recProvider.activeItems
            .where((item) => item.type == effectiveFilterType)
            .toList();
    final inactiveItems = effectiveFilterType == null
        ? recProvider.inactiveItems
        : recProvider.inactiveItems
            .where((item) => item.type == effectiveFilterType)
            .toList();
    final bool hasFilteredItems =
        activeItems.isNotEmpty || inactiveItems.isNotEmpty;

    final String appBarTitle = _isLockedToType
        ? 'Jadwal ${_typeLabel(widget.initialType!)} Berulang'
        : 'Transaksi Berulang';

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: CustomAppBar(
        title: appBarTitle,
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
                if (!_isLockedToType)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                    child: Row(
                      children: _riwayatTabs.map((tabType) {
                        final label = tabType == null
                            ? 'Semua'
                            : _typeLabel(tabType);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: CustomFilterChip(
                            label: label,
                            selected: _selectedFilterType == tabType,
                            onTap: () => setState(
                              () => _selectedFilterType = tabType,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                Expanded(
                  child: recProvider.isLoading && recProvider.items.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(color: primaryGreen),
                        )
                      : RefreshIndicator(
                          color: primaryGreen,
                          backgroundColor: scaffoldBg,
                          onRefresh: () => recProvider.loadRecurring(),
                          child: !hasFilteredItems
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(24),
                                  children: [
                                    const SizedBox(height: 60),
                                    Icon(
                                      Icons.event_repeat_rounded,
                                      size: 56,
                                      color:
                                          primaryGreen.withValues(alpha: 0.45),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      effectiveFilterType != null
                                          ? 'Belum ada jadwal ${_typeLabel(effectiveFilterType).toLowerCase()} berulang'
                                          : 'Belum ada jadwal transaksi berulang',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: primaryGreen,
                                        fontSize: 15,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _isLockedToType
                                          ? 'Ketuk tombol di bawah untuk membuat jadwal ${_typeLabel(widget.initialType!).toLowerCase()} berulang otomatis.'
                                          : 'Buat jadwal berulang baru melalui ikon jadwal di pojok kanan atas halaman Pemasukan, Pengeluaran, atau Transfer.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color:
                                            primaryGreen.withValues(alpha: 0.7),
                                        fontSize: 12.5,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                )
                              : ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding:
                                      const EdgeInsets.fromLTRB(24, 16, 24, 24),
                                  children: [
                                    if (activeItems.isNotEmpty) ...[
                                      Text(
                                        'Jadwal Aktif (${activeItems.length})',
                                        style: const TextStyle(
                                          color: primaryGreen,
                                          fontSize: 13.5,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      ...activeItems.map(
                                        (item) => _buildRecurringCard(
                                          item: item,
                                          dompets: dompets,
                                          catProvider: catProvider,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    if (inactiveItems.isNotEmpty) ...[
                                      Text(
                                        'Dijeda / Selesai (${inactiveItems.length})',
                                        style: TextStyle(
                                          color: primaryGreen.withValues(
                                            alpha: 0.75,
                                          ),
                                          fontSize: 13.5,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      ...inactiveItems.map(
                                        (item) => _buildRecurringCard(
                                          item: item,
                                          dompets: dompets,
                                          catProvider: catProvider,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                ),
                if (_isLockedToType)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: PrimaryButton(
                      label:
                          '+ Buat ${_typeLabel(widget.initialType!)} Berulang',
                      onPressed: () => context.push(
                        AppRoutes.buatBerulang,
                        extra: BuatBerulangArgs(initialType: widget.initialType),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringCard({
    required RecurringModel item,
    required List<DompetItem> dompets,
    required CategoryProvider? catProvider,
  }) {
    final cat = catProvider != null
        ? catProvider.resolve(item.categoryId, fallbackType: item.type)
        : CategoryCatalog.getById(item.categoryId, fallbackType: item.type);

    final bool isExpense = item.type == TransactionType.expense ||
        (item.type == TransactionType.transfer && !item.isInternalTransfer);
    final bool isInternalTransfer = item.isInternalTransfer;
    final String prefix = isInternalTransfer ? '' : (isExpense ? '- ' : '+ ');
    final Color amountColor = isInternalTransfer
        ? primaryGreen
        : (isExpense ? const Color(0xFFC62828) : primaryGreen);

    final Color iconBg = cat.color.withValues(alpha: 0.18);
    final Color iconFg = cat.color;

    final walletRoute = _resolveWalletRouteLabel(item, dompets);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CustomCard(
        backgroundColor: item.isActive ? cardBg : cardBg.withValues(alpha: 0.6),
        borderRadius: 16,
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(cat.icon, color: iconFg, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: primaryGreen,
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        walletRoute,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryGreen.withValues(alpha: 0.78),
                          fontSize: 11.5,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: primaryGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              item.scheduleLabel,
                              style: const TextStyle(
                                color: primaryGreen,
                                fontSize: 10.5,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: item.isActive
                                  ? orangeText.withValues(alpha: 0.14)
                                  : Colors.black12,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              item.isActive
                                  ? 'Berikutnya: ${DateHelper.formatShort(item.nextRunDate)}'
                                  : (item.isCompleted ? 'Selesai' : 'Dijeda'),
                              style: TextStyle(
                                color:
                                    item.isActive ? orangeText : primaryGreen,
                                fontSize: 10.5,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6, top: 2),
                      child: Text(
                        prefix + Formatters.rupiah(item.amount),
                        style: TextStyle(
                          color: amountColor,
                          fontSize: 13.5,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: primaryGreen,
                        size: 20,
                      ),
                      onSelected: (val) {
                        if (val == 'toggle') {
                          _toggleActive(item);
                        } else if (val == 'edit') {
                          context.push(
                            AppRoutes.buatBerulang,
                            extra: BuatBerulangArgs(itemToEdit: item),
                          );
                        } else if (val == 'delete') {
                          _confirmDelete(item);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Row(
                            children: [
                              Icon(
                                item.isActive
                                    ? Icons.pause_circle_outline_rounded
                                    : Icons.play_circle_outline_rounded,
                                color: primaryGreen,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.isActive ? 'Jeda Jadwal' : 'Aktifkan',
                                style: const TextStyle(color: primaryGreen),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, color: primaryGreen),
                              SizedBox(width: 8),
                              Text(
                                'Edit',
                                style: TextStyle(color: primaryGreen),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Hapus',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            if (item.lastSkipReason != null &&
                item.lastSkipReason!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 15,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.skippedCount > 0
                            ? 'Dilewati (${item.skippedCount}x) — ${item.lastSkipReason!}'
                            : 'Dilewati — ${item.lastSkipReason!}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
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
    );
  }
}
