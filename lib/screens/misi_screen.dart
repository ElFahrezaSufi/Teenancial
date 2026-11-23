import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/feen_catalog.dart';
import '../data/mission_catalog.dart';
import '../models/mission_model.dart';
import '../providers/mission_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../utils/error_mapper.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/feen/feen_avatar.dart';
import '../widgets/feen/feen_unlock_dialog.dart';
import '../widgets/feen/level_roadmap_sheet.dart';

class MisiScreen extends StatefulWidget {
  const MisiScreen({super.key});

  @override
  State<MisiScreen> createState() => _MisiScreenState();
}

class _MisiScreenState extends State<MisiScreen> {
  static const List<MissionPeriod> _visiblePeriods = [
    MissionPeriod.daily,
    MissionPeriod.weekly,
    MissionPeriod.monthly,
    MissionPeriod.oneTime,
  ];

  MissionPeriod _selectedPeriod = MissionPeriod.daily;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  String _resetCountdownText(
    MissionPeriod period,
    MissionProvider missionProvider,
  ) {
    final resetAt = missionProvider.nextResetAt(period);
    if (resetAt == null) {
      return 'Misi sekali selesai';
    }

    final now = DateTime.now();
    final diff = resetAt.difference(now);
    if (diff.isNegative) {
      return 'Mereset siklus...';
    }

    if (diff.inDays >= 1) {
      final hours = diff.inHours % 24;
      return 'Reset dalam ${diff.inDays} hari $hours jam';
    }
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    return 'Reset dalam $hours jam $minutes menit';
  }

  String _headerSubtitleText(MissionProvider missionProvider) {
    final bonus = missionProvider.streakBonusPercent;
    if (bonus > 0) {
      return 'Bonus streak +$bonus% XP aktif untuk setiap klaim!';
    }
    if (missionProvider.claimableCount > 0) {
      return 'Ada ${missionProvider.claimableCount} hadiah XP siap diklaim!';
    }
    return 'Selesaikan misi harian tiap hari untuk bangun streak.';
  }

  Future<void> _handleClaim(MissionItem mission) async {
    final userProvider = context.read<UserProvider>();
    final oldLevel = userProvider.level;

    try {
      final gainedXp =
          await context.read<MissionProvider>().claimMission(mission);
      if (gainedXp <= 0 || !mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 +$gainedXp XP berhasil diklaim!'),
          backgroundColor: primaryGreen,
        ),
      );

      final newLevel = userProvider.level;
      if (newLevel > oldLevel) {
        final unlocked = feenUnlockedBetween(oldLevel, newLevel);
        if (unlocked.isNotEmpty) {
          await showFeenUnlockDialog(
            context,
            level: newLevel,
            unlocked: unlocked,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                ErrorMapper.message(
                  e,
                  fallback: 'Gagal mengklaim XP, coba lagi.',
                ),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
      }
    }
  }

  Future<void> _handleClaimAll() async {
    final userProvider = context.read<UserProvider>();
    final oldLevel = userProvider.level;

    try {
      final totalXp = await context.read<MissionProvider>().claimAllMissions();
      if (totalXp <= 0 || !mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Semua misi diklaim! +$totalXp XP didapatkan!'),
          backgroundColor: primaryGreen,
        ),
      );

      final newLevel = userProvider.level;
      if (newLevel > oldLevel) {
        final unlocked = feenUnlockedBetween(oldLevel, newLevel);
        if (unlocked.isNotEmpty) {
          await showFeenUnlockDialog(
            context,
            level: newLevel,
            unlocked: unlocked,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                ErrorMapper.message(
                  e,
                  fallback: 'Gagal mengklaim semua XP, coba lagi.',
                ),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final missionProvider = context.watch<MissionProvider>();
    final missions = MissionCatalog.byPeriod(_selectedPeriod);

    final int currentXp = user.xpIntoLevel;
    final int nextLevelXp = user.xpNeededForNext;
    final double xpProgress =
        nextLevelXp > 0 ? (currentXp / nextLevelXp).clamp(0.0, 1.0) : 0.0;
    final int streakCount = missionProvider.streakCount;
    final int? brokenStreak = missionProvider.brokenStreakCount;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: const CustomAppBar(title: 'Misi & XP'),
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    children: [
                      if (brokenStreak != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1EC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFE07A5F),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFFD9534F),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Streak $brokenStreak harimu terputus. Selesaikan 1 misi harian hari ini untuk mulai membangun lagi.',
                                  style: const TextStyle(
                                    color: darkGreen,
                                    fontSize: 11.5,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap:
                                    missionProvider.dismissBrokenStreakNotice,
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: darkGreen,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => showLevelRoadmapSheet(context),
                        child: CustomCard(
                          backgroundColor: cardBg,
                          borderRadius: 20,
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              FeenAvatar(
                                level: user.level,
                                pose: missionProvider.claimableCount > 0
                                    ? FeenPose.levelup
                                    : FeenPose.normal,
                                equipped: user.feenEquipped,
                                size: 60,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Level ${user.level}',
                                                    maxLines: 1,
                                                    style: const TextStyle(
                                                      color: primaryGreen,
                                                      fontSize: 16,
                                                      fontFamily: 'Inter',
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 7,
                                                      vertical: 3,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: missionProvider
                                                              .isStreakActiveToday
                                                          ? const Color(
                                                              0xFFFFF1D6,
                                                            )
                                                          : inputBg,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        100,
                                                      ),
                                                      border: Border.all(
                                                        color: missionProvider
                                                                .isStreakActiveToday
                                                            ? const Color(
                                                                0xFFE5A93B,
                                                              )
                                                            : primaryGreen
                                                                .withValues(
                                                                alpha: 0.4,
                                                              ),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        _AnimatedStreakFlame(
                                                          isActive: missionProvider
                                                              .isStreakActiveToday,
                                                        ),
                                                        const SizedBox(
                                                            width: 3),
                                                        Text(
                                                          '$streakCount Hari',
                                                          maxLines: 1,
                                                          style:
                                                              const TextStyle(
                                                            color: darkGreen,
                                                            fontSize: 10,
                                                            fontFamily: 'Inter',
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '$currentXp / $nextLevelXp XP',
                                              maxLines: 1,
                                              style: const TextStyle(
                                                color: primaryGreen,
                                                fontSize: 11,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              size: 16,
                                              color: primaryGreen,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(100),
                                      child: LinearProgressIndicator(
                                        value: xpProgress,
                                        minHeight: 10,
                                        backgroundColor: lightGreen,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                          primaryGreen,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _headerSubtitleText(missionProvider),
                                      style: TextStyle(
                                        color: primaryGreen.withValues(
                                            alpha: 0.75),
                                        fontSize: 11,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (missionProvider.claimableCount > 1) ...[
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed:
                                              missionProvider.claimingId != null
                                                  ? null
                                                  : _handleClaimAll,
                                          icon: missionProvider.claimingId ==
                                                  'ALL'
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: primaryGreen,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.done_all_rounded,
                                                  size: 16,
                                                ),
                                          label: Text(
                                            'Klaim Semua (+${missionProvider.claimableTotalXp} XP)',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFFE5A93B),
                                            foregroundColor: darkGreen,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              side: const BorderSide(
                                                color: primaryGreen,
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          for (int i = 0; i < _visiblePeriods.length; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final period = _visiblePeriods[i];
                                  final isSelected = _selectedPeriod == period;
                                  final hasClaimable =
                                      MissionCatalog.byPeriod(period).any(
                                    (m) =>
                                        missionProvider.statusOf(m) ==
                                        MissionClaimStatus.claimable,
                                  );

                                  return GestureDetector(
                                    onTap: () => setState(
                                      () => _selectedPeriod = period,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected ? primaryGreen : inputBg,
                                        borderRadius:
                                            BorderRadius.circular(100),
                                        border: Border.all(
                                          color: primaryGreen,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                period.label,
                                                maxLines: 1,
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? Colors.white
                                                      : primaryGreen,
                                                  fontSize: 11.5,
                                                  fontFamily: 'Inter',
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (hasClaimable) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  width: 7,
                                                  height: 7,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Color(0xFFDAB62C),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            _selectedPeriod == MissionPeriod.oneTime
                                ? Icons.stars_rounded
                                : Icons.schedule_rounded,
                            size: 14,
                            color: primaryGreen.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _resetCountdownText(
                              _selectedPeriod,
                              missionProvider,
                            ),
                            style: TextStyle(
                              color: primaryGreen.withValues(alpha: 0.75),
                              fontSize: 11,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: missionProvider.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: primaryGreen),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                          itemCount: missions.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = missions[index];
                            final progress =
                                missionProvider.currentProgress(item);
                            final status = missionProvider.statusOf(item);
                            final isClaiming =
                                missionProvider.claimingId == item.id;
                            final displayXp =
                                missionProvider.effectiveXpReward(item);

                            return _MissionCard(
                              item: item,
                              displayXp: displayXp,
                              progress: progress,
                              status: status,
                              isClaiming: isClaiming,
                              onClaim: () => _handleClaim(item),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedStreakFlame extends StatefulWidget {
  final bool isActive;

  const _AnimatedStreakFlame({required this.isActive});

  @override
  State<_AnimatedStreakFlame> createState() => _AnimatedStreakFlameState();
}

class _AnimatedStreakFlameState extends State<_AnimatedStreakFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _tiltAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );

    _scaleAnim = Tween<double>(begin: 0.94, end: 1.18).animate(curved);
    _tiltAnim = Tween<double>(begin: -0.09, end: 0.09).animate(curved);

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedStreakFlame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const Text('\u{1F525}', style: TextStyle(fontSize: 11));
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.identity()
            ..rotateZ(_tiltAnim.value)
            ..scaleByDouble(_scaleAnim.value, _scaleAnim.value, 1.0, 1.0),
          child: child,
        );
      },
      child: const Text('\u{1F525}', style: TextStyle(fontSize: 11.5)),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final MissionItem item;
  final int displayXp;
  final int progress;
  final MissionClaimStatus status;
  final bool isClaiming;
  final VoidCallback onClaim;

  const _MissionCard({
    required this.item,
    required this.displayXp,
    required this.progress,
    required this.status,
    required this.isClaiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = item.targetCount > 0
        ? (progress / item.targetCount).clamp(0.0, 1.0)
        : 0.0;

    return CustomCard(
      backgroundColor: cardBg,
      borderRadius: 18,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primaryGreen, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '+$displayXp',
                  style: const TextStyle(
                    color: primaryGreen,
                    fontSize: 14,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'XP',
                  style: TextStyle(
                    color: primaryGreen,
                    fontSize: 10,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: primaryGreen,
                    fontSize: 14,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: TextStyle(
                    color: primaryGreen.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: lightGreen,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            primaryGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$progress/${item.targetCount}',
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
          const SizedBox(width: 10),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    switch (status) {
      case MissionClaimStatus.claimed:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: lightGreen.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(100),
          ),
          child: const Text(
            'Diklaim',
            style: TextStyle(
              color: primaryGreen,
              fontSize: 11,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case MissionClaimStatus.claimable:
        return ElevatedButton(
          onPressed: isClaiming ? null : onClaim,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE5A93B),
            foregroundColor: darkGreen,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
              side: const BorderSide(color: primaryGreen, width: 1.5),
            ),
          ),
          child: isClaiming
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryGreen,
                  ),
                )
              : const Text(
                  'Klaim',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                  ),
                ),
        );
      case MissionClaimStatus.inProgress:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: primaryGreen.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            'Proses',
            style: TextStyle(
              color: primaryGreen.withValues(alpha: 0.6),
              fontSize: 11,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
        );
    }
  }
}
