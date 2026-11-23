import 'package:material_ui/material_ui.dart';
import '../../data/feen_catalog.dart';
import '../../theme/app_colors.dart';

class UserAvatarWithFrame extends StatelessWidget {
  final ImageProvider? avatarImage;
  final String? frameId;
  final double size;
  final double placeholderIconSize;

  const UserAvatarWithFrame({
    super.key,
    required this.avatarImage,
    this.frameId,
    this.size = 68,
    this.placeholderIconSize = 36,
  });

  @override
  Widget build(BuildContext context) {
    final frame = feenById(frameId);
    final hasFrame = frame != null && frame.slot == FeenSlot.frame;
    final double avatarSize = hasFrame ? size * 0.92 : size;
    final double frameSize = hasFrame ? size * frame.frameScale : size;
    final double dy = hasFrame ? size * frame.frameOffsetY : 0.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              color: inputBg,
              shape: BoxShape.circle,
              border:
                  hasFrame ? null : Border.all(color: primaryGreen, width: 2),
              image: avatarImage != null
                  ? DecorationImage(
                      image: avatarImage!,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: avatarImage == null
                ? Icon(
                    Icons.person,
                    color: primaryGreen,
                    size: hasFrame
                        ? placeholderIconSize * 0.9
                        : placeholderIconSize,
                  )
                : null,
          ),
          if (hasFrame)
            Positioned(
              width: frameSize,
              height: frameSize,
              child: Transform.translate(
                offset: Offset(0, dy),
                child: IgnorePointer(
                  child: Image.asset(
                    frame.asset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
