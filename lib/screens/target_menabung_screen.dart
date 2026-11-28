import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../data/feen_catalog.dart';
import '../models/dompet_model.dart';
import '../models/feen_chat_model.dart';
import '../models/target_model.dart';
import '../models/transaction_model.dart';
import '../providers/category_provider.dart';
import '../providers/dompet_provider.dart';
import '../providers/target_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../utils/confirm_dialog.dart';
import '../utils/currency_formatter.dart';
import '../utils/error_mapper.dart';
import '../utils/loan_helper.dart';
import '../utils/saving_planner.dart';
import '../widgets/common/async_state_view.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/common/loading_overlay.dart';
import '../widgets/common/target_image.dart';
import '../widgets/feen/feen_avatar.dart';

class TargetMenabungScreen extends StatelessWidget {
  const TargetMenabungScreen({super.key});

  Future<void> _navigasiDanTambahData(BuildContext context) async {
    await context.push(AppRoutes.buatTarget);
  }

  @override
  Widget build(BuildContext context) {
    final targetProvider = context.watch<TargetProvider>();
    final userProvider = context.watch<UserProvider>();
    final transactionProvider = context.watch<TransactionProvider>();
    final dompetProvider = context.watch<DompetProvider>();
    final items = targetProvider.items;
    final wallets = dompetProvider.items;
    final saldoSekarang = dompetProvider.totalSaldo;
    final totalAllocated = targetProvider.totalAllocated;
    final availableSaldo = targetProvider.availableToAllocate(saldoSekarang);
    final bool hasAchievedAny = items.any((e) => e.isAchieved && !e.isSettled);

    // Dana yang benar-benar sudah keluar dari dompet (punya transaksi alokasi),
    // sekaligus melacak kontribusi per dompet agar saat diselesaikan dompet
    // sumber yang paling relevan terpilih secara akurat.
    final allocatedByTarget = <String, double>{};
    final walletContribByTarget = <String, Map<String, double>>{};
    for (final tx in transactionProvider.transactions) {
      final targetId = tx.targetId;
      if (targetId == null || targetId.isEmpty) continue;
      if (!tx.isBalanceAdjustment || tx.skipWalletEffect) continue;
      final delta = tx.type == TransactionType.expense ? tx.amount : -tx.amount;
      allocatedByTarget[targetId] = (allocatedByTarget[targetId] ?? 0) + delta;
      if (tx.dompetId.isNotEmpty) {
        final byWallet = walletContribByTarget.putIfAbsent(targetId, () => {});
        byWallet[tx.dompetId] = (byWallet[tx.dompetId] ?? 0) + delta;
      }
    }

    // Dana lama (sebelum fitur pemotongan saldo) belum pernah keluar dari
    // dompet, sehingga tidak boleh ditarik agar tidak mencetak uang baru.
    double legacyOf(TargetItem item) {
      final viaTx = allocatedByTarget[item.id] ?? 0;
      final clampedViaTx = viaTx > 0 ? viaTx : 0.0;
      final legacy = item.savedAmount - clampedViaTx;
      return legacy > 0.0001 ? legacy : 0;
    }

    String preferredWalletIdOf(TargetItem item) {
      final byWallet = walletContribByTarget[item.id];
      if (byWallet != null && byWallet.isNotEmpty) {
        String? bestId;
        double bestAmount = 0;
        for (final entry in byWallet.entries) {
          final exists = wallets.any((w) => w.id == entry.key);
          if (exists && entry.value > bestAmount) {
            bestAmount = entry.value;
            bestId = entry.key;
          }
        }
        if (bestId != null) return bestId;
      }
      return wallets.isNotEmpty ? wallets.first.id : '';
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: const CustomAppBar(title: 'Target Menabung'),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: scaffoldBg,
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                'assets/images/bg_curve.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (targetProvider.isLoading && items.isEmpty)
            const Center(
              child: CircularProgressIndicator(color: primaryGreen),
            )
          else if (targetProvider.errorMessage != null && items.isEmpty)
            SafeArea(
              child: ErrorStateView(
                errorMessage: targetProvider.errorMessage!,
                onRetry: () => context.read<TargetProvider>().loadTargets(),
              ),
            )
          else
            SafeArea(
              child: RefreshIndicator(
                color: primaryGreen,
                backgroundColor: scaffoldBg,
                onRefresh: () =>
                    context.read<TargetProvider>().loadTargets(silent: true),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (items.isEmpty)
                        _buildEmptyState(context, userProvider)
                      else ...[
                        _buildAllocationSummaryCard(
                          userProvider: userProvider,
                          hasAchievedAny: hasAchievedAny,
                          totalAllocated: totalAllocated,
                          availableSaldo: availableSaldo,
                        ),
                        const SizedBox(height: 20),
                        ...items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: _buildTargetCard(
                              context,
                              item: item,
                              saldoSekarang: saldoSekarang,
                              legacyAmount: legacyOf(item),
                              preferredWalletId: preferredWalletIdOf(item),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: items.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _navigasiDanTambahData(context),
              backgroundColor: primaryGreen,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            )
          : null,
    );
  }

  Widget _buildAllocationSummaryCard({
    required UserProvider userProvider,
    required bool hasAchievedAny,
    required double totalAllocated,
    required double availableSaldo,
  }) {
    return CustomCard(
      backgroundColor: appBarBg,
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FeenAvatar(
                level: userProvider.level,
                pose: hasAchievedAny ? FeenPose.levelup : FeenPose.saving,
                equipped: userProvider.feenEquipped,
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasAchievedAny
                      ? 'Keren! Ada target impianmu yang sudah tercapai!'
                      : 'Sisihkan sedikit demi sedikit biar target impianmu cepat tercapai!',
                  style: const TextStyle(
                    color: primaryGreen,
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: primaryGreen.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Saldo Dompet',
                      style: TextStyle(
                        color: primaryGreen.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.rupiah(availableSaldo),
                      style: const TextStyle(
                        color: primaryGreen,
                        fontSize: 18,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1.5,
                height: 36,
                color: primaryGreen.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tersimpan di Target',
                      style: TextStyle(
                        color: primaryGreen.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.rupiah(totalAllocated),
                      style: const TextStyle(
                        color: Color(0xFFDAB62C),
                        fontSize: 18,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, UserProvider userProvider) {
    return CustomCard(
      backgroundColor: appBarBg,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FeenAvatar(
            level: userProvider.level,
            pose: FeenPose.saving,
            equipped: userProvider.feenEquipped,
            size: 84,
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada target impian nih!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primaryGreen,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yuk mulai tabung uangmu untuk beli barang impianmu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primaryGreen.withValues(alpha: 0.7),
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _navigasiDanTambahData(context),
            child: const CustomCard(
              borderRadius: 100,
              backgroundColor: primaryGreen,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Buat Target Baru',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetCard(
    BuildContext context, {
    required TargetItem item,
    required double saldoSekarang,
    required double legacyAmount,
    required String preferredWalletId,
  }) {
    final double progress = item.progress;
    final String terkumpulStr = Formatters.rupiah(item.savedAmount);
    final String targetStr = Formatters.rupiah(item.targetAmount);
    final bool hasLegacyFunds = legacyAmount > 0.0001;
    final double withdrawableAmount =
        (item.savedAmount - legacyAmount).clamp(0.0, item.savedAmount);
    final bool canDeposit =
        !item.isAchieved && !item.isSettled && saldoSekarang > 0;
    final bool canWithdraw = withdrawableAmount > 0.0001 && !item.isSettled;
    final SavingPlan? plan = SavingPlanner.plan(item);
    final Color planBadgeColor = plan == null
        ? primaryGreen
        : (plan.isOverdue
            ? LoanHelper.overdueColor
            : (plan.isUrgent ? orangeText : primaryGreen));

    return CustomCard(
      backgroundColor: cardBg,
      borderRadius: 20,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
                child: TargetImage(imageUrl: item.imageUrl, height: 160),
              ),
              if (item.isAchieved)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      item.isSettled ? 'Selesai ✓' : 'Tercapai 🎉',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: appBarBg.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.more_vert,
                      color: primaryGreen,
                      size: 20,
                    ),
                    color: appBarBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        if (item.isSettled) return;
                        await context.push(AppRoutes.buatTarget, extra: item);
                      } else if (value == 'delete') {
                        if (!item.isSettled && withdrawableAmount > 0.0001) {
                          final withdrawNow = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: appBarBg,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              title: const Text(
                                'Target Masih Menyimpan Dana',
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                              content: Text(
                                'Target "${item.nama}" masih menyimpan '
                                '${Formatters.rupiah(withdrawableAmount)} yang '
                                'berasal dari dompetmu.\n\n'
                                'Tarik seluruh dana kembali ke dompet terlebih '
                                'dahulu sebelum menghapus target agar saldomu '
                                'tidak hilang.',
                                style: const TextStyle(
                                  color: primaryGreen,
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text(
                                    'Tutup',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryGreen,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                  ),
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('Tarik Dana'),
                                ),
                              ],
                            ),
                          );
                          if (withdrawNow == true && context.mounted) {
                            await _showAllocationDialog(
                              context,
                              item: item,
                              isDeposit: false,
                              withdrawableAmount: withdrawableAmount,
                            );
                          }
                          return;
                        }

                        final String deleteMessage =
                            (!item.isSettled && hasLegacyFunds)
                                ? 'Target ini hanya memiliki dana catatan lama '
                                    '(${Formatters.rupiah(legacyAmount)}) yang '
                                    'tidak pernah memotong dompet. Yakin ingin '
                                    'menghapus target ini?'
                                : 'Apakah Anda yakin ingin menghapus target ini?';

                        final bool confirm = await showConfirmDialog(
                          context,
                          title: 'Hapus Target',
                          message: deleteMessage,
                        );

                        if (confirm && context.mounted) {
                          final targetProvider = context.read<TargetProvider>();
                          try {
                            await runWithLoadingDialog(
                              context,
                              message: 'Menghapus target...',
                              action: () => targetProvider.deleteTarget(
                                item.id,
                                walletBackedAmount: withdrawableAmount,
                              ),
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Gagal menghapus target: ${ErrorMapper.message(e)}',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      if (!item.isSettled)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, color: primaryGreen),
                              SizedBox(width: 8),
                              Text(
                                'Edit Target',
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
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
                              'Hapus Target',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: (item.isPinned || item.isSettled)
                      ? null
                      : () async {
                          final targetProvider = context.read<TargetProvider>();
                          try {
                            await runWithLoadingDialog(
                              context,
                              message: 'Menyematkan target...',
                              action: () => targetProvider.togglePin(item),
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Gagal mengubah pin target: ${ErrorMapper.message(e)}',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (!item.isSettled && item.isPinned)
                          ? const Color(0xFFDAB62C).withValues(alpha: 0.2)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.isSettled
                          ? Icons.check_circle
                          : (item.isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined),
                      size: 24,
                      color: item.isSettled
                          ? primaryGreen
                          : (item.isPinned
                              ? const Color(0xFFDAB62C)
                              : Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nama,
                        style: const TextStyle(
                          color: primaryGreen,
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$terkumpulStr / $targetStr',
                        style: TextStyle(
                          color: primaryGreen.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: primaryGreen,
                    fontSize: 14,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: lightGreen,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasLegacyFunds && !item.isSettled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: orangeText.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: orangeText.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: orangeText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        withdrawableAmount > 0.0001
                            ? 'Dana lama ${Formatters.rupiah(legacyAmount)} tidak dapat ditarik ke dompet. Maksimal penarikan: ${Formatters.rupiah(withdrawableAmount)}.'
                            : 'Dana lama ${Formatters.rupiah(legacyAmount)} belum tersinkron dengan dompet, jadi penarikan dinonaktifkan.',
                        style: const TextStyle(
                          color: orangeText,
                          fontSize: 11,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (plan != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.event,
                        size: 14,
                        color: planBadgeColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Tenggat ${plan.deadlineLabel}',
                          style: TextStyle(
                            color: planBadgeColor,
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: planBadgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: planBadgeColor, width: 1),
                        ),
                        child: Text(
                          plan.badgeText,
                          style: TextStyle(
                            color: planBadgeColor,
                            fontSize: 11,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (plan.suggestionText != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          plan.isOverdue
                              ? Icons.warning_amber_rounded
                              : Icons.tips_and_updates_outlined,
                          size: 14,
                          color: plan.isOverdue
                              ? LoanHelper.overdueColor
                              : primaryGreen,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            plan.suggestionText!,
                            style: TextStyle(
                              color: plan.isOverdue
                                  ? LoanHelper.overdueColor
                                  : primaryGreen,
                              fontSize: 12,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: item.isSettled
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: primaryGreen, width: 1.5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: primaryGreen,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Target Selesai',
                          style: TextStyle(
                            color: primaryGreen,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                : item.isAchieved
                    ? Row(
                        children: [
                          if (canWithdraw) ...[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showAllocationDialog(
                                  context,
                                  item: item,
                                  isDeposit: false,
                                  withdrawableAmount: withdrawableAmount,
                                ),
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Tarik',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primaryGreen,
                                  side: const BorderSide(
                                    color: primaryGreen,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _confirmSettle(
                                context,
                                item,
                                preferredWalletId: preferredWalletId,
                              ),
                              icon: const Icon(Icons.flag_outlined, size: 18),
                              label: const Text(
                                'Selesaikan',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: canWithdraw
                                      ? () => _showAllocationDialog(
                                            context,
                                            item: item,
                                            isDeposit: false,
                                            withdrawableAmount:
                                                withdrawableAmount,
                                          )
                                      : null,
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Tarik',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: primaryGreen,
                                    side: BorderSide(
                                      color: canWithdraw
                                          ? primaryGreen
                                          : Colors.grey.withValues(alpha: 0.4),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: canDeposit
                                      ? () => _showAllocationDialog(
                                            context,
                                            item: item,
                                            isDeposit: true,
                                            withdrawableAmount:
                                                withdrawableAmount,
                                          )
                                      : null,
                                  icon: const Icon(
                                    Icons.savings_outlined,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Tabung',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryGreen,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        Colors.grey.withValues(alpha: 0.3),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            borderRadius: BorderRadius.circular(100),
                            onTap: () {
                              final deadlineNote = plan != null
                                  ? ' dengan tenggat ${plan.deadlineLabel} (${plan.badgeText})'
                                  : '';
                              context.push(
                                AppRoutes.tanyaFeen,
                                extra: TanyaFeenArgs(
                                  initialPrompt:
                                      'Bantu buatkan strategi nabung buat target "${item.nama}" (terkumpul $terkumpulStr dari $targetStr, sisa ${Formatters.rupiah(item.remainingAmount)}$deadlineNote) dong!',
                                  startNewSession: true,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: inputBg,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: primaryGreen.withValues(alpha: 0.45),
                                  width: 1,
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 15,
                                    color: primaryGreen,
                                  ),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Minta Strategi Feen',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: primaryGreen,
                                        fontSize: 12,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
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

  Future<void> _showAllocationDialog(
    BuildContext context, {
    required TargetItem item,
    required bool isDeposit,
    required double withdrawableAmount,
  }) async {
    final dompetProvider = context.read<DompetProvider>();
    final targetProvider = context.read<TargetProvider>();
    final txProvider = context.read<TransactionProvider>();
    final wallets = dompetProvider.items;
    if (wallets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada dompet. Tambahkan dompet terlebih dahulu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final double remainingTarget =
        (item.targetAmount - item.savedAmount).clamp(0.0, double.infinity);

    final result = await showDialog<({double amount, DompetItem wallet})>(
      context: context,
      builder: (_) => _TargetAllocationDialog(
        targetName: item.nama,
        isDeposit: isDeposit,
        maxAmount: isDeposit ? remainingTarget : withdrawableAmount,
        wallets: wallets,
      ),
    );

    if (result == null || !context.mounted) return;

    final double delta = isDeposit ? result.amount : -result.amount;

    try {
      await runWithLoadingDialog(
        context,
        message: isDeposit ? 'Menyimpan tabungan...' : 'Menarik dana target...',
        action: () async {
          await targetProvider.allocateTargetFunds(
            targetId: item.id,
            amountDelta: delta,
            walletId: result.wallet.id,
            maxWithdrawable: isDeposit ? null : withdrawableAmount,
          );
          await Future.wait([
            dompetProvider.loadDompets(silent: true),
            txProvider.loadTransactions(silent: true),
          ]);
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDeposit
                  ? '✅ ${Formatters.rupiah(result.amount)} dialokasikan ke ${item.nama} dari ${result.wallet.nama}'
                  : '✅ ${Formatters.rupiah(result.amount)} ditarik dari ${item.nama} ke ${result.wallet.nama}',
            ),
            backgroundColor: primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${ErrorMapper.message(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmSettle(
    BuildContext context,
    TargetItem item, {
    required String preferredWalletId,
  }) async {
    final double amount = item.savedAmount;
    if (amount <= 0) return;

    final targetProvider = context.read<TargetProvider>();
    final txProvider = context.read<TransactionProvider>();
    final expenseCategories =
        context.read<CategoryProvider>().categoriesFor(TransactionType.expense);
    final wallets = context.read<DompetProvider>().items;
    final String walletId = preferredWalletId.isNotEmpty
        ? preferredWalletId
        : (wallets.isNotEmpty ? wallets.first.id : '');

    String selectedCategoryId = expenseCategories.any((c) => c.id == 'c6')
        ? 'c6'
        : (expenseCategories.isNotEmpty ? expenseCategories.first.id : 'c6');

    final String? chosenCategoryId = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: appBarBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Selesaikan Target?',
            style: TextStyle(
              color: primaryGreen,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Dana tabungan ${Formatters.rupiah(amount)} untuk "${item.nama}" '
                  'akan dicatat sebagai pengeluaran di Riwayat & Laporan.\n\n'
                  'Saldo dompet tidak berkurang lagi karena sudah dipotong saat menabung.',
                  style: const TextStyle(
                    color: primaryGreen,
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                if (expenseCategories.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategoryId,
                    isExpanded: true,
                    dropdownColor: appBarBg,
                    decoration: InputDecoration(
                      labelText: 'Kategori Pengeluaran',
                      filled: true,
                      fillColor: inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: primaryGreen, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: primaryGreen, width: 1.5),
                      ),
                    ),
                    items: expenseCategories
                        .map(
                          (cat) => DropdownMenuItem<String>(
                            value: cat.id,
                            child: Row(
                              children: [
                                Icon(cat.icon, size: 18, color: cat.color),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    cat.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: primaryGreen,
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedCategoryId = value);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(null),
              child: const Text(
                'Batal',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(selectedCategoryId),
              child: const Text('Selesaikan'),
            ),
          ],
        ),
      ),
    );

    if (chosenCategoryId == null || !context.mounted) return;

    try {
      await runWithLoadingDialog(
        context,
        message: 'Menyelesaikan target...',
        action: () async {
          await targetProvider.settleTarget(
            item.id,
            walletId: walletId,
            categoryId: chosenCategoryId,
          );
          await txProvider.loadTransactions(silent: true);
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Target "${item.nama}" selesai dan tercatat sebagai pengeluaran!',
            ),
            backgroundColor: primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${ErrorMapper.message(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _TargetAllocationDialog extends StatefulWidget {
  final String targetName;
  final bool isDeposit;
  final double maxAmount;
  final List<DompetItem> wallets;

  const _TargetAllocationDialog({
    required this.targetName,
    required this.isDeposit,
    required this.maxAmount,
    required this.wallets,
  });

  @override
  State<_TargetAllocationDialog> createState() =>
      _TargetAllocationDialogState();
}

class _TargetAllocationDialogState extends State<_TargetAllocationDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;
  String? _selectedWalletId;

  @override
  void initState() {
    super.initState();
    _selectedWalletId = _defaultWalletId();
  }

  String? _defaultWalletId() {
    if (widget.wallets.isEmpty) return null;
    if (widget.isDeposit) {
      for (final wallet in widget.wallets) {
        if (wallet.jumlah > 0) return wallet.id;
      }
    }
    return widget.wallets.first.id;
  }

  DompetItem? get _selectedWallet {
    for (final wallet in widget.wallets) {
      if (wallet.id == _selectedWalletId) return wallet;
    }
    return null;
  }

  /// Batas nominal mengikuti saldo dompet terpilih (saat setor) atau dana
  /// tersimpan (saat tarik).
  double get _maxForWallet {
    if (!widget.isDeposit) return widget.maxAmount;
    final wallet = _selectedWallet;
    if (wallet == null) return 0;
    return wallet.jumlah < widget.maxAmount ? wallet.jumlah : widget.maxAmount;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final wallet = _selectedWallet;
    if (wallet == null) {
      setState(() => _errorText = 'Pilih dompet terlebih dahulu');
      return;
    }

    final raw = _controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = double.tryParse(raw) ?? 0.0;
    if (amount <= 0) {
      setState(() => _errorText = 'Masukkan nominal lebih dari Rp 0');
      return;
    }
    if (amount > _maxForWallet + 0.0001) {
      setState(() {
        if (widget.isDeposit) {
          _errorText = amount > wallet.jumlah + 0.0001
              ? 'Saldo ${wallet.nama} tidak cukup (${Formatters.rupiah(wallet.jumlah)})'
              : 'Melebihi sisa target (${Formatters.rupiah(widget.maxAmount)})';
        } else {
          _errorText =
              'Melebihi dana yang dapat ditarik (${Formatters.rupiah(widget.maxAmount)})';
        }
      });
      return;
    }
    Navigator.of(context).pop((amount: amount, wallet: wallet));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: appBarBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        widget.isDeposit ? 'Tabung ke Target' : 'Tarik Alokasi Target',
        style: const TextStyle(
          color: primaryGreen,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.targetName,
              style: const TextStyle(
                color: primaryGreen,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isDeposit
                  ? 'Maksimal dapat ditabung: ${Formatters.rupiah(widget.maxAmount)}'
                  : 'Dapat ditarik ke dompet: ${Formatters.rupiah(widget.maxAmount)}',
              style: TextStyle(
                color: primaryGreen.withValues(alpha: 0.75),
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedWalletId,
              isExpanded: true,
              dropdownColor: appBarBg,
              decoration: InputDecoration(
                labelText: widget.isDeposit
                    ? 'Ambil saldo dari dompet'
                    : 'Kembalikan ke dompet',
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryGreen, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryGreen, width: 1.5),
                ),
              ),
              items: widget.wallets
                  .map(
                    (wallet) => DropdownMenuItem<String>(
                      value: wallet.id,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              wallet.nama,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: primaryGreen,
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            Formatters.rupiah(wallet.jumlah),
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: primaryGreen.withValues(alpha: 0.75),
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedWalletId = value;
                  _errorText = null;
                });
              },
            ),
            const SizedBox(height: 12),
            Text(
              widget.isDeposit
                  ? 'Maksimal dari dompet ini: ${Formatters.rupiah(_maxForWallet)}'
                  : 'Tersimpan di target ini: ${Formatters.rupiah(widget.maxAmount)}',
              style: TextStyle(
                color: primaryGreen.withValues(alpha: 0.75),
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              autofocus: true,
              style: const TextStyle(
                color: primaryGreen,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Rp 0',
                errorText: _errorText,
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryGreen, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryGreen, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryGreen, width: 2),
                ),
              ),
            ),
            if (_maxForWallet > 0) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    _controller.text = CurrencyInputFormatter.formatValue(
                      _maxForWallet.toStringAsFixed(0),
                    );
                    setState(() => _errorText = null);
                  },
                  child: Text(
                    widget.isDeposit ? 'Isi Maksimal' : 'Tarik Semua',
                    style: const TextStyle(
                      color: primaryGreen,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
          child: const Text(
            'Batal',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          onPressed: _submit,
          child: Text(widget.isDeposit ? 'Tabung' : 'Tarik'),
        ),
      ],
    );
  }
}
