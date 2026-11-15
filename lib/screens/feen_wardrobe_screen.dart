import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../data/feen_catalog.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/feen/feen_avatar.dart';

class FeenWardrobeScreen extends StatelessWidget {
  const FeenWardrobeScreen({super.key});
  static const List<FeenSlot> _slotOrder = [
    FeenSlot.head,
    FeenSlot.face,
    FeenSlot.neck,
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final level = user.level;
    final equipped = user.feenEquipped;
    final tier = tierForLevel(level);

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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        FeenAvatar(
                          level: level,
                          equipped: equipped,
                          size: 200,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Level $level  •  ${tier.label}',
                          style: AppTextStyles.sectionTitle,
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: equipped.isEmpty
                              ? null
                              : () =>
                                  context.read<UserProvider>().unequipAllFeen(),
                          child: Text(
                            'Lepas semua aksesoris',
                            style: TextStyle(
                              color:
                                  equipped.isEmpty ? Colors.grey : orangeText,
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
                  for (final slot in _slotOrder) ...[
                    Text(slot.label, style: AppTextStyles.sectionTitle),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.82,
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
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onTapAccessory(
    BuildContext context, {
    required FeenAccessory accessory,
    required int level,
    required bool selected,
  }) {
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
    context
        .read<UserProvider>()
        .equipFeen(accessory.slot, selected ? null : accessory.id);
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

  @override
  Widget build(BuildContext context) {
    Widget preview = FeenAvatar(
      level: level,
      equipped: {accessory.slot.name: accessory.id},
      size: 80,
    );
    if (locked) {
      preview = ColorFiltered(
        colorFilter: _grayscale,
        child: Opacity(opacity: 0.45, child: preview),
      );
    }

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
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    preview,
                    if (locked)
                      const Icon(Icons.lock_rounded,
                          color: primaryGreen, size: 22),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                accessory.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: primaryGreen,
                  fontSize: 11,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                locked
                    ? 'Level ${accessory.unlockLevel}'
                    : (selected ? 'Dipakai' : 'Pakai'),
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
