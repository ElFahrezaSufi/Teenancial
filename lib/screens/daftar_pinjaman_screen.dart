import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction_model.dart';
import '../providers/dompet_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_colors.dart';
import '../utils/confirm_dialog.dart';
import '../utils/currency_formatter.dart';
import '../utils/error_mapper.dart';
import '../widgets/common/async_state_view.dart';
import '../widgets/common/custom_filter_chip.dart';
import '../widgets/transaction/loan_card.dart';
import '../widgets/transaction/loan_payment_dialog.dart';
import '../widgets/transaction/loan_payment_history_sheet.dart';
import '../widgets/transaction/transaction_scaffold.dart';

enum _LoanFilter { all, unpaid, paid }

class DaftarPinjamanScreen extends StatefulWidget {
  const DaftarPinjamanScreen({super.key});

  @override
  State<DaftarPinjamanScreen> createState() => _DaftarPinjamanScreenState();
}

class _DaftarPinjamanScreenState extends State<DaftarPinjamanScreen> {
  int _selectedTab = 0; // 0 = Hutang Saya, 1 = Piutang Saya
  _LoanFilter _filter = _LoanFilter.unpaid;
  bool _isProcessing = false;

  List<TransactionModel> _visibleLoans(TransactionProvider txProvider) {
    final source =
        _selectedTab == 0 ? txProvider.debts : txProvider.receivables;

    final filtered = source.where((t) {
      switch (_filter) {
        case _LoanFilter.all:
          return true;
        case _LoanFilter.unpaid:
          return !t.isPaid;
        case _LoanFilter.paid:
          return t.isPaid;
      }
    }).toList();

    filtered.sort((a, b) {
      if (a.isPaid != b.isPaid) return a.isPaid ? 1 : -1;
      if (!a.isPaid) {
        if (a.dueDate == null && b.dueDate == null) {
          return b.date.compareTo(a.date);
        }
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      }
      return b.date.compareTo(a.date);
    });
    return filtered;
  }

  double _totalOutstanding(TransactionProvider txProvider) {
    final source =
        _selectedTab == 0 ? txProvider.debts : txProvider.receivables;
    return source
        .where((t) => !t.isPaid)
        .fold(0.0, (sum, t) => sum + t.remainingAmount);
  }

  Future<void> _recordPayment(
    TransactionModel item, {
    required bool settleFull,
  }) async {
    if (_isProcessing) return;

    final LoanPayment? payment = await showDialog<LoanPayment>(
      context: context,
      builder: (_) => LoanPaymentDialog(
        item: item,
        settleFull: settleFull,
      ),
    );
    if (payment == null || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await context.read<TransactionProvider>().addLoanPayment(
            item.id,
            payment,
          );
      if (mounted) {
        final bool nowFullyPaid =
            payment.amount + 0.0001 >= item.remainingAmount;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nowFullyPaid
                  ? (item.type == TransactionType.debt
                      ? '✅ Hutang berhasil dilunasi!'
                      : '✅ Piutang berhasil dilunasi!')
                  : '✅ Cicilan ${Formatters.rupiah(payment.amount)} berhasil dicatat!',
            ),
            backgroundColor: primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMapper.message(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showPaymentHistory(TransactionModel item) async {
    await LoanPaymentHistorySheet.show(context, item.id);
  }

  Future<void> _deleteLoan(TransactionModel item) async {
    if (_isProcessing) return;

    final bool hasPayments = item.payments.isNotEmpty || item.isPaid;
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Hapus Pinjaman?',
      message: hasPayments
          ? 'Menghapus catatan "${item.title}" sebesar ${Formatters.rupiah(item.amount)} juga akan membalik perubahan saldo pokok beserta seluruh cicilannya pada dompet terkait.'
          : 'Menghapus catatan "${item.title}" sebesar ${Formatters.rupiah(item.amount)} juga akan mengembalikan perubahan saldonya pada dompet terkait.',
      confirmColor: Colors.redAccent,
    );

    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await context.read<TransactionProvider>().deleteTransaction(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data pinjaman berhasil dihapus'),
            backgroundColor: primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMapper.message(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildTabButton(int index, String title) {
    final isSelected = _selectedTab == index;
    const Color activeColor = Color(0xFF415121);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.only(top: isSelected ? 0.0 : 4.0),
          decoration: BoxDecoration(
            color:
                isSelected ? activeColor : activeColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(50),
          ),
          padding: EdgeInsets.only(bottom: isSelected ? 6.0 : 2.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color:
                  isSelected ? const Color(0xFFF8FFE8) : Colors.transparent,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: isSelected
                    ? activeColor
                    : activeColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  color: primaryGreen,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(TransactionProvider txProvider) {
    final isDebt = _selectedTab == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGreen, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isDebt ? 'Total sisa hutang' : 'Total sisa piutang',
            style: const TextStyle(
              color: primaryGreen,
              fontSize: 12,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            Formatters.rupiah(_totalOutstanding(txProvider)),
            style: const TextStyle(
              color: primaryGreen,
              fontSize: 16,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final isDebt = _selectedTab == 0;
    String message;
    switch (_filter) {
      case _LoanFilter.unpaid:
        message = isDebt
            ? 'Tidak ada hutang yang belum lunas. Mantap!'
            : 'Tidak ada piutang yang belum lunas.';
        break;
      case _LoanFilter.paid:
        message = 'Belum ada pinjaman yang berstatus lunas.';
        break;
      case _LoanFilter.all:
        message = isDebt
            ? 'Belum ada catatan hutang.'
            : 'Belum ada catatan piutang.';
        break;
    }

    return EmptyStateView(
      icon: Icons.receipt_long_outlined,
      title: 'Daftar kosong',
      subtitle: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    // Watch DompetProvider too so settlement balances stay reactive
    context.watch<DompetProvider>();
    final loans = _visibleLoans(txProvider);

    return TransactionScaffold(
      title: 'Daftar Pinjaman',
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4DFBA),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    _buildTabButton(0, 'Hutang Saya'),
                    const SizedBox(width: 6),
                    _buildTabButton(1, 'Piutang Saya'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildSummary(txProvider),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    CustomFilterChip(
                      label: 'Belum Lunas',
                      selected: _filter == _LoanFilter.unpaid,
                      onTap: () =>
                          setState(() => _filter = _LoanFilter.unpaid),
                    ),
                    const SizedBox(width: 8),
                    CustomFilterChip(
                      label: 'Sudah Lunas',
                      selected: _filter == _LoanFilter.paid,
                      onTap: () => setState(() => _filter = _LoanFilter.paid),
                    ),
                    const SizedBox(width: 8),
                    CustomFilterChip(
                      label: 'Semua',
                      selected: _filter == _LoanFilter.all,
                      onTap: () => setState(() => _filter = _LoanFilter.all),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: txProvider.isLoading && txProvider.transactions.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: primaryGreen),
                      )
                    : loans.isEmpty
                        ? _buildEmpty()
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 32),
                            itemCount: loans.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = loans[index];
                              return LoanCard(
                                key: ValueKey(item.id),
                                item: item,
                                formatCurrency: Formatters.rupiah,
                                onPayInstallment: () => _recordPayment(
                                  item,
                                  settleFull: false,
                                ),
                                onMarkPaid: () => _recordPayment(
                                  item,
                                  settleFull: true,
                                ),
                                onShowHistory: () => _showPaymentHistory(item),
                                onDelete: () => _deleteLoan(item),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
