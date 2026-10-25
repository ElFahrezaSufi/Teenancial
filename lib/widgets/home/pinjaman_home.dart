import 'package:flutter/material.dart';
import '../../data/transaction_model.dart';
import '../../repositories/transaction_repository.dart';
import '../../theme/app_colors.dart';
import '../../utils/loan_helper.dart';
import '../common/custom_card.dart';

/// Ringkasan hutang & piutang untuk halaman Home.
/// Ketuk kartu untuk membuka halaman Daftar Pinjaman.
class PinjamanHome extends StatelessWidget {
  final String Function(double) formatRupiah;
  final VoidCallback onTap;

  const PinjamanHome({
    super.key,
    required this.formatRupiah,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final repo = TransactionRepository.instance;
    final unpaidDebts = repo.debts.where((t) => !t.isPaid).toList();
    final unpaidReceivables = repo.receivables.where((t) => !t.isPaid).toList();

    final double totalDebt = unpaidDebts.fold(0.0, (s, t) => s + t.amount);
    final double totalReceivable =
        unpaidReceivables.fold(0.0, (s, t) => s + t.amount);

    final List<TransactionModel> allUnpaid = [
      ...unpaidDebts,
      ...unpaidReceivables,
    ];
    final int overdueCount = allUnpaid
        .where((t) => t.dueDate != null && LoanHelper.daysUntilDue(t.dueDate!) < 0)
        .length;
    final int soonCount = allUnpaid.where((t) {
      if (t.dueDate == null) return false;
      final d = LoanHelper.daysUntilDue(t.dueDate!);
      return d >= 0 && d <= 3;
    }).length;

    String? alertText;
    Color alertColor = primaryGreen;
    if (overdueCount > 0) {
      alertText = '$overdueCount pinjaman melewati batas waktu';
      alertColor = LoanHelper.overdueColor;
    } else if (soonCount > 0) {
      alertText = '$soonCount pinjaman jatuh tempo dalam 3 hari';
      alertColor = orangeText;
    }

    return GestureDetector(
      onTap: onTap,
      child: CustomCard(
        backgroundColor: cardBg,
        borderRadius: 20,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryColumn(
                    label: 'Hutang Saya',
                    value: formatRupiah(totalDebt),
                    count: unpaidDebts.length,
                  ),
                ),
                Container(
                  width: 1.5,
                  height: 44,
                  color: primaryGreen.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: _SummaryColumn(
                    label: 'Piutang Saya',
                    value: formatRupiah(totalReceivable),
                    count: unpaidReceivables.length,
                  ),
                ),
              ],
            ),
            if (alertText != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: alertColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      alertText,
                      style: TextStyle(
                        color: alertColor,
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: alertColor),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Lihat detail & jatuh tempo',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 12,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 18, color: primaryGreen),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  final String label;
  final String value;
  final int count;

  const _SummaryColumn({
    required this.label,
    required this.value,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: primaryGreen,
            fontSize: 12,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: primaryGreen,
              fontSize: 16,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$count belum lunas',
          style: TextStyle(
            color: primaryGreen.withValues(alpha: 0.7),
            fontSize: 11,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
