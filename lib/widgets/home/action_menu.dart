import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class ActionMenu extends StatelessWidget {
  final String assetPath;
  final String label;
  final VoidCallback onTap;
  final EdgeInsetsGeometry iconPadding;
  final double circleSize;
  final double iconSize;

  const ActionMenu({
    super.key,
    required this.assetPath,
    required this.label,
    required this.onTap,
    this.iconPadding = EdgeInsets.zero,
    this.circleSize = 72,
    this.iconSize = 36,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPng = assetPath.toLowerCase().endsWith('.png');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: circleSize,
            height: circleSize,
            decoration: const BoxDecoration(
              color: primaryGreen,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Padding(
                padding: iconPadding,
                child: isPng
                    ? Image.asset(
                        assetPath,
                        width: iconSize,
                        height: iconSize,
                        color: iconLightGreen,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image,
                                color: iconLightGreen),
                      )
                    : SvgPicture.asset(
                        assetPath,
                        width: iconSize,
                        height: iconSize,
                        colorFilter: const ColorFilter.mode(
                            iconLightGreen, BlendMode.srcIn),
                        placeholderBuilder: (context) => const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: iconLightGreen, strokeWidth: 2),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: AppTextStyles.captionGreen,
            ),
          ),
        ],
      ),
    );
  }
}
