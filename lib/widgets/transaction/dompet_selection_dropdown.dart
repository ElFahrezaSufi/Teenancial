import 'package:material_ui/material_ui.dart';
import '../../models/dompet_model.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../common/custom_dropdown_field.dart';

/// Hasil evaluasi kecukupan saldo dompet terpilih terhadap nominal form.
class WalletBalanceStatus {
  final double walletBalance;
  final double availableBalance;
  final double shortfall;
  final bool isInsufficient;
  final bool isAdvisoryOnly;

  const WalletBalanceStatus({
    required this.walletBalance,
    required this.availableBalance,
    required this.shortfall,
    required this.isInsufficient,
    required this.isAdvisoryOnly,
  });
}

class DompetSelectionDropdown extends StatelessWidget {
  final String label;
  final String hint;
  final List<DompetItem> dompets;
  final String? selectedDompetId;
  final void Function(String?) onChanged;
  final String? Function(String?)? validator;

  /// Menampilkan ringkasan saldo dompet terpilih tepat di bawah dropdown.
  final bool showBalanceInfo;

  /// Mengaktifkan pengecekan kecukupan saldo secara live (khusus transaksi
  /// yang mengurangi saldo dompet seperti Pengeluaran, Transfer, dan Piutang).
  final bool checkSufficiency;

  /// Nominal yang sedang diisi user di form untuk dibandingkan dengan saldo.
  final double? enteredAmount;

  /// Kompensasi nominal lama saat mengedit transaksi keluar pada dompet yang
  /// sama (karena nominal lama akan dikembalikan terlebih dahulu saat update).
  final double editRefundAllowance;

  /// Bila `true` (jadwal berulang masa depan), peringatan kecukupan saldo
  /// ditampilkan secara halus dengan warna oranye (advisory) alih-alih merah.
  final bool isFutureSchedule;

  const DompetSelectionDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.dompets,
    this.selectedDompetId,
    required this.onChanged,
    this.validator,
    this.showBalanceInfo = false,
    this.checkSufficiency = false,
    this.enteredAmount,
    this.editRefundAllowance = 0.0,
    this.isFutureSchedule = false,
  });

  /// Mengurai teks input mata uang (mis. `"Rp 75.000"`) menjadi angka nominal.
  static double? parseAmount(String rawText) {
    final digits = rawText.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    final parsed = double.tryParse(digits);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  /// Fungsi murni untuk menghitung kecukupan saldo dompet terhadap nominal.
  static WalletBalanceStatus evaluateWalletBalance({
    required double walletBalance,
    double? enteredAmount,
    bool checkSufficiency = false,
    double editRefundAllowance = 0.0,
    bool isFutureSchedule = false,
  }) {
    final double allowance =
        editRefundAllowance > 0 ? editRefundAllowance : 0.0;
    final double availableBalance = walletBalance + allowance;
    final double amount =
        (enteredAmount != null && enteredAmount > 0) ? enteredAmount : 0.0;
    final double rawShortfall = amount - availableBalance;
    final bool isInsufficient =
        checkSufficiency && amount > 0 && rawShortfall > 0.0001;
    final double shortfall = isInsufficient ? rawShortfall : 0.0;

    return WalletBalanceStatus(
      walletBalance: walletBalance,
      availableBalance: availableBalance,
      shortfall: shortfall,
      isInsufficient: isInsufficient,
      isAdvisoryOnly: isInsufficient && isFutureSchedule,
    );
  }

  DompetItem? _findSelectedDompet() {
    if (selectedDompetId == null) return null;
    for (final d in dompets) {
      if (d.id == selectedDompetId) return d;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, String> displayMap = {};
    final Set<String> usedLabels = {};

    for (final dompet in dompets) {
      final String baseDisplay = '${dompet.nama} (${dompet.jenis.label})';
      String display = baseDisplay;
      int suffix = 2;
      while (usedLabels.contains(display)) {
        display = '$baseDisplay #$suffix';
        suffix++;
      }
      usedLabels.add(display);
      displayMap[dompet.id] = display;
    }

    final items = displayMap.values.toList();
    final value =
        selectedDompetId != null ? displayMap[selectedDompetId] : null;
    final selectedDompet = _findSelectedDompet();
    final bool renderFooter = showBalanceInfo && selectedDompet != null;

    final dropdown = CustomDropdownField(
      label: label,
      hint: hint,
      value: value,
      items: items,
      bottomPadding: renderFooter ? 6.0 : 16.0,
      onChanged: (String? newValue) {
        if (newValue != null) {
          final entry =
              displayMap.entries.firstWhere((e) => e.value == newValue);
          onChanged(entry.key);
        } else {
          onChanged(null);
        }
      },
      validator: (String? val) {
        if (validator != null) {
          return validator!(val);
        }
        if (val == null || val.isEmpty) {
          return 'Pilih sumber dana';
        }
        return null;
      },
    );

    if (!renderFooter) {
      return dropdown;
    }

    final status = evaluateWalletBalance(
      walletBalance: selectedDompet.jumlah,
      enteredAmount: enteredAmount,
      checkSufficiency: checkSufficiency,
      editRefundAllowance: editRefundAllowance,
      isFutureSchedule: isFutureSchedule,
    );

    final Color accentColor = !status.isInsufficient
        ? primaryGreen
        : (status.isAdvisoryOnly ? orangeText : Colors.red);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        dropdown,
        Padding(
          key: const Key('dompet_balance_info'),
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 14,
                    color: accentColor.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Saldo tersedia',
                      style: TextStyle(
                        color: status.isInsufficient
                            ? accentColor
                            : primaryGreen.withValues(alpha: 0.78),
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    Formatters.rupiah(selectedDompet.jumlah),
                    key: const Key('dompet_balance_amount'),
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12.5,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (checkSufficiency && editRefundAllowance > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    'Termasuk nominal transaksi ini: ${Formatters.rupiah(status.availableBalance)}',
                    key: const Key('dompet_edit_allowance_note'),
                    style: TextStyle(
                      color: primaryGreen.withValues(alpha: 0.72),
                      fontSize: 11.5,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              if (status.isInsufficient)
                Padding(
                  key: const Key('dompet_balance_warning'),
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(
                          status.isAdvisoryOnly
                              ? Icons.info_outline_rounded
                              : Icons.warning_amber_rounded,
                          size: 14,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          status.isAdvisoryOnly
                              ? 'Saldo saat ini belum cukup. Pastikan saldo cukup saat jadwal berjalan.'
                              : 'Saldo tidak mencukupi (kurang ${Formatters.rupiah(status.shortfall)})',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
