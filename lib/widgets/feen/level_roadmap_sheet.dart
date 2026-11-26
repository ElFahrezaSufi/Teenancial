import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../../data/feen_catalog.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../common/user_avatar_with_frame.dart';
import 'feen_avatar.dart';

Future<void> showLevelRoadmapSheet(BuildContext context) {
  final user = context.read<UserProvider>();
  final currentLevel = user.level;
  final currentXp = user.xpIntoLevel;
  final nextXp = user.xpNeededForNext;
  final profileImageUrl = user.profileImageUrl;

  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (routeContext, animation, secondaryAnimation) {
        return Localizations.override(
          context: routeContext,
          delegates: const [
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          child: Material(
            type: MaterialType.transparency,
            child: _LevelRoadmapModalWrapper(
              currentLevel: currentLevel,
              currentXp: currentXp,
              nextXp: nextXp,
              profileImageUrl: profileImageUrl,
            ),
          ),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    ),
  );
}

class _LevelRoadmapModalWrapper extends StatefulWidget {
  final int currentLevel;
  final int currentXp;
  final int nextXp;
  final String? profileImageUrl;

  const _LevelRoadmapModalWrapper({
    required this.currentLevel,
    required this.currentXp,
    required this.nextXp,
    this.profileImageUrl,
  });

  @override
  State<_LevelRoadmapModalWrapper> createState() =>
      _LevelRoadmapModalWrapperState();
}

class _LevelRoadmapModalWrapperState extends State<_LevelRoadmapModalWrapper> {
  bool _isClosing = false;

  void _close() {
    if (_isClosing || !mounted) return;
    _isClosing = true;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: const SizedBox.expand(),
          ),
        ),
        NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            if (notification.extent <= 0.32) {
              _close();
            }
            return false;
          },
          child: LevelRoadmapSheet(
            currentLevel: widget.currentLevel,
            currentXp: widget.currentXp,
            nextXp: widget.nextXp,
            profileImageUrl: widget.profileImageUrl,
            onClose: _close,
          ),
        ),
      ],
    );
  }
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

  static const ColorFilter _grayscale = ColorFilter.matrix(<double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  List<FeenAccessory> get _allItems => [
        for (final slot in FeenSlot.values) ...feenBySlot(slot),
      ];

  List<int> _buildMilestoneLevels(List<FeenAccessory> items) {
    final levels = <int>{1, 15, 30, currentLevel};
    for (final item in items) {
      levels.add(item.unlockLevel);
    }
    return levels.toList()..sort();
  }

  FeenTier? _tierUnlockedAt(int level) {
    if (level == 1) return FeenTier.rookie;
    if (level == 15) return FeenTier.saver;
    if (level == 30) return FeenTier.pro;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final xpProgress = nextXp > 0 ? (currentXp / nextXp).clamp(0.0, 1.0) : 0.0;

    final ImageProvider? avatarImage =
        (profileImageUrl != null && profileImageUrl!.isNotEmpty)
            ? CachedNetworkImageProvider(profileImageUrl!)
            : null;

    final allItems = _allItems;
    final milestones = _buildMilestoneLevels(allItems);

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: true,
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
                            'Level $currentLevel',
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
                          '$currentXp / $nextXp XP',
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
                    final isUnlocked = currentLevel >= lvl;
                    final isCurrent = currentLevel == lvl;

                    final rewards =
                        allItems.where((a) => a.unlockLevel == lvl).toList();
                    final evolvedTier = _tierUnlockedAt(lvl);

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
                                        grayscale: _grayscale,
                                      ),
                                    ],
                                    for (final item in rewards) ...[
                                      const SizedBox(height: 10),
                                      _ItemRewardRow(
                                        item: item,
                                        isUnlocked: isUnlocked,
                                        avatarImage: avatarImage,
                                        grayscale: _grayscale,
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
  final ColorFilter grayscale;

  const _EvolutionRewardRow({
    required this.tier,
    required this.unlockLevel,
    required this.isUnlocked,
    required this.grayscale,
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
        colorFilter: grayscale,
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
  final ColorFilter grayscale;

  const _ItemRewardRow({
    required this.item,
    required this.isUnlocked,
    required this.avatarImage,
    required this.grayscale,
  });

  @override
  Widget build(BuildContext context) {
    Widget preview = item.slot == FeenSlot.frame
        ? UserAvatarWithFrame(
            avatarImage: avatarImage,
            frameId: item.id,
            size: 44,
            placeholderIconSize: 22,
          )
        : FeenAvatar(
            level: item.unlockLevel,
            equipped: {item.slot.name: item.id},
            size: 48,
          );

    if (!isUnlocked) {
      preview = ColorFiltered(
        colorFilter: grayscale,
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
