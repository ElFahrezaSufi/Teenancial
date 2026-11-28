import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/common/loading_overlay.dart';
import 'confirm_dialog.dart';
import 'currency_formatter.dart';
import 'error_mapper.dart';
import 'loan_helper.dart';

/// Helper terpusat untuk aksi Edit dan Hapus transaksi di layar Riwayat
/// maupun Semua Aktivitas agar tidak ada duplikasi logika.
class TransactionActions {
  TransactionActions._();

  @visibleForTesting
  static ({String title, String message}) buildDeleteConfirmation(
    TransactionModel? item,
  ) {
    if (item != null && LoanHelper.isLoan(item)) {
      final bool hasPayments = item.payments.isNotEmpty || item.isPaid;
      return (
        title: 'Hapus Pinjaman?',
        message: hasPayments
            ? 'Menghapus catatan "${item.title}" sebesar ${Formatters.rupiah(item.amount)} juga akan membalik perubahan saldo pokok beserta seluruh cicilannya pada dompet terkait.'
            : 'Menghapus catatan "${item.title}" sebesar ${Formatters.rupiah(item.amount)} juga akan mengembalikan perubahan saldonya pada dompet terkait.',
      );
    }

    if (item != null && item.isBalanceAdjustment && !item.isInitialBalance) {
      return (
        title: 'Hapus Penyesuaian Saldo?',
        message:
            'Menghapus "${item.title}" sebesar ${Formatters.rupiah(item.amount)} akan mengembalikan saldo dompet ke nominal sebelum penyesuaian ini. Aksi tidak dapat dibatalkan.',
      );
    }

    return (
      title: 'Hapus Transaksi',
      message:
          'Apakah Anda yakin ingin menghapus data ini? Aksi ini tidak dapat dibatalkan.',
    );
  }

  static Future<void> edit(BuildContext context, TransactionModel item) async {
    if (!item.isEditable) return;

    late final String route;
    switch (item.type) {
      case TransactionType.income:
        route = AppRoutes.pemasukan;
        break;
      case TransactionType.expense:
        route = AppRoutes.pengeluaran;
        break;
      case TransactionType.transfer:
        route = AppRoutes.transfer;
        break;
      case TransactionType.debt:
      case TransactionType.receivable:
        route = AppRoutes.pinjaman;
        break;
    }

    await context.push(route, extra: item);
  }

  static Future<void> delete(BuildContext context, String id) async {
    final txProvider = context.read<TransactionProvider>();
    TransactionModel? targetTx;
    for (final tx in txProvider.transactions) {
      if (tx.id == id) {
        targetTx = tx;
        break;
      }
    }

    if (targetTx != null && !targetTx.isDeletableFromHistory) return;

    final dialogCopy = buildDeleteConfirmation(targetTx);
    final bool confirm = await showConfirmDialog(
      context,
      title: dialogCopy.title,
      message: dialogCopy.message,
      confirmColor:
          (targetTx != null && LoanHelper.isLoan(targetTx))
              ? Colors.redAccent
              : Colors.red,
    );

    if (!confirm || !context.mounted) return;

    try {
      await runWithLoadingDialog(
        context,
        message: 'Menghapus transaksi...',
        action: () => txProvider.deleteTransaction(id),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data berhasil dihapus!'),
            backgroundColor: primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Gagal menghapus: ${ErrorMapper.message(e)}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
