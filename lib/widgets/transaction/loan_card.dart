import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/category_catalog.dart';
import '../../models/transaction_model.dart';
import '../../providers/contact_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/loan_helper.dart';
import '../common/custom_card.dart';

/// Kartu khusus untuk halaman Daftar Pinjaman (hutang & piutang).
class LoanCard extends StatelessWidget {
  final TransactionModel item;
  final String Function(double) formatCurrency;
  final VoidCallback onMarkPaid;
  final VoidCallback? onPayInstallment;
  final VoidCallback? onShowHistory;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const LoanCard({
    super.key,
    required this.item,
    required this.formatCurrency,
    required this.onMarkPaid,
    this.onPayInstallment,
    this.onShowHistory,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cat = CategoryCatalog.getById(
      item.categoryId,
      fallbackType: item.type,
    );
    final bool isDebt = item.type == TransactionType.debt;
    final contact =
        context.watch<ContactProvider>().getContactById(item.contactId);
    final String name = LoanHelper.counterpartyName(
      item,
      contactName: contact?.name,
    );
    final LoanDueInfo? dueInfo = LoanHelper.describe(item);
    final Color statusColor = dueInfo?.color ?? primaryGreen;

    final double paidAmount = item.paidAmount;
    final double remainingAmount = item.remainingAmount;
    final bool hasPartialPayment = paidAmount > 0 && !item.isPaid;
    final double progress = item.amount > 0
        ? (paidAmount / item.amount).clamp(0.0, 1.0)
        : 0.0;
    final bool hasHistory =
        onShowHistory != null && (item.payments.isNotEmpty || item.isPaid);
    final bool canShowMenu =
        (onEdit != null && !item.isPaid) || hasHistory || onDelete != null;

    return CustomCard(
      backgroundColor: cardBg,
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: lightGreen.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(cat.icon, color: primaryGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: primaryGreen,
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cat.name,
                      style: TextStyle(
                        color: primaryGreen.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.notes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.notes,
                        style: TextStyle(
                          color: primaryGreen.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(
                      hasPartialPayment ? remainingAmount : item.amount,
                    ),
                    style: const TextStyle(
                      color: primaryGreen,
                      fontSize: 14,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (hasPartialPayment)
                    Text(
                      'dari ${formatCurrency(item.amount)}',
                      style: TextStyle(
                        color: primaryGreen.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              if (canShowMenu) ...[
                const SizedBox(width: 2),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.more_vert,
                      color: primaryGreen,
                      size: 20,
                    ),
                    color: appBarBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit?.call();
                      } else if (value == 'history') {
                        onShowHistory?.call();
                      } else if (value == 'delete') {
                        onDelete?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      if (onEdit != null && !item.isPaid)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, color: primaryGreen),
                              SizedBox(width: 8),
                              Text(
                                'Edit Pinjaman',
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (hasHistory)
                        PopupMenuItem(
                          value: 'history',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.history_rounded,
                                color: primaryGreen,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.payments.isNotEmpty
                                    ? 'Riwayat Cicilan (${item.payments.length})'
                                    : 'Detail Pelunasan',
                                style: const TextStyle(
                                  color: primaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Hapus Pinjaman',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (hasPartialPayment) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Terbayar ${formatCurrency(paidAmount)}',
                  style: TextStyle(
                    color: primaryGreen.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Sisa ${formatCurrency(remainingAmount)}',
                  style: const TextStyle(
                    color: primaryGreen,
                    fontSize: 11,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: lightGreen,
                color: primaryGreen,
                minHeight: 6,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.event, size: 14, color: statusColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.dueDate != null
                      ? LoanHelper.formatDueDate(item.dueDate!)
                      : 'Tanpa batas waktu',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.payments.isNotEmpty && onShowHistory != null) ...[
                GestureDetector(
                  onTap: onShowHistory,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 12,
                          color: primaryGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item.payments.length}x cicilan',
                          style: const TextStyle(
                            color: primaryGreen,
                            fontSize: 11,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (dueInfo != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    dueInfo.label,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (!item.isPaid) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onPayInstallment != null) ...[
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: OutlinedButton.icon(
                        onPressed: onPayInstallment,
                        icon: const Icon(
                          Icons.add_card_outlined,
                          size: 16,
                          color: primaryGreen,
                        ),
                        label: Text(
                          isDebt ? 'Bayar Cicilan' : 'Terima Cicilan',
                          style: const TextStyle(
                            color: primaryGreen,
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side:
                              const BorderSide(color: primaryGreen, width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: onMarkPaid,
                      icon: Icon(
                        isDebt ? Icons.payments_outlined : Icons.price_check,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        hasPartialPayment
                            ? 'Lunasi Sisa'
                            : (isDebt ? 'Bayar Lunas' : 'Terima Lunas'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
