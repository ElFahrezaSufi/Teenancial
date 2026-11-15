import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_colors.dart';
import 'confirm_dialog.dart';
import 'error_mapper.dart';

/// Helper terpusat untuk aksi Edit dan Hapus transaksi di layar Riwayat
/// maupun Semua Aktivitas agar tidak ada duplikasi logika.
class TransactionActions {
  TransactionActions._();

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
    final bool confirm = await showConfirmDialog(
      context,
      title: 'Hapus Transaksi',
      message:
          'Apakah Anda yakin ingin menghapus data ini? Aksi ini tidak dapat dibatalkan.',
    );

    if (!confirm || !context.mounted) return;

    try {
      await context.read<TransactionProvider>().deleteTransaction(id);
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
