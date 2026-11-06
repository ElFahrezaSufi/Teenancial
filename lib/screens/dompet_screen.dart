import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../models/dompet_model.dart';
import '../providers/dompet_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/common/async_state_view.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/common/skeleton.dart';

class DompetScreen extends StatelessWidget {
  const DompetScreen({super.key});

  Future<void> _openTambahDompet(
    BuildContext context, [
    DompetItem? item,
  ]) async {
    await context.push<bool>(AppRoutes.tambahDompet, extra: item);
  }

  Widget _buildLoading() {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 100, height: 16),
            SizedBox(height: 10),
            Skeleton(width: double.infinity, height: 70),
            SizedBox(height: 10),
            Skeleton(width: double.infinity, height: 70),
            SizedBox(height: 24),
            Skeleton(width: 100, height: 16),
            SizedBox(height: 10),
            Skeleton(width: double.infinity, height: 70),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dompetProvider = context.watch<DompetProvider>();
    final dompets = dompetProvider.items;

    const groupedJenis = [
      JenisDompet.cash,
      JenisDompet.accounts,
      JenisDompet.card,
    ];

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: const CustomAppBar(
        title: 'Dompet',
        showBackButton: false,
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
          if (dompetProvider.isLoading && dompets.isEmpty)
            _buildLoading()
          else if (dompetProvider.errorMessage != null && dompets.isEmpty)
            ErrorStateView(
              errorMessage: dompetProvider.errorMessage!,
              onRetry: () => context.read<DompetProvider>().loadDompets(),
            )
          else if (dompets.isEmpty)
            EmptyStateView(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Dompet masih kosong',
              subtitle: 'Yuk tambahkan dompet pertamamu sekarang!',
              actionLabel: 'Tambah Dompet',
              onAction: () => _openTambahDompet(context),
            )
          else
            SafeArea(
              child: RefreshIndicator(
                color: primaryGreen,
                backgroundColor: scaffoldBg,
                onRefresh: () =>
                    context.read<DompetProvider>().loadDompets(silent: true),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...groupedJenis.map((jenis) {
                        final list =
                            dompets.where((e) => e.jenis == jenis).toList();
                        if (list.isEmpty) return const SizedBox.shrink();
                        return _DompetGroup(
                          jenis: jenis,
                          items: list,
                          onItemTap: (item) =>
                              _openTambahDompet(context, item),
                        );
                      }),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => _openTambahDompet(context),
                        child: CustomCard(
                          borderRadius: 100,
                          backgroundColor: primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: const Center(
                            child: Text(
                              '+ Tambah Dompet',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DompetGroup extends StatelessWidget {
  final JenisDompet jenis;
  final List<DompetItem> items;
  final Function(DompetItem) onItemTap;

  const _DompetGroup({
    required this.jenis,
    required this.items,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          jenis.label,
          style: const TextStyle(
            color: primaryGreen,
            fontSize: 14,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => onItemTap(item),
              child: CustomCard(
                backgroundColor: cardBg,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.nama,
                      style: const TextStyle(
                        color: primaryGreen,
                        fontSize: 15,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          Formatters.rupiah(item.jumlah),
                          style: const TextStyle(
                            color: primaryGreen,
                            fontSize: 14,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: primaryGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
