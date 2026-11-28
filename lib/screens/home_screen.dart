import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_constants.dart';
import '../config/app_routes.dart';
import '../data/feen_catalog.dart';
import '../data/mission_catalog.dart';
import '../models/feen_chat_model.dart';
import '../models/mission_model.dart';
import '../models/target_model.dart';
import '../providers/auth_provider.dart';
import '../providers/belajar_provider.dart';
import '../providers/category_provider.dart';
import '../providers/dompet_provider.dart';
import '../providers/mission_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/target_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/user_provider.dart';
import '../routes/app_router.dart';
import '../services/connectivity_service.dart';
import '../services/firestore_service.dart';
import '../services/local_storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../utils/weekly_balance_forecaster.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/common/skeleton.dart';
import '../widgets/feen/feen_fab.dart';
import '../widgets/home/action_menu.dart';
import '../widgets/home/belajar_card.dart';
import '../widgets/home/initial_balance_onboarding_sheet.dart';
import '../widgets/home/pinjaman_home.dart';
import '../widgets/home/profile_header.dart';
import '../widgets/home/section_header.dart';
import '../widgets/home/target_menabung_home.dart';
import '../widgets/home/total_saldo_card.dart';
import '../widgets/home/weekly_forecast_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const double feenButtonWidth = 80.0;
  static const double feenButtonHeight = 92.0;

  /// Menghitung batas area gerak dan posisi default tombol Feen berdasarkan
  /// ukuran viewport aktual `HomeScreen` (sudah otomatis menyesuaikan tinggi
  /// ketika OfflineBanner muncul/hilang serta tinggi bottom navbar + SafeArea).
  @visibleForTesting
  static ({
    double minX,
    double maxX,
    double minY,
    double maxY,
    double defaultX,
    double defaultY,
  }) computeFeenBounds({
    required double viewportWidth,
    required double viewportHeight,
    required double topPadding,
    required double bottomPadding,
  }) {
    const double horizontalEdgeMargin = 16.0;
    const double clearanceAboveNavbar = 16.0;

    final double effectiveBottomClearance =
        bottomPadding + clearanceAboveNavbar;

    final double minX = horizontalEdgeMargin;
    final double maxX = math.max(
      minX,
      viewportWidth - feenButtonWidth - horizontalEdgeMargin,
    );
    final double minY = topPadding + 8.0;
    final double maxY = math.max(
      minY,
      viewportHeight - effectiveBottomClearance - feenButtonHeight,
    );

    return (
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      defaultX: maxX,
      defaultY: maxY,
    );
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _feenX = 0;
  double _feenY = 0;
  bool _hasUserDraggedFeen = false;
  bool _isDraggingFeen = false;
  bool _isSnappingFeen = false;
  String? _onboardingPromptShownForUid;
  bool _isShowingOnboardingSheet = false;

  Future<void> _handleRefresh() async {
    final userProvider = context.read<UserProvider>();
    final dompetProvider = context.read<DompetProvider>();
    final txProvider = context.read<TransactionProvider>();
    final targetProvider = context.read<TargetProvider>();
    final missionProvider = context.read<MissionProvider>();
    final belajarProvider = context.read<BelajarProvider>();
    final catProvider = Provider.of<CategoryProvider?>(context, listen: false);
    final recProvider = Provider.of<RecurringProvider?>(context, listen: false);

    await ConnectivityService.instance.refreshStatus();
    if (!mounted) return;

    await Future.wait([
      userProvider
          .syncPendingOnboardingFlagIfNeeded()
          .then((_) => userProvider.loadProfile(silent: true)),
      dompetProvider.loadDompets(silent: true),
      txProvider.loadTransactions(silent: true),
      targetProvider.loadTargets(silent: true),
      missionProvider.loadMissions(),
      if (catProvider != null) catProvider.loadCategories(silent: true),
      if (recProvider != null) recProvider.loadRecurring(silent: true),
      belajarProvider.levels.isEmpty
          ? belajarProvider.loadAll(silent: true)
          : belajarProvider.loadProgress(silent: true),
    ]);
  }

  Future<void> _showInitialBalanceOnboarding(String uid) async {
    if (!mounted) {
      _isShowingOnboardingSheet = false;
      return;
    }

    final userProvider = context.read<UserProvider>();
    final dompetProvider = context.read<DompetProvider>();
    final txProvider = context.read<TransactionProvider>();

    try {
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (_) => InitialBalanceOnboardingSheet(
          displayName: userProvider.displayName,
          userLevel: userProvider.level,
          feenEquipped: userProvider.feenEquipped,
          onSave: (input) async {
            FirestoreService.instance.ensureOnline(
              actionLabel: 'menyimpan saldo awal',
            );
            bool mutatedWallets = false;
            try {
              if (input.cashInitialBalance > 0) {
                await dompetProvider.setInitialWalletBalance(
                  AppConstants.defaultNewWalletId,
                  input.cashInitialBalance,
                );
                mutatedWallets = true;
              }
              if (input.extraWallet != null) {
                await dompetProvider.addDompet(input.extraWallet!);
                mutatedWallets = true;
              }
            } finally {
              if (mutatedWallets) {
                await txProvider.loadTransactions(silent: true);
              }
            }
            await userProvider.markInitialBalanceOnboardingDone(
              allowOfflineLocalFallback: true,
            );
            rootScaffoldMessengerKey.currentState
              ?..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('✅ Saldo awal berhasil diatur!'),
                  backgroundColor: primaryGreen,
                ),
              );
          },
          onSkip: () async {
            await userProvider.markInitialBalanceOnboardingDone(
              allowOfflineLocalFallback: true,
            );
          },
        ),
      );
    } finally {
      _isShowingOnboardingSheet = false;
    }
  }

  Future<void> _tambahTargetData() async {
    await context.push(AppRoutes.buatTarget);
  }

  void _showWeeklyForecastSheet(WeeklyBalanceForecast forecast) {
    final userProvider = context.read<UserProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WeeklyForecastSheet(
        forecast: forecast,
        userLevel: userProvider.level,
        feenEquipped: userProvider.feenEquipped,
        onAskFeen: () {
          context.push(
            AppRoutes.tanyaFeen,
            extra: TanyaFeenArgs(
              initialPrompt:
                  'Perkiraan saldoku minggu depan sekitar ${Formatters.rupiah(forecast.projectedBalance)} dari saldo sekarang ${Formatters.rupiah(forecast.currentBalance)}. Menurutmu gimana dan apa yang perlu kujaga minggu ini?',
              startNewSession: true,
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyMissionBanner(MissionProvider missionProvider) {
    final dailyMissions = MissionCatalog.byPeriod(MissionPeriod.daily);
    final totalDaily = dailyMissions.length;
    final completedDaily = dailyMissions
        .where(
            (m) => missionProvider.statusOf(m) != MissionClaimStatus.inProgress)
        .length;
    final claimableTotal = missionProvider.claimableCount;
    final progressRatio =
        totalDaily > 0 ? (completedDaily / totalDaily).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.misi),
      child: CustomCard(
        backgroundColor: cardBg,
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryGreen, width: 1.5),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: primaryGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Misi Harian',
                        style: TextStyle(
                          color: primaryGreen,
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (claimableTotal > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDAB62C),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: primaryGreen, width: 1),
                          ),
                          child: Text(
                            '$claimableTotal Klaim XP!',
                            style: const TextStyle(
                              color: primaryGreen,
                              fontSize: 10,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: LinearProgressIndicator(
                            value: progressRatio,
                            minHeight: 7,
                            backgroundColor: lightGreen,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              primaryGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$completedDaily/$totalDaily',
                        style: const TextStyle(
                          color: primaryGreen,
                          fontSize: 11,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: primaryGreen,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeUid = context.select<AuthProvider, String?>((a) => a.activeUid);
    final userProvider = context.watch<UserProvider>();
    final dompetProvider = context.watch<DompetProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final targetProvider = context.watch<TargetProvider>();
    final missionProvider = context.watch<MissionProvider>();
    final recurringProvider = Provider.of<RecurringProvider?>(context);

    if (activeUid != null &&
        !_isShowingOnboardingSheet &&
        _onboardingPromptShownForUid != activeUid &&
        !userProvider.isLoading &&
        !dompetProvider.isLoading &&
        !txProvider.isLoading &&
        InitialBalanceOnboardingHelper.shouldShowOnboarding(
          profile: userProvider.profile,
          dompets: dompetProvider.items,
          transactions: txProvider.transactions,
          isLocalDismissed: LocalStorageService.instance
              .isInitialBalanceOnboardingDoneLocal(activeUid),
        )) {
      _onboardingPromptShownForUid = activeUid;
      _isShowingOnboardingSheet = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showInitialBalanceOnboarding(activeUid);
      });
    }

    final int level = userProvider.level;
    final int currentXP = userProvider.xpIntoLevel;
    final int maxXP = userProvider.xpNeededForNext;

    final mediaPadding = MediaQuery.paddingOf(context);
    final double topPadding = mediaPadding.top;
    final double bottomPadding = mediaPadding.bottom;
    final double xpProgress =
        maxXP > 0 ? (currentXP / maxXP).clamp(0.0, 1.0) : 0.0;
    final double totalSaldoReal = dompetProvider.totalSaldo;
    final WeeklyBalanceForecast weeklyForecast =
        WeeklyBalanceForecaster.forecast(
      currentBalance: totalSaldoReal,
      transactions: txProvider.transactions,
      recurringItems: recurringProvider?.activeItems ?? const [],
    );
    final double perkiraanMingguanReal = weeklyForecast.projectedBalance;

    final TargetItem? currentTarget = targetProvider.pinnedItem;
    final bool isProfileInitialLoading =
        userProvider.isLoading && userProvider.profile == null;
    final bool isSaldoInitialLoading =
        dompetProvider.isLoading && dompetProvider.items.isEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final feenBounds = HomeScreen.computeFeenBounds(
            viewportWidth: constraints.maxWidth,
            viewportHeight: constraints.maxHeight,
            topPadding: topPadding,
            bottomPadding: bottomPadding,
          );
          final double currentFeenX = _hasUserDraggedFeen
              ? _feenX.clamp(feenBounds.minX, feenBounds.maxX)
              : feenBounds.defaultX;
          final double currentFeenY = _hasUserDraggedFeen
              ? _feenY.clamp(feenBounds.minY, feenBounds.maxY)
              : feenBounds.defaultY;

          return Stack(
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
                          height: constraints.maxWidth > 500 ? 280 : null,
                          fit: constraints.maxWidth > 500
                              ? BoxFit.fill
                              : BoxFit.fitWidth,
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
                              if (isProfileInitialLoading)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Skeleton(width: 140, height: 18),
                                          SizedBox(height: 8),
                                          Skeleton(width: 90, height: 13),
                                        ],
                                      ),
                                      Skeleton(
                                        width: 50,
                                        height: 50,
                                        radius: 100,
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ProfileHeader(
                                  displayName: userProvider.displayName,
                                  level: level,
                                  imageUrl: userProvider.profileImageUrl,
                                  frameId: userProvider
                                      .feenEquipped[FeenSlot.frame.name],
                                  onProfileTap: () =>
                                      context.go(AppRoutes.profile),
                                ),
                              const SizedBox(height: 16),

                              // Total Saldo Card
                              if (isSaldoInitialLoading)
                                const CustomCard(
                                  backgroundColor: cardBg,
                                  borderRadius: 24,
                                  padding: EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Skeleton(width: 96, height: 14),
                                      SizedBox(height: 10),
                                      Skeleton(width: 190, height: 32),
                                      SizedBox(height: 18),
                                      Skeleton(
                                        width: double.infinity,
                                        height: 8,
                                      ),
                                      SizedBox(height: 10),
                                      Skeleton(width: 150, height: 12),
                                      SizedBox(height: 16),
                                      Skeleton(
                                        width: double.infinity,
                                        height: 36,
                                        radius: 12,
                                      ),
                                    ],
                                  ),
                                )
                              else
                                TotalSaldoCard(
                                  totalSaldoReal: totalSaldoReal,
                                  perkiraanMingguanReal: perkiraanMingguanReal,
                                  xpProgress: xpProgress,
                                  currentXP: currentXP,
                                  maxXP: maxXP,
                                  level: level,
                                  formatRupiah: Formatters.rupiah,
                                  onTap: () =>
                                      _showWeeklyForecastSheet(weeklyForecast),
                                ),
                              const SizedBox(height: 32),

                              // Menu Action
                              LayoutBuilder(
                                builder: (context, menuConstraints) {
                                  final double circleSize =
                                      ((menuConstraints.maxWidth - 24) / 4)
                                          .clamp(54.0, 72.0);
                                  final double iconSize =
                                      (circleSize * 0.5).clamp(27.0, 36.0);
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: ActionMenu(
                                          assetPath:
                                              'assets/images/pemasukan.svg',
                                          label: 'Pemasukan',
                                          circleSize: circleSize,
                                          iconSize: iconSize,
                                          onTap: () => context
                                              .push(AppRoutes.pemasukan),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: ActionMenu(
                                          assetPath:
                                              'assets/images/pengeluaran.svg',
                                          label: 'Pengeluaran',
                                          circleSize: circleSize,
                                          iconSize: iconSize,
                                          onTap: () => context
                                              .push(AppRoutes.pengeluaran),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: ActionMenu(
                                          assetPath:
                                              'assets/images/pinjaman.svg',
                                          label: 'Pinjaman',
                                          circleSize: circleSize,
                                          iconSize: iconSize,
                                          onTap: () =>
                                              context.push(AppRoutes.pinjaman),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: ActionMenu(
                                          assetPath:
                                              'assets/images/transfer.png',
                                          label: 'Transfer',
                                          circleSize: circleSize,
                                          iconSize: iconSize,
                                          iconPadding:
                                              const EdgeInsets.only(left: 4.0),
                                          onTap: () =>
                                              context.push(AppRoutes.transfer),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 24),

                              // Misi Harian Banner
                              _buildDailyMissionBanner(missionProvider),
                              const SizedBox(height: 24),

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
                                onTap: () =>
                                    context.push(AppRoutes.daftarPinjaman),
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
                                onTap: () =>
                                    context.push(AppRoutes.ruangBelajar),
                                child: const BelajarCard(),
                              ),
                              const SizedBox(height: 24),
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
                duration: _isSnappingFeen
                    ? const Duration(milliseconds: 300)
                    : Duration.zero,
                curve: Curves.easeOutBack,
                onEnd: () {
                  if (_isSnappingFeen && mounted) {
                    setState(() => _isSnappingFeen = false);
                  }
                },
                left: currentFeenX,
                top: currentFeenY,
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _isDraggingFeen = true;
                      _isSnappingFeen = false;
                      if (!_hasUserDraggedFeen) {
                        _feenX = currentFeenX;
                        _feenY = currentFeenY;
                        _hasUserDraggedFeen = true;
                      }
                    });
                  },
                  onPanUpdate: (details) {
                    if (!_isDraggingFeen) return;
                    setState(() {
                      _feenX = (_feenX + details.delta.dx)
                          .clamp(feenBounds.minX, feenBounds.maxX);
                      _feenY = (_feenY + details.delta.dy)
                          .clamp(feenBounds.minY, feenBounds.maxY);
                    });
                  },
                  onPanEnd: (details) {
                    final double centerScreen = constraints.maxWidth / 2;
                    final double targetX =
                        (_feenX + (HomeScreen.feenButtonWidth / 2) <
                                centerScreen)
                            ? feenBounds.minX
                            : feenBounds.maxX;
                    final bool willAnimateX = (targetX - _feenX).abs() > 0.5;
                    setState(() {
                      _isDraggingFeen = false;
                      _isSnappingFeen = willAnimateX;
                      _feenX = targetX;
                    });
                  },
                  onTap: () => context.push(AppRoutes.tanyaFeen),
                  child: const FeenFab(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
