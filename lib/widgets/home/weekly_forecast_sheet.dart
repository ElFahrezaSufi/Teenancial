import 'package:material_ui/material_ui.dart';
import '../../data/feen_catalog.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/weekly_balance_forecaster.dart';
import '../feen/feen_avatar.dart';

/// Bottom sheet rincian perhitungan Perkiraan Saldo Minggu Depan di Beranda.
class WeeklyForecastSheet extends StatelessWidget {
  final WeeklyBalanceForecast forecast;
  final int userLevel;
  final Map<String, String> feenEquipped;
  final VoidCallback onAskFeen;

  const WeeklyForecastSheet({
    super.key,
    required this.forecast,
    required this.userLevel,
    required this.feenEquipped,
    required this.onAskFeen,
  });

  @override
  Widget build(BuildContext context) {
    final bool isProjectedNegative = forecast.projectedBalance < 0;
    final double netChange = forecast.netChange;
    final String netChangeLabel = netChange > 0
        ? '+${Formatters.rupiah(netChange)}'
        : (netChange < 0
            ? '-${Formatters.rupiah(netChange.abs())}'
            : 'Stabil (Rp 0)');
    final Color netColor = netChange > 0
        ? primaryGreen
        : (netChange < 0 ? const Color(0xFFC62828) : primaryGreen);

    return Container(
      margin: const EdgeInsets.only(top: 2),
      decoration: const BoxDecoration(
        color: primaryGreen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 1.5, left: 1.5, right: 1.5),
        child: Container(
          decoration: const BoxDecoration(
            color: appBarBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.5)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: primaryGreen.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      FeenAvatar(
                        level: userLevel,
                        pose: isProjectedNegative
                            ? FeenPose.alert
                            : FeenPose.normal,
                        equipped: feenEquipped,
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Perkiraan Minggu Depan',
                              style: TextStyle(
                                color: primaryGreen,
                                fontSize: 17,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Proyeksi 7 hari ke depan dari data nyatamu',
                              style: TextStyle(
                                color: primaryGreen.withValues(alpha: 0.75),
                                fontSize: 12,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryGreen, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimasi Saldo 7 Hari Lagi',
                          style: TextStyle(
                            color: primaryGreen.withValues(alpha: 0.78),
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  Formatters.rupiah(forecast.projectedBalance),
                                  style: TextStyle(
                                    color: isProjectedNegative
                                        ? const Color(0xFFC62828)
                                        : primaryGreen,
                                    fontSize: 22,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: netColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                netChangeLabel,
                                style: TextStyle(
                                  color: netColor,
                                  fontSize: 11,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ForecastBreakdownRow(
                    label: 'Saldo saat ini',
                    subtitle: 'Total seluruh dompet aktif',
                    valueText: Formatters.rupiah(forecast.currentBalance),
                    valueColor: primaryGreen,
                  ),
                  const Divider(height: 18),
                  _ForecastBreakdownRow(
                    label: 'Jadwal rutin 7 hari ke depan',
                    subtitle: forecast.scheduledRecurringCount > 0
                        ? '${forecast.scheduledRecurringCount} jadwal transaksi berulang aktif'
                        : 'Belum ada jadwal berulang dalam 7 hari',
                    valueText: forecast.scheduledNet > 0
                        ? '+${Formatters.rupiah(forecast.scheduledNet)}'
                        : (forecast.scheduledNet < 0
                            ? '-${Formatters.rupiah(forecast.scheduledNet.abs())}'
                            : 'Rp 0'),
                    valueColor: forecast.scheduledNet < 0
                        ? const Color(0xFFC62828)
                        : primaryGreen,
                  ),
                  const Divider(height: 18),
                  _ForecastBreakdownRow(
                    label: 'Estimasi pengeluaran harian (7 hari)',
                    subtitle: forecast.estimatedDailyExpense > 0
                        ? 'Rata-rata ${Formatters.rupiah(forecast.estimatedDailyExpense)}/hari (${forecast.lookbackDays} hari terakhir)'
                        : 'Belum ada riwayat pengeluaran non-rutin',
                    valueText: forecast.estimatedWeeklyNonRecurringExpense > 0
                        ? '-${Formatters.rupiah(forecast.estimatedWeeklyNonRecurringExpense)}'
                        : 'Rp 0',
                    valueColor: forecast.estimatedWeeklyNonRecurringExpense > 0
                        ? const Color(0xFFC62828)
                        : primaryGreen,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Perhitungan ini bersifat proyeksi lokal berdasarkan jadwal berulang aktif dan kebiasaan pengeluaran 30 hari terakhir (tidak termasuk transfer antar-dompet dan hutang/piutang).',
                    style: TextStyle(
                      color: primaryGreen.withValues(alpha: 0.68),
                      fontSize: 11,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onAskFeen();
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                    label: const Text(
                      'Tanya Feen soal proyeksi ini',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ForecastBreakdownRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final String valueText;
  final Color valueColor;

  const _ForecastBreakdownRow({
    required this.label,
    required this.subtitle,
    required this.valueText,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: primaryGreen,
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: primaryGreen.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          valueText,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
