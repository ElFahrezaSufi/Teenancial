import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/category_catalog.dart';
import '../../models/transaction_model.dart';
import '../../providers/category_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/loan_helper.dart';
import '../common/custom_card.dart';

class TransactionCard extends StatelessWidget {
  final TransactionModel item;
  final String Function(double) formatCurrency;
  final Function(TransactionModel) onEdit;
  final Function(String) onDelete;

  const TransactionCard({
    super.key,
    required this.item,
    required this.formatCurrency,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final catProvider = Provider.of<CategoryProvider?>(context);
    final cat = catProvider != null
        ? catProvider.resolve(item.categoryId, fallbackType: item.type)
        : CategoryCatalog.getById(
            item.categoryId,
            fallbackType: item.type,
          );
    final Color iconBgColor = cat.isCustom
        ? cat.color.withValues(alpha: 0.18)
        : lightGreen.withValues(alpha: 0.4);
    final Color iconFgColor = cat.isCustom ? cat.color : primaryGreen;
    // Piutang & Transfer keluar = uang keluar, Hutang & Pemasukan = uang masuk
    final bool isExpense = item.type == TransactionType.expense ||
        item.type == TransactionType.receivable ||
        (item.type == TransactionType.transfer &&
            item.destinationDompetId == null);
    final bool isInternalTransfer = item.type == TransactionType.transfer &&
        item.destinationDompetId != null;
    final bool isLoan = LoanHelper.isLoan(item);
    final LoanDueInfo? dueInfo = LoanHelper.describe(item);

    final String prefix = isInternalTransfer
        ? ''
        : (isExpense ? '- ' : '+ ');
    final Color amountColor = isInternalTransfer
        ? primaryGreen
        : (isExpense ? Colors.red : primaryGreen);

    final bool canEdit = item.isEditable;

    return CustomCard(
      backgroundColor: cardBg,
      borderRadius: 16,
      padding: const EdgeInsets.only(left: 14, right: 4, top: 12, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(cat.icon, color: iconFgColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.notes.isNotEmpty ? item.notes : cat.name,
                        style: const TextStyle(
                          color: primaryGreen,
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.recurringId != null &&
                        item.recurringId!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: primaryGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.autorenew_rounded,
                              size: 10,
                              color: primaryGreen,
                            ),
                            SizedBox(width: 2.5),
                            Text(
                              'Berulang',
                              style: TextStyle(
                                color: primaryGreen,
                                fontSize: 9.5,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (isLoan) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (item.dueDate != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event,
                              size: 12,
                              color: item.isPaid
                                  ? primaryGreen
                                  : (dueInfo?.color ?? primaryGreen),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              LoanHelper.formatDueDate(item.dueDate!),
                              style: TextStyle(
                                color: item.isPaid
                                    ? primaryGreen
                                    : (dueInfo?.color ?? primaryGreen),
                                fontSize: 11,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      _LoanBadge(
                        label: item.isPaid
                            ? 'Lunas'
                            : (item.paidAmount > 0
                                ? 'Sisa ${formatCurrency(item.remainingAmount)}'
                                : 'Belum Lunas'),
                        color: item.isPaid
                            ? primaryGreen
                            : (dueInfo?.isOverdue == true
                                ? LoanHelper.overdueColor
                                : orangeText),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Text(
            prefix + formatCurrency(item.amount),
            style: TextStyle(
              color: amountColor,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: primaryGreen, size: 20),
            onSelected: (value) {
              if (value == 'edit') {
                onEdit(item);
              } else if (value == 'delete') {
                onDelete(item.id);
              }
            },
            itemBuilder: (context) => [
              if (canEdit)
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, color: primaryGreen),
                      SizedBox(width: 8),
                      Text('Edit', style: TextStyle(color: primaryGreen)),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Hapus', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoanBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _LoanBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
