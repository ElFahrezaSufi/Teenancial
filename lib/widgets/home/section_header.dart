import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onActionTap;

  const SectionHeader({
    super.key, 
    required this.title, 
    this.actionText, 
    this.onActionTap
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                color: primaryGreen,
                fontSize: 18,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800)),
        if (actionText != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(actionText!, style: AppTextStyles.actionText),
          ),
      ],
    );
  }
}
