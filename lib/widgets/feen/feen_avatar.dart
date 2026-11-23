import 'package:material_ui/material_ui.dart';
import '../../data/feen_catalog.dart';

class FeenAvatar extends StatelessWidget {
  final int level;
  final FeenPose pose;
  final Map<String, String> equipped;
  final double size;

  const FeenAvatar({
    super.key,
    required this.level,
    this.pose = FeenPose.normal,
    this.equipped = const {},
    this.size = 56,
  });

  String _basePath(FeenTier tier, FeenPose pose) =>
      'assets/feen/base/feen_${tier.name}_${pose.name}.png';

  Widget _layer(BuildContext context, String path, {String? fallback}) {
    final cacheWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Image.asset(
      path,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      cacheWidth: cacheWidth,
      errorBuilder: (_, __, ___) => fallback == null
          ? const SizedBox.shrink()
          : _layer(context, fallback),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tier = tierForLevel(level);

    final layers = <Widget>[
      _layer(
        context,
        _basePath(tier, pose),
        fallback: _basePath(tier, FeenPose.normal),
      ),
    ];
    for (final slot in FeenSlot.values) {
      if (slot == FeenSlot.frame) continue;
      final accessory = feenById(equipped[slot.name]);
      if (accessory != null && accessory.slot == slot) {
        layers.add(_layer(context, accessory.asset));
      }
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(fit: StackFit.expand, children: layers),
    );
  }
}
