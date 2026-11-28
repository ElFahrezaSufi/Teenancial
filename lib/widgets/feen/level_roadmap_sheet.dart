import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../data/feen_catalog.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../common/user_avatar_with_frame.dart';
import 'feen_avatar.dart';

Future<void> showLevelRoadmapSheet(BuildContext context) {
  final user = Provider.of<UserProvider?>(context, listen: false);
  final currentLevel = user?.level ?? 1;
  final currentXp = user?.xpIntoLevel ?? 0;
  final nextXp = user?.xpNeededForNext ?? 500;
  final profileImageUrl = user?.profileImageUrl;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (sheetContext) {
      return LevelRoadmapSheet(
        currentLevel: currentLevel,
        currentXp: currentXp,
        nextXp: nextXp,
        profileImageUrl: profileImageUrl,
        onClose: () => Navigator.of(sheetContext).maybePop(),
      );
    },
  );
}

class LevelRoadmapSheet extends StatelessWidget {
  final int currentLevel;
  final int currentXp;
  final int nextXp;
  final String? profileImageUrl;
  final VoidCallback? onClose;

  const LevelRoadmapSheet({
    super.key,
    required this.currentLevel,
    required this.currentXp,
    required this.nextXp,
    this.profileImageUrl,
    this.onClose,
  });

  List<FeenAccessory> get _allItems => [
        for (final slot in FeenSlot.values) ...feenBySlot(slot),
      ];

  List<int> _buildMilestoneLevels(
    List<FeenAccessory> items,
    int effectiveLevel,
  ) {
    final levels = <int>{
      for (final tier in FeenTier.values) tier.minLevel,
      effectiveLevel,
    };
    for (final item in items) {
      levels.add(item.unlockLevel);
    }
    return levels.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    // Jika UserProvider tersedia di tree, ikuti pembaruan level/XP secara live.
    final liveUser = Provider.of<UserProvider?>(context);
    final int effectiveLevel = liveUser?.level ?? currentLevel;
    final int effectiveXp = liveUser?.xpIntoLevel ?? currentXp;
    final int effectiveNextXp = liveUser?.xpNeededForNext ?? nextXp;
    final String? effectiveImageUrl =
        liveUser?.profileImageUrl ?? profileImageUrl;

    final xpProgress = effectiveNextXp > 0
        ? (effectiveXp / effectiveNextXp).clamp(0.0, 1.0)
        : 0.0;

    final ImageProvider? avatarImage =
        (effectiveImageUrl != null && effectiveImageUrl.isNotEmpty)
            ? CachedNetworkImageProvider(effectiveImageUrl)
            : null;

    final allItems = _allItems;
    final milestones = _buildMilestoneLevels(allItems, effectiveLevel);

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: scaffoldBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: primaryGreen, width: 2),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: primaryGreen.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Peta Hadiah Level',
                            style: TextStyle(
                              color: primaryGreen,
                              fontSize: 18,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primaryGreen,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            'Level $effectiveLevel',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (onClose != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: onClose,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: inputBg,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primaryGreen.withValues(alpha: 0.35),
                                ),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 17,
                                color: primaryGreen,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: LinearProgressIndicator(
                              value: xpProgress,
                              minHeight: 8,
                              backgroundColor: lightGreen,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                primaryGreen,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$effectiveXp / $effectiveNextXp XP',
                          style: const TextStyle(
                            color: primaryGreen,
                            fontSize: 11.5,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Divider(
                height: 1,
                color: primaryGreen.withValues(alpha: 0.15),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  itemCount: milestones.length,
                  itemBuilder: (context, index) {
                    final lvl = milestones[index];
                    final isLast = index == milestones.length - 1;
                    final isUnlocked = effectiveLevel >= lvl;
                    final isCurrent = effectiveLevel == lvl;

                    final rewards =
                        allItems.where((a) => a.unlockLevel == lvl).toList();
                    final evolvedTier = tierUnlockedAt(lvl);

                    return Stack(
                      children: [
                        if (!isLast)
                          Positioned(
                            left: 16.5,
                            top: 36,
                            bottom: 0,
                            width: 3,
                            child: Container(
                              color: isUnlocked
                                  ? primaryGreen
                                  : primaryGreen.withValues(alpha: 0.2),
                            ),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? const Color(0xFFE5A93B)
                                    : (isUnlocked ? primaryGreen : inputBg),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primaryGreen,
                                  width: isCurrent ? 2.5 : 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$lvl',
                                  style: TextStyle(
                                    color: isCurrent
                                        ? darkGreen
                                        : (isUnlocked
                                            ? Colors.white
                                            : primaryGreen),
                                    fontSize: 13,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isCurrent ? inputBg : cardBg,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isCurrent
                                        ? orangeText
                                        : (isUnlocked
                                            ? primaryGreen
                                            : primaryGreen.withValues(
                                                alpha: 0.3,
                                              )),
                                    width: isCurrent ? 2.2 : 1.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Level $lvl',
                                          style: const TextStyle(
                                            color: primaryGreen,
                                            fontSize: 14,
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        _StatusBadge(
                                          isCurrent: isCurrent,
                                          isUnlocked: isUnlocked,
                                        ),
                                      ],
                                    ),
                                    if (evolvedTier != null) ...[
                                      const SizedBox(height: 10),
                                      _EvolutionRewardRow(
                                        tier: evolvedTier,
                                        unlockLevel: lvl,
                                        isUnlocked: isUnlocked,
                                      ),
                                    ],
                                    for (final item in rewards) ...[
                                      const SizedBox(height: 10),
                                      _ItemRewardRow(
                                        item: item,
                                        isUnlocked: isUnlocked,
                                        avatarImage: avatarImage,
                                      ),
                                    ],
                                    if (evolvedTier == null &&
                                        rewards.isEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Posisi kamu sekarang. Kumpulkan XP untuk membuka hadiah berikutnya!',
                                        style: TextStyle(
                                          color: primaryGreen.withValues(
                                            alpha: 0.7,
                                          ),
                                          fontSize: 11.5,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isCurrent;
  final bool isUnlocked;

  const _StatusBadge({
    required this.isCurrent,
    required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    if (isCurrent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFE5A93B),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: primaryGreen, width: 1),
        ),
        child: const Text(
          'Posisi Kamu',
          style: TextStyle(
            color: darkGreen,
            fontSize: 10,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    if (isUnlocked) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: primaryGreen, size: 15),
          SizedBox(width: 4),
          Text(
            'Terbuka',
            style: TextStyle(
              color: primaryGreen,
              fontSize: 11,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.lock_rounded,
          color: primaryGreen.withValues(alpha: 0.55),
          size: 14,
        ),
        const SizedBox(width: 4),
        Text(
          'Terkunci',
          style: TextStyle(
            color: primaryGreen.withValues(alpha: 0.55),
            fontSize: 11,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EvolutionRewardRow extends StatelessWidget {
  final FeenTier tier;
  final int unlockLevel;
  final bool isUnlocked;

  const _EvolutionRewardRow({
    required this.tier,
    required this.unlockLevel,
    required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    Widget preview = FeenAvatar(
      level: unlockLevel,
      pose: FeenPose.levelup,
      size: 48,
    );
    if (!isUnlocked) {
      preview = ColorFiltered(
        colorFilter: feenLockedGrayscaleFilter,
        child: Opacity(opacity: 0.5, child: preview),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scaffoldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryGreen.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          preview,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EVOLUSI MASKOT',
                  style: TextStyle(
                    color: orangeText,
                    fontSize: 9.5,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Feen ${tier.label}',
                  style: const TextStyle(
                    color: primaryGreen,
                    fontSize: 13,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
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

class _ItemRewardRow extends StatelessWidget {
  final FeenAccessory item;
  final bool isUnlocked;
  final ImageProvider? avatarImage;

  const _ItemRewardRow({
    required this.item,
    required this.isUnlocked,
    required this.avatarImage,
  });

  @override
  Widget build(BuildContext context) {
    Widget preview = item.slot == FeenSlot.frame
        ? UserAvatarWithFrame(
            avatarImage: avatarImage,
            frameId: item.id,
            size: 48,
            placeholderIconSize: 22,
          )
        : FeenAvatar(
            level: item.unlockLevel,
            equipped: {item.slot.name: item.id},
            size: 48,
          );

    if (!isUnlocked) {
      preview = ColorFiltered(
        colorFilter: feenLockedGrayscaleFilter,
        child: Opacity(opacity: 0.5, child: preview),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scaffoldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryGreen.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: Center(child: preview),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.slot.label.toUpperCase(),
                  style: TextStyle(
                    color: primaryGreen.withValues(alpha: 0.65),
                    fontSize: 9.5,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  item.name,
                  style: const TextStyle(
                    color: primaryGreen,
                    fontSize: 13,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
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
