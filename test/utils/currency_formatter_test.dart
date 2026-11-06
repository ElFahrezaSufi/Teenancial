import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teenancial/utils/currency_formatter.dart';

void main() {
  group('Formatters.rupiah()', () {
    test('memformat angka dengan titik pemisah ribuan tanpa desimal ,00', () {
      expect(Formatters.rupiah(0), 'Rp 0');
      expect(Formatters.rupiah(50000), 'Rp 50.000');
      expect(Formatters.rupiah(100000), 'Rp 100.000');
      expect(Formatters.rupiah(2075000), 'Rp 2.075.000');
    });
  });

  group('CurrencyInputFormatter', () {
    final formatter = CurrencyInputFormatter();

    test('formatValue memformat string digit menjadi format Rupiah bertitik', () {
      expect(CurrencyInputFormatter.formatValue(''), '');
      expect(CurrencyInputFormatter.formatValue('100000'), 'Rp 100.000');
      expect(CurrencyInputFormatter.formatValue('Rp 250.000'), 'Rp 250.000');
    });

    test('formatEditUpdate memformat ketikan secara real-time', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '100000',
        selection: TextSelection.collapsed(offset: 6),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, 'Rp 100.000');
    });

    test('membatasi input maksimal 12 digit (Rp 999.999.999.999) untuk mencegah overflow', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '999999999999123',
        selection: TextSelection.collapsed(offset: 15),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, 'Rp 999.999.999.999');
    });

    test('mengembalikan string kosong bila input tidak mengandung angka', () {
      const oldValue = TextEditingValue(text: 'Rp 5');
      const newValue = TextEditingValue(
        text: 'Rp ',
        selection: TextSelection.collapsed(offset: 3),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '');
    });
  });
}
