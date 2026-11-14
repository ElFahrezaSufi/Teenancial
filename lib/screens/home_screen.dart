import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../models/target_model.dart';
import '../providers/belajar_provider.dart';
import '../providers/category_provider.dart';
import '../providers/dompet_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/target_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';

import '../widgets/home/action_menu.dart';
import '../widgets/home/belajar_card.dart';
import '../widgets/home/pinjaman_home.dart';
import '../widgets/home/profile_header.dart';
import '../widgets/home/section_header.dart';
import '../widgets/home/target_menabung_home.dart';
import '../widgets/home/total_saldo_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Visual XP & Level di-hold (tetap dipertahankan secara UI di Beranda)
  int currentXP = 0;
  int maxXP = 1000;
  int level = 1;

  double _feenX = 0;
  double _feenY = 0;
  bool _isFeenInitialized = false;
  bool _isDraggingFeen = false;

  static const double _feenButtonWidth = 84.0;
  static const double _feenBottomMargin = 220.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isFeenInitialized) {
      final size = MediaQuery.sizeOf(context);
      _feenX = (size.width - _feenButtonWidth).clamp(0.0, double.infinity);
      _feenY = (size.height - _feenBottomMargin).clamp(0.0, double.infinity);
      _isFeenInitialized = true;
    }
  }

  void _tambahTabunganMock() {
    setState(() {
      currentXP += 50;
      if (currentXP >= maxXP) {
        level++;
        currentXP = currentXP - maxXP;
        maxXP = (maxXP * 1.5).toInt();
      }
    });
  }

  Future<void> _handleRefresh() async {
    final belajarProvider = context.read<BelajarProvider>();
    final catProvider = Provider.of<CategoryProvider?>(context, listen: false);
    final recProvider = Provider.of<RecurringProvider?>(context, listen: false);
    await Future.wait([
      context.read<UserProvider>().loadProfile(silent: true),
      context.read<DompetProvider>().loadDompets(silent: true),
      context.read<TransactionProvider>().loadTransactions(silent: true),
      context.read<TargetProvider>().loadTargets(silent: true),
      if (catProvider != null) catProvider.loadCategories(silent: true),
      if (recProvider != null) recProvider.loadRecurring(silent: true),
      belajarProvider.levels.isEmpty
          ? belajarProvider.loadAll(silent: true)
          : belajarProvider.loadProgress(silent: true),
    ]);
  }

  Future<void> _tambahTargetData() async {
    await context.push(AppRoutes.buatTarget);
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final dompetProvider = context.watch<DompetProvider>();
    final targetProvider = context.watch<TargetProvider>();

    final screenSize = MediaQuery.sizeOf(context);
    final double maxFeenX =
        (screenSize.width - _feenButtonWidth).clamp(0.0, double.infinity);
    final double maxFeenY =
        (screenSize.height - _feenBottomMargin).clamp(0.0, double.infinity);
    final double clampedFeenX = _feenX.clamp(0.0, maxFeenX);
    final double clampedFeenY = _feenY.clamp(0.0, maxFeenY);

    final double topPadding = MediaQuery.paddingOf(context).top;
    final double xpProgress =
        maxXP > 0 ? (currentXP / maxXP).clamp(0.0, 1.0) : 0.0;
    final double totalSaldoReal = dompetProvider.totalSaldo;
    final double perkiraanMingguanReal =
        totalSaldoReal + (totalSaldoReal * 0.02);

    final TargetItem? currentTarget = targetProvider.pinnedItem;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: primaryGreen,
              backgroundColor: scaffoldBg,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                child: Stack(
                  children: [
                    Image.asset(
                      'assets/images/stenga_lingkaran.png',
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: topPadding + 20),
                          ProfileHeader(
                            displayName: userProvider.displayName,
                            level: level,
                            imageUrl: userProvider.profileImageUrl,
                            onProfileTap: () => context.go(AppRoutes.profile),
                          ),
                          const SizedBox(height: 16),

                          // Total Saldo Card
                          TotalSaldoCard(
                            totalSaldoReal: totalSaldoReal,
                            perkiraanMingguanReal: perkiraanMingguanReal,
                            xpProgress: xpProgress,
                            currentXP: currentXP,
                            maxXP: maxXP,
                            level: level,
                            formatRupiah: Formatters.rupiah,
                            onTap: _tambahTabunganMock,
                          ),
                          const SizedBox(height: 32),

                          // Menu Action
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ActionMenu(
                                assetPath: 'assets/images/pemasukan.svg',
                                label: 'Pemasukan',
                                onTap: () => context.push(AppRoutes.pemasukan),
                              ),
                              ActionMenu(
                                assetPath: 'assets/images/pengeluaran.svg',
                                label: 'Pengeluaran',
                                onTap: () =>
                                    context.push(AppRoutes.pengeluaran),
                              ),
                              ActionMenu(
                                assetPath: 'assets/images/pinjaman.svg',
                                label: 'Pinjaman',
                                onTap: () => context.push(AppRoutes.pinjaman),
                              ),
                              ActionMenu(
                                assetPath: 'assets/images/transfer.png',
                                label: 'Transfer',
                                iconPadding: const EdgeInsets.only(left: 4.0),
                                onTap: () => context.push(AppRoutes.transfer),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Target Menabung
                          SectionHeader(
                            title: 'Target Menabung',
                            actionText: 'Lihat Semua',
                            onActionTap: () =>
                                context.push(AppRoutes.targetMenabung),
                          ),
                          const SizedBox(height: 12),

                          TargetMenabungHome(
                            currentTarget: currentTarget,
                            totalSaldoReal: totalSaldoReal,
                            formatRupiah: Formatters.rupiah,
                            onTambahTarget: _tambahTargetData,
                          ),
                          const SizedBox(height: 24),

                          // Daftar Pinjaman
                          SectionHeader(
                            title: 'Daftar Pinjaman',
                            actionText: 'Lihat Semua',
                            onActionTap: () =>
                                context.push(AppRoutes.daftarPinjaman),
                          ),
                          const SizedBox(height: 12),
                          PinjamanHome(
                            formatRupiah: Formatters.rupiah,
                            onTap: () => context.push(AppRoutes.daftarPinjaman),
                          ),
                          const SizedBox(height: 24),

                          // Ruang Belajar
                          SectionHeader(
                            title: 'Ruang Belajar',
                            actionText: 'Lihat Semua',
                            onActionTap: () =>
                                context.push(AppRoutes.ruangBelajar),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.ruangBelajar),
                            child: const BelajarCard(),
                          ),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Floating button Tanya Feen
          AnimatedPositioned(
            duration: _isDraggingFeen
                ? Duration.zero
                : const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            left: clampedFeenX,
            top: clampedFeenY,
            child: GestureDetector(
              onPanStart: (details) {
                setState(() => _isDraggingFeen = true);
              },
              onPanUpdate: (details) {
                final size = MediaQuery.sizeOf(context);
                setState(() {
                  _feenX = (_feenX + details.delta.dx)
                      .clamp(0.0, (size.width - 80).clamp(0.0, double.infinity));
                  _feenY = (_feenY + details.delta.dy).clamp(
                    0.0,
                    (size.height - _feenBottomMargin)
                        .clamp(0.0, double.infinity),
                  );
                });
              },
              onPanEnd: (details) {
                final screenWidth = MediaQuery.sizeOf(context).width;
                setState(() {
                  _isDraggingFeen = false;
                  final centerScreen = screenWidth / 2;

                  if (_feenX + 30 < centerScreen) {
                    _feenX = 24.0;
                  } else {
                    _feenX = (screenWidth - _feenButtonWidth)
                        .clamp(0.0, double.infinity);
                  }
                });
              },
              onTap: () => context.push(AppRoutes.tanyaFeen),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: feenButtonBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryGreen, width: 2),
                    ),
                    child: const Center(
                      child: Text(
                        '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryGreen, width: 1),
                    ),
                    child: const Text(
                      'Tanya Feen',
                      style: TextStyle(
                        color: primaryGreen,
                        fontSize: 10,
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
    );
  }
}
