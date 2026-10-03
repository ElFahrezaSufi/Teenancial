import 'package:flutter/material.dart';
import '../../data/transaction_model.dart';
import 'transaction_card.dart';

class TransactionGroupData {
  final String dateLabel;
  final List<TransactionModel> items;

  const TransactionGroupData({required this.dateLabel, required this.items});
}

class TransactionGroupList extends StatelessWidget {
  final TransactionGroupData group;
  final String Function(double) formatCurrency;
  final Function(TransactionModel) onEdit;
  final Function(String) onDelete;

  const TransactionGroupList({
    super.key,
    required this.group,
    required this.formatCurrency,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const Color orangeText = Color(0xFFE18151);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.dateLabel,
          style: const TextStyle(
            color: orangeText,
            fontSize: 13,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...group.items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TransactionCard(
              item: item,
              formatCurrency: formatCurrency,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
