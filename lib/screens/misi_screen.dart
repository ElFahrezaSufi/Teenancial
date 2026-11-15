import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../data/feen_catalog.dart';
import '../data/mission_catalog.dart';
import '../models/mission_model.dart';
import '../providers/mission_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/feen/feen_avatar.dart';
import '../widgets/feen/feen_unlock_dialog.dart';

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

  Future<void> _handleClaim(MissionItem mission) async {
    final userProvider = context.read<UserProvider>();
    final oldLevel = userProvider.level;

    try {
      final ok = await context.read<MissionProvider>().claimMission(mission);
      if (!ok || !mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 +${mission.xpReward} XP berhasil diklaim!'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengklaim XP, coba lagi.'),
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
                      CustomCard(
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
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Level ${user.level}',
                                        style: const TextStyle(
                                          color: primaryGreen,
                                          fontSize: 17,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        '$currentXp / $nextLevelXp XP',
                                        style: const TextStyle(
                                          color: primaryGreen,
                                          fontSize: 12,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w700,
                                        ),
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
                                    missionProvider.claimableCount > 0
                                        ? 'Ada ${missionProvider.claimableCount} hadiah XP siap diklaim!'
                                        : 'Selesaikan misi untuk menaikkan level Feen.',
                                    style: TextStyle(
                                      color:
                                          primaryGreen.withValues(alpha: 0.75),
                                      fontSize: 11,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _visiblePeriods.map((period) {
                                  final isSelected = _selectedPeriod == period;
                                  final hasClaimable =
                                      MissionCatalog.byPeriod(period).any(
                                    (m) =>
                                        missionProvider.statusOf(m) ==
                                        MissionClaimStatus.claimable,
                                  );

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: GestureDetector(
                                      onTap: () => setState(
                                        () => _selectedPeriod = period,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 9,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? primaryGreen
                                              : inputBg,
                                          borderRadius:
                                              BorderRadius.circular(100),
                                          border: Border.all(
                                            color: primaryGreen,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              period.label,
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Colors.white
                                                    : primaryGreen,
                                                fontSize: 12,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            if (hasClaimable) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFDAB62C),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
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

                            return _MissionCard(
                              item: item,
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

class _MissionCard extends StatelessWidget {
  final MissionItem item;
  final int progress;
  final MissionClaimStatus status;
  final bool isClaiming;
  final VoidCallback onClaim;

  const _MissionCard({
    required this.item,
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
                  '+${item.xpReward}',
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
            backgroundColor: const Color(0xFFDAB62C),
            foregroundColor: primaryGreen,
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
