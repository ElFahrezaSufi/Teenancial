import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class SourceToggle extends StatelessWidget {
  final String label;
  final String option1;
  final IconData icon1;
  final String option2;
  final IconData icon2;
  final int selectedIndex;
  final Function(int) onSelect;

  const SourceToggle({
    super.key,
    required this.label,
    required this.option1,
    required this.icon1,
    required this.option2,
    required this.icon2,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            Text(
              label,
              style: const TextStyle(
                color: primaryGreen,
                fontSize: 14,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: _buildOption(0, option1, icon1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOption(1, option2, icon2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOption(int index, String text, IconData icon) {
    final isSelected = selectedIndex == index;
    const double borderRadius = 12.0;
    IconData displayIcon = icon;
    if (text == 'Cash' && icon == Icons.money) {
      displayIcon = Icons.payments_outlined;
    } else if (text == 'Digital' && icon == Icons.phone_android) {
      displayIcon = Icons.smartphone_outlined;
    }

    final Color activeStroke =
        isSelected ? primaryGreen : primaryGreen.withValues(alpha: 0.3);
    final Color contentColor =
        isSelected ? primaryGreen : primaryGreen.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: () => onSelect(index),
      child: Container(
        decoration: BoxDecoration(
          color: activeStroke,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: activeStroke, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius - 2),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(displayIcon, color: contentColor, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: TextStyle(
                      color: contentColor,
                      fontSize: 14,
                      fontFamily: 'Inter',
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
