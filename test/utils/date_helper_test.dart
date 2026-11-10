import 'package:flutter_test/flutter_test.dart';
import 'package:teenancial/utils/date_helper.dart';

void main() {
  group('DateHelper', () {
    test('dateOnly membuang komponen jam, menit, detik, dan milidetik', () {
      final raw = DateTime(2026, 11, 10, 22, 35, 19, 400);
      expect(DateHelper.dateOnly(raw), DateTime(2026, 11, 10));
    });

    test('daysBetween menghitung selisih hari kalender tanpa pengaruh jam', () {
      final lateNight = DateTime(2026, 11, 10, 23, 59);
      final earlyMorningNextDay = DateTime(2026, 11, 11, 0, 1);

      expect(DateHelper.daysBetween(lateNight, earlyMorningNextDay), 1);
      expect(DateHelper.daysBetween(earlyMorningNextDay, lateNight), -1);
      expect(DateHelper.daysBetween(lateNight, DateTime(2026, 11, 10, 1, 0)), 0);
    });

    test(
      'withCurrentTime mempertahankan original jika tanggal kalender tidak berubah',
      () {
        final original = DateTime(2026, 11, 5, 14, 20, 30);
        final pickedSameDay = DateTime(2026, 11, 5);
        final clock = DateTime(2026, 11, 10, 9, 15, 0);

        final result = DateHelper.withCurrentTime(
          pickedSameDay,
          original: original,
          now: clock,
        );
        expect(result, original);
      },
    );

    test(
      'withCurrentTime menggabungkan tanggal pilihan dengan jam saat ini jika tanggal berubah atau baru',
      () {
        final original = DateTime(2026, 11, 5, 14, 20, 30);
        final pickedNewDay = DateTime(2026, 11, 8);
        final clock = DateTime(2026, 11, 10, 9, 15, 45);

        final result = DateHelper.withCurrentTime(
          pickedNewDay,
          original: original,
          now: clock,
        );
        expect(result, DateTime(2026, 11, 8, 9, 15, 45));
      },
    );
  });
}
