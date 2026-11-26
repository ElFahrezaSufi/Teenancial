import 'package:material_ui/material_ui.dart';
import '../../data/feen_catalog.dart';
import '../../theme/app_colors.dart';

/// Menampilkan avatar pengguna (foto profil atau ikon placeholder) lengkap
/// dengan bingkai kosmetik opsional.
///
/// Secara default (`fitWithinBounds: true`), seluruh bingkai dirender di dalam
/// kotak berukuran [size] x [size] agar tidak pernah terpotong oleh `ClipRRect`
/// parent maupun menabrak teks/elemen di sekitarnya.
class UserAvatarWithFrame extends StatelessWidget {
  final ImageProvider? avatarImage;
  final String? frameId;
  final double size;
  final double placeholderIconSize;
  final bool fitWithinBounds;

  const UserAvatarWithFrame({
    super.key,
    required this.avatarImage,
    this.frameId,
    this.size = 68,
    this.placeholderIconSize = 36,
    this.fitWithinBounds = true,
  });

  @override
  Widget build(BuildContext context) {
    final frame = feenById(frameId);
    final bool hasFrame = frame != null && frame.slot == FeenSlot.frame;

    // Rasio diameter bingkai terhadap lingkaran foto mengikuti desain asli
    // (`frameScale / 0.92`) agar ornamen bingkai tetap pas melingkari foto.
    final double frameSize;
    final double avatarSize;
    final double dy;
    final double boxSize;

    if (hasFrame) {
      if (fitWithinBounds) {
        final double extraOffset = frame.frameOffsetY.abs() * 2;
        final double divisor = frame.frameScale + extraOffset;
        final double baseUnit = size / divisor;
        frameSize = baseUnit * frame.frameScale;
        avatarSize = baseUnit * 0.92;
        dy = baseUnit * frame.frameOffsetY;
        boxSize = size;
      } else {
        avatarSize = size * 0.92;
        frameSize = size * frame.frameScale;
        dy = size * frame.frameOffsetY;
        boxSize = frameSize + (dy.abs() * 2);
      }
    } else {
      avatarSize = size;
      frameSize = size;
      dy = 0.0;
      boxSize = size;
    }

    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final int? cacheWidth = hasFrame
        ? (frameSize * dpr).round().clamp(64, 512)
        : null;

    final double resolvedIconSize = hasFrame
        ? (placeholderIconSize * (avatarSize / size)).clamp(14.0, avatarSize * 0.65)
        : placeholderIconSize;

    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Stack(
        alignment: Alignment.center,
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
                    size: resolvedIconSize,
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
                    cacheWidth: cacheWidth,
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
