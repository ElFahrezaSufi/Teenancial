import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../models/dompet_model.dart';
import '../providers/dompet_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
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

  Widget _buildError(BuildContext context, String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Oops, terjadi kesalahan!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () => context.read<DompetProvider>().loadDompets(),
              child: const Text(
                'Coba Lagi',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 80,
              color: primaryGreen.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Dompet masih kosong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Yuk tambahkan dompet pertamamu sekarang!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () => _openTambahDompet(context),
              child: const Text(
                'Tambah Dompet',
                style: TextStyle(color: Colors.white),
              ),
            ),
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            color: appBarBg,
            border: Border(
              bottom: BorderSide(color: primaryGreen, width: 1.5),
            ),
          ),
          child: const SafeArea(
            child: Center(
              child: Text(
                'Dompet',
                style: TextStyle(
                  color: primaryGreen,
                  fontSize: 25,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
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
          if (dompetProvider.isLoading && dompets.isEmpty)
            _buildLoading()
          else if (dompetProvider.errorMessage != null && dompets.isEmpty)
            _buildError(context, dompetProvider.errorMessage!)
          else if (dompets.isEmpty)
            _buildEmpty(context)
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
