import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dompet_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/contact_provider.dart';
import '../../providers/dompet_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/confirm_dialog.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_helper.dart';
import '../../utils/error_mapper.dart';
import '../../utils/loan_helper.dart';

/// Bottom sheet untuk menampilkan riwayat cicilan suatu pinjaman sekaligus
/// menyediakan tombol pembatalan per cicilan.
class LoanPaymentHistorySheet extends StatefulWidget {
  final String loanId;

  const LoanPaymentHistorySheet({
    super.key,
    required this.loanId,
  });

  static Future<void> show(BuildContext context, String loanId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LoanPaymentHistorySheet(loanId: loanId),
    );
  }

  @override
  State<LoanPaymentHistorySheet> createState() =>
      _LoanPaymentHistorySheetState();
}

class _LoanPaymentHistorySheetState extends State<LoanPaymentHistorySheet> {
  String? _removingPaymentId;

  String _walletName(List<DompetItem> dompets, String dompetId) {
    for (final d in dompets) {
      if (d.id == dompetId) return d.nama;
    }
    return 'Dompet terhapus';
  }

  Future<void> _confirmRemovePayment(
    TransactionModel loan,
    LoanPayment payment,
    String walletName,
  ) async {
    if (_removingPaymentId != null) return;

    final isDebt = loan.type == TransactionType.debt;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Batalkan Cicilan?',
      message: isDebt
          ? 'Cicilan ${Formatters.rupiah(payment.amount)} pada ${DateHelper.formatShort(payment.date)} akan dihapus dan saldo catatan di "$walletName" dikembalikan.'
          : 'Penerimaan cicilan ${Formatters.rupiah(payment.amount)} pada ${DateHelper.formatShort(payment.date)} akan dibatalkan dan mengurangi saldo catatan di "$walletName".',
      confirmLabel: 'Batalkan Cicilan',
      confirmColor: Colors.redAccent,
    );

    if (!confirmed || !mounted) return;

    setState(() => _removingPaymentId = payment.id);
    try {
      await context
          .read<TransactionProvider>()
          .removeLoanPayment(loan.id, payment.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cicilan berhasil dibatalkan'),
            backgroundColor: primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${ErrorMapper.message(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _removingPaymentId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final dompets = context.watch<DompetProvider>().items;
    final matches =
        txProvider.transactions.where((t) => t.id == widget.loanId);

    if (matches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Data pinjaman tidak ditemukan.',
          style: TextStyle(color: primaryGreen, fontWeight: FontWeight.w600),
        ),
      );
    }

    final loan = matches.first;
    final contact =
        context.watch<ContactProvider>().getContactById(loan.contactId);
    final counterparty = LoanHelper.counterpartyName(
      loan,
      contactName: contact?.name,
    );
    final payments = loan.payments;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: primaryGreen.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Riwayat Cicilan',
                  style: TextStyle(
                    color: primaryGreen,
                    fontSize: 18,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${Formatters.rupiah(loan.paidAmount)} / ${Formatters.rupiah(loan.amount)}',
                  style: const TextStyle(
                    color: primaryGreen,
                    fontSize: 13,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    counterparty,
                    style: TextStyle(
                      color: primaryGreen.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  loan.isPaid
                      ? 'Status: Lunas'
                      : 'Sisa: ${Formatters.rupiah(loan.remainingAmount)}',
                  style: TextStyle(
                    color: loan.isPaid ? primaryGreen : orangeText,
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (payments.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: primaryGreen.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  loan.isPaid
                      ? 'Pinjaman ini dilunasi langsung sebesar ${Formatters.rupiah(loan.amount)} melalui dompet "${_walletName(dompets, loan.paidDompetId ?? loan.dompetId)}".'
                      : 'Belum ada cicilan yang tercatat untuk pinjaman ini.',
                  style: const TextStyle(
                    color: primaryGreen,
                    fontSize: 13,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: payments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final p = payments[index];
                    final wName = _walletName(dompets, p.dompetId);
                    final isRemoving = _removingPaymentId == p.id;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: primaryGreen.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateHelper.formatLong(p.date),
                                style: const TextStyle(
                                  color: primaryGreen,
                                  fontSize: 13,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                Formatters.rupiah(p.amount),
                                style: const TextStyle(
                                  color: primaryGreen,
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet_outlined,
                                      size: 14,
                                      color:
                                          primaryGreen.withValues(alpha: 0.75),
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        wName,
                                        style: TextStyle(
                                          color: primaryGreen
                                              .withValues(alpha: 0.8),
                                          fontSize: 12,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: isRemoving
                                    ? null
                                    : () => _confirmRemovePayment(
                                          loan,
                                          p,
                                          wName,
                                        ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.undo_rounded,
                                      size: 14,
                                      color: isRemoving
                                          ? Colors.grey
                                          : Colors.redAccent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isRemoving
                                          ? 'Membatalkan...'
                                          : 'Batalkan',
                                      style: TextStyle(
                                        color: isRemoving
                                            ? Colors.grey
                                            : Colors.redAccent,
                                        fontSize: 12,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (p.note != null && p.note!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              p.note!,
                              style: TextStyle(
                                color: primaryGreen.withValues(alpha: 0.75),
                                fontSize: 12,
                                fontFamily: 'Inter',
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
