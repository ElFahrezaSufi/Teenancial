import 'package:flutter/material.dart';
import '../../data/transaction_model.dart';
import '../../repositories/transaction_repository.dart';
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
    final cat = TransactionRepository.instance.getCategoryById(item.categoryId);
    // Piutang = uang keluar (dipinjamkan), Hutang = uang masuk (dipinjam)
    final bool isExpense = item.type == TransactionType.expense ||
        item.type == TransactionType.receivable;
    final bool isLoan = LoanHelper.isLoan(item);
    final LoanDueInfo? dueInfo = LoanHelper.describe(item);

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
                Text(
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
                        label: item.isPaid ? 'Lunas' : 'Belum Lunas',
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
            (isExpense ? '- ' : '+ ') + formatCurrency(item.amount),
            style: TextStyle(
              color: isExpense ? Colors.red : primaryGreen,
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
