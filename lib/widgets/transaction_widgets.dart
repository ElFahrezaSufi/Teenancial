import 'package:flutter/material.dart';

const Color primaryGreen = Color(0xFF627931);
const Color inputBg = Color(0xFFF8FFE8);

class CustomTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;

  const CustomTextField({
    super.key,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          TextFormField(
            readOnly: readOnly,
            onTap: onTap,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: primaryGreen,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: primaryGreen.withOpacity(0.5),
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: inputBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryGreen, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryGreen, width: 2.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
                    color: primaryGreen.withOpacity(0.2),
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
                          color: primaryGreen.withOpacity(0.2),
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

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
