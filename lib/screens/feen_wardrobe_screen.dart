import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../data/feen_catalog.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/error_mapper.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/common/user_avatar_with_frame.dart';
import '../widgets/feen/feen_avatar.dart';

class FeenWardrobeScreen extends StatefulWidget {
  const FeenWardrobeScreen({super.key});
  static const List<FeenSlot> _slotOrder = [
    FeenSlot.head,
    FeenSlot.face,
    FeenSlot.neck,
  ];

  @override
  State<FeenWardrobeScreen> createState() => _FeenWardrobeScreenState();
}

class _FeenWardrobeScreenState extends State<FeenWardrobeScreen> {
  bool _isUpdating = false;
  bool _isUnequippingAll = false;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final level = user.level;
    final equipped = user.feenEquipped;
    final bool hasEquippedAccessories =
        equipped.keys.any((key) => key != FeenSlot.frame.name);
    final tier = tierForLevel(level);
    final remoteImageUrl = user.profileImageUrl;
    final ImageProvider? avatarImage =
        (remoteImageUrl != null && remoteImageUrl.isNotEmpty)
            ? CachedNetworkImageProvider(remoteImageUrl)
            : null;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: const CustomAppBar(title: 'Lemari Feen'),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: scaffoldBg,
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                'assets/images/bg_curve.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomCard(
                    borderRadius: 24,
                    backgroundColor: cardBg,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      children: [
                        FeenAvatar(
                          level: level,
                          equipped: equipped,
                          size: 190,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: primaryGreen,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            'Level $level  |  Feen ${tier.label}',
                            style: const TextStyle(
                              color: primaryGreen,
                              fontSize: 13,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FeenEvolutionStagesRow(
                          currentLevel: level,
                          currentTier: tier,
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: (!hasEquippedAccessories || _isUpdating)
                              ? null
                              : () => _handleUnequipAll(context),
                          child: _isUnequippingAll
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: orangeText,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Lepas semua aksesoris',
                                  style: TextStyle(
                                    color: (!hasEquippedAccessories ||
                                            _isUpdating)
                                        ? Colors.grey
                                        : orangeText,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (final slot in FeenWardrobeScreen._slotOrder) ...[
                    Text(slot.label, style: AppTextStyles.sectionTitle),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, gridConstraints) {
                        final int columns =
                            gridConstraints.maxWidth >= 460 ? 4 : 3;
                        final double aspectRatio =
                            gridConstraints.maxWidth < 300 ? 0.68 : 0.78;
                        return GridView.count(
                          crossAxisCount: columns,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: aspectRatio,
                          children: [
                            for (final accessory in feenBySlot(slot))
                              _AccessoryTile(
                                accessory: accessory,
                                level: level,
                                selected: equipped[slot.name] == accessory.id,
                                locked: level < accessory.unlockLevel,
                                onTap: () => _onTapAccessory(
                                  context,
                                  accessory: accessory,
                                  level: level,
                                  selected: equipped[slot.name] == accessory.id,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(FeenSlot.frame.label, style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, gridConstraints) {
                      final int columns =
                          gridConstraints.maxWidth >= 460 ? 4 : 3;
                      final double aspectRatio =
                          gridConstraints.maxWidth < 300 ? 0.68 : 0.78;
                      return GridView.count(
                        crossAxisCount: columns,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: aspectRatio,
                        children: [
                          for (final frame in feenBySlot(FeenSlot.frame))
                            _FrameTile(
                              frame: frame,
                              avatarImage: avatarImage,
                              selected:
                                  equipped[FeenSlot.frame.name] == frame.id,
                              locked: level < frame.unlockLevel,
                              onTap: () => _onTapAccessory(
                                context,
                                accessory: frame,
                                level: level,
                                selected:
                                    equipped[FeenSlot.frame.name] == frame.id,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUnequipAll(BuildContext context) async {
    if (_isUpdating) return;
    setState(() {
      _isUpdating = true;
      _isUnequippingAll = true;
    });
    try {
      await context.read<UserProvider>().unequipAllFeen();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(ErrorMapper.message(e)),
              backgroundColor: Colors.redAccent,
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _isUnequippingAll = false;
        });
      }
    }
  }

  Future<void> _onTapAccessory(
    BuildContext context, {
    required FeenAccessory accessory,
    required int level,
    required bool selected,
  }) async {
    if (_isUpdating) return;
    if (level < accessory.unlockLevel) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${accessory.name} terbuka di level ${accessory.unlockLevel}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      return;
    }
    setState(() => _isUpdating = true);
    try {
      await context
          .read<UserProvider>()
          .equipFeen(accessory.slot, selected ? null : accessory.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(ErrorMapper.message(e)),
              backgroundColor: Colors.redAccent,
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }
}

class _FeenEvolutionStagesRow extends StatelessWidget {
  final int currentLevel;
  final FeenTier currentTier;

  const _FeenEvolutionStagesRow({
    required this.currentLevel,
    required this.currentTier,
  });

  @override
  Widget build(BuildContext context) {
    const stages = FeenTier.values;
    return Row(
      children: [
        for (int i = 0; i < stages.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 13,
                color: primaryGreen.withValues(alpha: 0.55),
              ),
            ),
          Expanded(
            child: Builder(
              builder: (context) {
                final stage = stages[i];
                final isCurrent = currentTier == stage;
                final isUnlocked = currentLevel >= stage.minLevel;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? primaryGreen
                        : (isUnlocked
                            ? inputBg
                            : inputBg.withValues(alpha: 0.55)),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: isUnlocked
                          ? primaryGreen
                          : primaryGreen.withValues(alpha: 0.3),
                      width: isCurrent ? 1.5 : 1,
                    ),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCurrent
                                ? Icons.auto_awesome_rounded
                                : (isUnlocked
                                    ? Icons.check_circle_rounded
                                    : Icons.lock_outline_rounded),
                            size: 12,
                            color: isCurrent
                                ? const Color(0xFFDAB62C)
                                : (isUnlocked
                                    ? primaryGreen
                                    : primaryGreen.withValues(alpha: 0.5)),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${stage.label} (Lv.${stage.minLevel})',
                            style: TextStyle(
                              color: isCurrent
                                  ? Colors.white
                                  : (isUnlocked
                                      ? primaryGreen
                                      : primaryGreen.withValues(alpha: 0.55)),
                              fontSize: 10.5,
                              fontFamily: 'Inter',
                              fontWeight:
                                  isCurrent ? FontWeight.w800 : FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _AccessoryTile extends StatelessWidget {
  final FeenAccessory accessory;
  final int level;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  const _AccessoryTile({
    required this.accessory,
    required this.level,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: locked
          ? '${accessory.name}, terkunci, terbuka di level ${accessory.unlockLevel}'
          : '${accessory.name}${selected ? ', sedang dipakai' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? orangeText : primaryGreen,
              width: selected ? 3 : 1.5,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final double previewSize =
                        math.min(box.maxWidth, box.maxHeight).clamp(40.0, 74.0);
                    Widget preview = FeenAvatar(
                      level: level,
                      equipped: {accessory.slot.name: accessory.id},
                      size: previewSize,
                    );
                    if (locked) {
                      preview = ColorFiltered(
                        colorFilter: feenLockedGrayscaleFilter,
                        child: Opacity(opacity: 0.45, child: preview),
                      );
                    }
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        preview,
                        if (locked)
                          const Icon(
                            Icons.lock_rounded,
                            color: primaryGreen,
                            size: 22,
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              Text(
                accessory.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: primaryGreen,
                  fontSize: 10.5,
                  height: 1.15,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                locked
                    ? 'Level ${accessory.unlockLevel}'
                    : (selected ? 'Dipakai' : 'Pakai'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: locked
                      ? Colors.grey
                      : (selected ? orangeText : primaryGreen),
                  fontSize: 10,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrameTile extends StatelessWidget {
  final FeenAccessory frame;
  final ImageProvider? avatarImage;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  const _FrameTile({
    required this.frame,
    required this.avatarImage,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: locked
          ? '${frame.name}, terkunci, terbuka di level ${frame.unlockLevel}'
          : '${frame.name}${selected ? ', sedang dipakai' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? orangeText : primaryGreen,
              width: selected ? 3 : 1.5,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final double previewSize =
                        math.min(box.maxWidth, box.maxHeight).clamp(42.0, 76.0);
                    Widget preview = UserAvatarWithFrame(
                      avatarImage: avatarImage,
                      frameId: frame.id,
                      size: previewSize,
                      placeholderIconSize:
                          (previewSize * 0.4).clamp(18.0, 30.0),
                    );
                    if (locked) {
                      preview = ColorFiltered(
                        colorFilter: feenLockedGrayscaleFilter,
                        child: Opacity(opacity: 0.45, child: preview),
                      );
                    }
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        preview,
                        if (locked)
                          const Icon(
                            Icons.lock_rounded,
                            color: primaryGreen,
                            size: 22,
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              Text(
                frame.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: primaryGreen,
                  fontSize: 10.5,
                  height: 1.15,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                locked
                    ? 'Level ${frame.unlockLevel}'
                    : (selected ? 'Dipakai' : 'Pakai'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: locked
                      ? Colors.grey
                      : (selected ? orangeText : primaryGreen),
                  fontSize: 10,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
