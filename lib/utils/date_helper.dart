import 'package:intl/intl.dart';

/// Kumpulan fungsi bantu murni untuk manipulasi dan pemformatan tanggal.
class DateHelper {
  DateHelper._();

  /// Mengembalikan objek [DateTime] hanya dengan komponen tahun, bulan, dan hari.
  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Menghitung selisih hari kalender dari [from] ke [to] (`to - from`),
  /// mengabaikan komponen jam serta potensi pergeseran zona waktu.
  static int daysBetween(DateTime from, DateTime to) {
    final fromUtc = DateTime.utc(from.year, from.month, from.day);
    final toUtc = DateTime.utc(to.year, to.month, to.day);
    return toUtc.difference(fromUtc).inDays;
  }

  /// Menggabungkan tanggal pilihan [picked] dengan komponen waktu:
  /// - Jika [original] diberikan dan jatuh pada hari kalender yang sama dengan
  ///   [picked], kembalikan [original] apa adanya agar urutan transaksi di hari
  ///   tersebut tidak berubah saat diedit.
  /// - Selain itu, gunakan jam/menit/detik dari [now] (default `DateTime.now()`).
  static DateTime withCurrentTime(
    DateTime picked, {
    DateTime? original,
    DateTime? now,
  }) {
    if (original != null && dateOnly(picked) == dateOnly(original)) {
      return original;
    }
    final clock = now ?? DateTime.now();
    return DateTime(
      picked.year,
      picked.month,
      picked.day,
      clock.hour,
      clock.minute,
      clock.second,
      clock.millisecond,
      clock.microsecond,
    );
  }

  /// Mengembalikan awal hari (`00:00:00`) untuk batas bawah filter periode Riwayat:
  /// - `0` (Mingguan): hari ini + 6 hari kalender sebelumnya (total 7 hari)
  /// - `1` (Bulanan): hari ini + 29 hari kalender sebelumnya (total 30 hari)
  /// - `2` (Tahunan): hari ini + 364 hari kalender sebelumnya (total 365 hari)
  static DateTime periodStartForFilter(int filterIndex, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    if (filterIndex == 0) {
      return today.subtract(const Duration(days: 6));
    } else if (filterIndex == 1) {
      return today.subtract(const Duration(days: 29));
    }
    return today.subtract(const Duration(days: 364));
  }

  /// Format tanggal panjang Bahasa Indonesia (mis. `31 Desember 2026`).
  static String formatLong(DateTime date) {
    return _formatSafe('dd MMMM yyyy', date);
  }

  /// Format tanggal ringkas Bahasa Indonesia (mis. `31 Des 2026`).
  static String formatShort(DateTime date) {
    return _formatSafe('dd MMM yyyy', date);
  }

  static String _formatSafe(String pattern, DateTime date) {
    try {
      return DateFormat(pattern, 'id_ID').format(date);
    } catch (_) {
      return DateFormat(pattern).format(date);
    }
  }
}
