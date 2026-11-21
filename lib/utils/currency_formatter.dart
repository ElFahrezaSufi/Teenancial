import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final NumberFormat _rupiahFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Format angka menjadi string mata uang Rupiah tanpa desimal (misal: `Rp 50.000`).
  static String rupiah(num value) {
    return _rupiahFormat.format(value.round());
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  /// Maksimal 9 digit (Rp 999.999.999) agar nominal tetap realistis & rapi di UI.
  static const int maxDigits = 9;

  static String _sanitizeDigits(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    final normalized = digits.replaceFirst(RegExp(r'^0+'), '');
    if (normalized.isEmpty) return '0';
    if (normalized.length > maxDigits) {
      return normalized.substring(0, maxDigits);
    }
    return normalized;
  }

  static String formatValue(String value) {
    if (value.isEmpty) return '';
    final digits = _sanitizeDigits(value);
    if (digits.isEmpty) return '';
    final int number = int.tryParse(digits) ?? 0;
    return Formatters.rupiah(number);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    if (newValue.text.compareTo(oldValue.text) != 0) {
      final String digits = _sanitizeDigits(newValue.text);
      if (digits.isEmpty) {
        return const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        );
      }
      final int selectionIndexFromTheRight =
          newValue.text.length - newValue.selection.end;
      final int number = int.tryParse(digits) ?? 0;
      final String newString = Formatters.rupiah(number);
      final int offset =
          (newString.length - selectionIndexFromTheRight).clamp(
        0,
        newString.length,
      );
      return TextEditingValue(
        text: newString,
        selection: TextSelection.collapsed(offset: offset),
      );
    }
    return newValue;
  }
}
