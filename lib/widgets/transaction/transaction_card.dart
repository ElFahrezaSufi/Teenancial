import 'package:flutter/material.dart';
import '../../data/transaction_model.dart';
import '../../repositories/transaction_repository.dart';
import '../../theme/app_colors.dart';
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
    final bool isExpense = item.type == TransactionType.expense;

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
