import 'package:flutter/material.dart';
import '../../data/transaction_model.dart';
import '../../repositories/contact_repository.dart';
import '../../repositories/transaction_repository.dart';
import '../../theme/app_colors.dart';
import '../../utils/loan_helper.dart';
import '../common/custom_card.dart';

/// Kartu khusus untuk halaman Daftar Pinjaman (hutang & piutang).
class LoanCard extends StatelessWidget {
  final TransactionModel item;
  final String Function(double) formatCurrency;
  final VoidCallback onMarkPaid;

  const LoanCard({
    super.key,
    required this.item,
    required this.formatCurrency,
    required this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    final cat = TransactionRepository.instance.getCategoryById(item.categoryId);
    final bool isDebt = item.type == TransactionType.debt;
    final contact = ContactRepository.instance.getContactById(item.contactId);
    final String name = contact?.name ?? LoanHelper.nameFromTitle(item.title);
    final LoanDueInfo? dueInfo = LoanHelper.describe(item);
    final Color statusColor = dueInfo?.color ?? primaryGreen;

    return CustomCard(
      backgroundColor: cardBg,
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                      item.notes.isNotEmpty
                          ? '${cat.name} • ${item.notes}'
                          : cat.name,
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
              const SizedBox(width: 8),
              Text(
                formatCurrency(item.amount),
                style: const TextStyle(
                  color: primaryGreen,
                  fontSize: 14,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
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
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: onMarkPaid,
                icon: Icon(
                  isDebt ? Icons.payments_outlined : Icons.price_check,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  isDebt ? 'Bayar & Tandai Lunas' : 'Terima & Tandai Lunas',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
