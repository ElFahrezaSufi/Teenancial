import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class ActionMenu extends StatelessWidget {
  final String assetPath;
  final String label;
  final VoidCallback onTap;
  final EdgeInsetsGeometry iconPadding;

  const ActionMenu({
    super.key,
    required this.assetPath,
    required this.label,
    required this.onTap,
    this.iconPadding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPng = assetPath.toLowerCase().endsWith('.png');

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
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
                        width: 36,
                        height: 36,
                        color: iconLightGreen,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image,
                                color: iconLightGreen),
                      )
                    : SvgPicture.asset(
                        assetPath,
                        width: 36,
                        height: 36,
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
          Text(label, style: AppTextStyles.captionGreen),
        ],
      ),
    );
  }
}
