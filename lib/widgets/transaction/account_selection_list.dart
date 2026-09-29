import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class AccountSelectionList extends StatelessWidget {
  final int? selectedIndex;
  final Function(int) onSelect;

  const AccountSelectionList({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> accounts = const ['SeaBank', 'Go-Pay', 'Dana', 'Ovo'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        children: List.generate(accounts.length, (index) {
          final isSelected = selectedIndex == index;
          const double borderRadius = 12.0;
          final Color activeStroke =
              isSelected ? primaryGreen : primaryGreen.withValues(alpha: 0.3);
          final Color contentColor =
              isSelected ? primaryGreen : primaryGreen.withValues(alpha: 0.5);

          return GestureDetector(
            onTap: () => onSelect(index),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            accounts[index],
                            style: TextStyle(
                              color: contentColor,
                              fontSize: 14,
                              fontFamily: 'Inter',
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Rp xx.xxx,xx',
                            style: TextStyle(
                              color: contentColor,
                              fontSize: 12,
                              fontFamily: 'Inter',
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
