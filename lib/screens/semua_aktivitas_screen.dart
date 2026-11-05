import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_colors.dart';
import '../utils/error_mapper.dart';
import '../widgets/transaction/transaction_group.dart';
import 'riwayat_screen.dart';

class SemuaAktivitasScreen extends StatelessWidget {
  final int filterIndex;

  const SemuaAktivitasScreen({
    super.key,
    this.filterIndex = 0,
  });

  Future<void> _deleteTransaction(BuildContext context, String id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Hapus Transaksi',
          style: TextStyle(color: primaryGreen),
        ),
        content: const Text(
          'Apakah Anda yakin ingin menghapus data ini? Aksi ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

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

  Future<void> _editTransaction(
    BuildContext context,
    TransactionModel item,
  ) async {
    if (item.type != TransactionType.income &&
        item.type != TransactionType.expense) {
      return;
    }
    final route = item.type == TransactionType.income
        ? AppRoutes.pemasukan
        : AppRoutes.pengeluaran;
    await context.push(route, extra: item);
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final groups = RiwayatScreen.buildFilteredGroups(
      txProvider.transactions,
      filterIndex,
    );

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            color: appBarBg,
            border: Border(
              bottom: BorderSide(color: primaryGreen, width: 1.5),
            ),
          ),
          child: SafeArea(
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Center(
                  child: Text(
                    'Semua Aktivitas',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 25,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: primaryGreen,
                      size: 20,
                    ),
                    onPressed: () => context.pop(true),
                  ),
                ),
              ],
            ),
          ),
        ),
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
            child: groups.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada aktivitas pada periode ini.',
                      style: TextStyle(
                        color: primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...groups.map(
                          (group) => TransactionGroupList(
                            group: group,
                            formatCurrency: RiwayatScreen.formatCurrency,
                            onEdit: (item) => _editTransaction(context, item),
                            onDelete: (id) => _deleteTransaction(context, id),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
