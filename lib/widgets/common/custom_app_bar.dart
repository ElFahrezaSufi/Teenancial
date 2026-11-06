import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final IconData backIcon;
  final VoidCallback? onBack;
  final Widget? trailing;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.backIcon = Icons.arrow_back_ios,
    this.onBack,
    this.trailing,
  });

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: appBarBg,
        border: Border(
          bottom: BorderSide(color: primaryGreen, width: 1.5),
        ),
      ),
      child: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (showBackButton)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: IconButton(
                    icon: Icon(
                      backIcon,
                      color: primaryGreen,
                      size: 20,
                    ),
                    onPressed: onBack ?? () => context.pop(),
                  ),
                ),
              ),
            Center(
              child: Text(
                title,
                style: const TextStyle(
                  color: primaryGreen,
                  fontSize: 25,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (trailing != null)
              Align(
                alignment: Alignment.centerRight,
                child: trailing!,
              ),
          ],
        ),
      ),
    );
  }
}
