const _hari = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];
const _bulan = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String formatRupiah(double value) {
  final digits = value.abs().toStringAsFixed(0);
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}Rp $buffer';
}

String formatTanggalPanjang(DateTime d) =>
    '${_hari[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')} '
    '${_bulan[d.month - 1]} ${d.year}';

String formatTanggalPendek(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

double parseNominal(String? text) =>
    double.tryParse((text ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class Validators {
  static const int maxNominal = 1000000000;
  static const int maxNote = 60;
  static const int maxWalletName = 20;

  static String? amount(String? text) {
    if (text == null || text.trim().isEmpty) {
      return 'Jumlah uang tidak boleh kosong';
    }
    final v = parseNominal(text);
    if (v <= 0) return 'Jumlah uang harus lebih dari Rp 0';
    if (v > maxNominal) return 'Jumlah uang maksimal Rp 1.000.000.000';
    return null;
  }

  static String? note(String? text) {
    if (text != null && text.trim().length > maxNote) {
      return 'Catatan maksimal $maxNote karakter';
    }
    return null;
  }

  static String? notEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName tidak boleh kosong';
    }
    return null;
  }

  static String? date(DateTime? value, {DateTime? now}) {
    if (value == null) return 'Tanggal belum dipilih';
    final today = dateOnly(now ?? DateTime.now());
    if (dateOnly(value).isAfter(today)) {
      return 'Tanggal tidak boleh di masa depan';
    }
    return null;
  }

  static String? walletName(String? text) {
    if (text == null || text.trim().isEmpty) {
      return 'Nama dompet tidak boleh kosong';
    }
    if (text.trim().length > maxWalletName) {
      return 'Nama dompet maksimal $maxWalletName karakter';
    }
    return null;
  }
}
