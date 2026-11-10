import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../utils/transaction_actions.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/transaction/transaction_group.dart';
import 'riwayat_screen.dart';

class SemuaAktivitasScreen extends StatelessWidget {
  final int filterIndex;

  const SemuaAktivitasScreen({
    super.key,
    this.filterIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final groups = RiwayatScreen.buildFilteredGroups(
      txProvider.transactions,
      filterIndex,
    );

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
                            formatCurrency: Formatters.rupiah,
                            onEdit: (item) =>
                                TransactionActions.edit(context, item),
                            onDelete: (id) =>
                                TransactionActions.delete(context, id),
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
