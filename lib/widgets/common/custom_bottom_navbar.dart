import 'package:material_ui/material_ui.dart';
import '../../theme/app_colors.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: scaffoldBg,
      child: Container(
        decoration: BoxDecoration(
          color: primaryGreen,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        padding: const EdgeInsets.only(top: 1.8, left: 1.5, right: 1.5),
        child: Container(
          decoration: const BoxDecoration(
            color: appBarBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22.5)),
          ),
          child: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isCompact = constraints.maxWidth < 360;
                final double horizontalPadding = isCompact ? 10.0 : 16.0;
                final double itemHorizontalPadding = isCompact ? 4.0 : 8.0;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    8,
                    horizontalPadding,
                    8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildNavItem(
                          icon: Icons.home_filled,
                          label: 'Beranda',
                          index: 0,
                          horizontalPadding: itemHorizontalPadding,
                        ),
                      ),
                      Expanded(
                        child: _buildNavItem(
                          icon: Icons.account_balance_wallet,
                          label: 'Dompet',
                          index: 1,
                          horizontalPadding: itemHorizontalPadding,
                        ),
                      ),
                      Expanded(
                        child: _buildNavItem(
                          icon: Icons.history,
                          label: 'Riwayat',
                          index: 2,
                          horizontalPadding: itemHorizontalPadding,
                        ),
                      ),
                      Expanded(
                        child: _buildNavItem(
                          icon: Icons.person,
                          label: 'Akun',
                          index: 3,
                          horizontalPadding: itemHorizontalPadding,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required double horizontalPadding,
  }) {
    final bool isActive = selectedIndex == index;

    return GestureDetector(
      onTap: () => onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? primaryGreen.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: isActive ? Border.all(color: primaryGreen, width: 1.5) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: primaryGreen, size: 24),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: primaryGreen,
                  fontSize: 11,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
