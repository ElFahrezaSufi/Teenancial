import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class CustomDropdownField extends StatelessWidget {
  final String label;
  final String hint;
  final String? value;
  final List<String> items;
  final void Function(String?)? onChanged;
  final String? Function(String?)? validator;

  const CustomDropdownField({
    super.key,
    required this.label,
    required this.hint,
    required this.items,
    this.value,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: FormField<String>(
        validator: validator,
        initialValue: value,
        builder: (FormFieldState<String> state) {
          return Column(
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
              Container(
                decoration: BoxDecoration(
                  color: state.hasError ? Colors.redAccent : primaryGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: state.hasError ? Colors.redAccent : primaryGreen,
                      width: 2,
                    ),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: state.value,
                    onChanged: (newValue) {
                      state.didChange(newValue);
                      if (onChanged != null) {
                        onChanged!(newValue);
                      }
                    },
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: state.hasError ? Colors.redAccent : primaryGreen,
                    ),
                    style: const TextStyle(
                      color: primaryGreen,
                      fontSize: 15,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(
                        color: primaryGreen.withValues(alpha: 0.5),
                        fontSize: 15,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    items: items.map((String item) {
                      return DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16),
                  child: Text(
                    state.errorText ?? '',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
