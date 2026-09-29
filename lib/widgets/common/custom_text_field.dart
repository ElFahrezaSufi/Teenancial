import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final bool obscureText;

  const CustomTextField({
    super.key,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.controller,
    this.validator,
    this.inputFormatters,
    this.suffixIcon,
    this.prefixIcon,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: FormField<String>(
        validator: validator,
        initialValue: controller?.text,
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
                        width: 2),
                  ),
                  child: TextField(
                    controller: controller,
                    obscureText: obscureText,
                    keyboardType: keyboardType,
                    readOnly: readOnly,
                    onTap: onTap,
                    inputFormatters: inputFormatters,
                    onChanged: (value) {
                      state.didChange(value);
                    },
                    style: const TextStyle(
                        color: primaryGreen,
                        fontSize: 15,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(
                          color: primaryGreen.withValues(alpha: 0.5),
                          fontSize: 15,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500),
                      prefixIcon: prefixIcon,
                      suffixIcon: suffixIcon,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: prefixIcon == null ? 16 : 0),
                    ),
                  ),
                ),
              ),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16),
                  child: Text(state.errorText ?? '',
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600)),
                ),
            ],
          );
        },
      ),
    );
  }
}
