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
    return GestureDetector(
      onTap: () => onSelect(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: inputBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primaryGreen,
            width: isSelected ? 3.0 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryGreen.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: primaryGreen, size: 28),
            const SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(
                color: primaryGreen,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}