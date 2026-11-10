import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teenancial/widgets/common/date_picker_field.dart';

void main() {
  group('DatePickerField', () {
    testWidgets('menampilkan nilai awal, tombol hapus saat clearable, dan validasi', (
      tester,
    ) async {
      DateTime? currentDate = DateTime(2026, 12, 31);
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Form(
                  key: formKey,
                  child: DatePickerField(
                    label: 'Tenggat',
                    hint: 'Pilih tanggal',
                    value: currentDate,
                    clearable: true,
                    onChanged: (val) => setState(() => currentDate = val),
                    validator: (val) =>
                        val == null ? 'Tanggal wajib diisi' : null,
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Tenggat'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(formKey.currentState!.validate(), isTrue);

      // Tekan tombol hapus (X)
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(currentDate, isNull);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Tanggal wajib diisi'), findsOneWidget);
    });
  });
}
