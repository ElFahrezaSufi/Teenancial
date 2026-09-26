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
          return GestureDetector(
            onTap: () => onSelect(index),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    accounts[index],
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Rp xx.xxx,xx',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}