import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/dompet_model.dart';
import '../models/transaction_model.dart';
import '../repositories/dompet_repository.dart';
import '../repositories/transaction_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/common/custom_filter_chip.dart';
import '../widgets/transaction/dompet_selection_dropdown.dart';
import '../widgets/transaction/loan_card.dart';
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

  String _formatCurrency(double value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }

  List<TransactionModel> _visibleLoans() {
    final repo = TransactionRepository.instance;
    final source = _selectedTab == 0 ? repo.debts : repo.receivables;

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

    // Belum lunas dulu (tenggat terdekat di atas), lalu yang sudah lunas.
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

  double _totalOutstanding() {
    final repo = TransactionRepository.instance;
    final source = _selectedTab == 0 ? repo.debts : repo.receivables;
    return source.where((t) => !t.isPaid).fold(0.0, (sum, t) => sum + t.amount);
  }

  Future<void> _markAsPaid(TransactionModel item) async {
    if (_isProcessing) return;

    final String? dompetId = await showDialog<String>(
      context: context,
      builder: (_) => _SettleDialog(
        item: item,
        formatCurrency: _formatCurrency,
      ),
    );
    if (dompetId == null || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await TransactionRepository.instance.markAsPaid(item.id, dompetId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(item.type == TransactionType.debt
                ? '✅ Hutang berhasil dilunasi!'
                : '✅ Piutang berhasil dilunasi!'),
            backgroundColor: primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
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
            color: isSelected ? activeColor : activeColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(50),
          ),
          padding: EdgeInsets.only(bottom: isSelected ? 6.0 : 2.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF8FFE8) : Colors.transparent,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color:
                    isSelected ? activeColor : activeColor.withValues(alpha: 0.3),
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

  Widget _buildSummary() {
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
            isDebt ? 'Total hutang belum lunas' : 'Total piutang belum lunas',
            style: const TextStyle(
              color: primaryGreen,
              fontSize: 12,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            _formatCurrency(_totalOutstanding()),
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: primaryGreen.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Daftar kosong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TransactionScaffold(
      title: 'Daftar Pinjaman',
      child: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            TransactionRepository.instance,
            DompetRepository.instance,
          ]),
          builder: (context, _) {
            final loans = _visibleLoans();

            return Padding(
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
                  _buildSummary(),
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
                          onTap: () =>
                              setState(() => _filter = _LoanFilter.paid),
                        ),
                        const SizedBox(width: 8),
                        CustomFilterChip(
                          label: 'Semua',
                          selected: _filter == _LoanFilter.all,
                          onTap: () =>
                              setState(() => _filter = _LoanFilter.all),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: loans.isEmpty
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
                                formatCurrency: _formatCurrency,
                                onMarkPaid: () => _markAsPaid(item),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Dialog konfirmasi pelunasan: pengguna memilih dompet yang dipakai
/// (uang keluar untuk hutang, uang masuk untuk piutang).
class _SettleDialog extends StatefulWidget {
  final TransactionModel item;
  final String Function(double) formatCurrency;

  const _SettleDialog({required this.item, required this.formatCurrency});

  @override
  State<_SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends State<_SettleDialog> {
  late final List<DompetItem> _dompets;
  String? _selectedDompetId;

  @override
  void initState() {
    super.initState();
    _dompets = DompetRepository.instance.currentDompets;
    // Default: dompet asal saat pinjaman dibuat (jika masih ada), bisa diganti.
    final hasOriginal = _dompets.any((d) => d.id == widget.item.dompetId);
    _selectedDompetId = hasOriginal
        ? widget.item.dompetId
        : (_dompets.isNotEmpty ? _dompets.first.id : null);
  }

  @override
  Widget build(BuildContext context) {
    final isDebt = widget.item.type == TransactionType.debt;
    final selected = _dompets.where((d) => d.id == _selectedDompetId);
    final DompetItem? selectedDompet = selected.isNotEmpty ? selected.first : null;
    final bool insufficient = isDebt &&
        selectedDompet != null &&
        selectedDompet.jumlah < widget.item.amount;

    return AlertDialog(
      backgroundColor: scaffoldBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      title: Text(
        isDebt ? 'Bayar Hutang' : 'Terima Pelunasan',
        style: const TextStyle(
          color: primaryGreen,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDebt
                  ? 'Kamu akan melunasi ${widget.formatCurrency(widget.item.amount)}. Uang keluar dari dompet mana?'
                  : 'Kamu menerima pelunasan ${widget.formatCurrency(widget.item.amount)}. Uang masuk ke dompet mana?',
              style: const TextStyle(color: primaryGreen, fontSize: 13),
            ),
            const SizedBox(height: 16),
            DompetSelectionDropdown(
              label: isDebt ? 'Bayar dari' : 'Masuk ke',
              hint: 'Pilih dompet',
              dompets: _dompets,
              selectedDompetId: _selectedDompetId,
              onChanged: (val) => setState(() => _selectedDompetId = val),
            ),
            if (selectedDompet != null)
              Text(
                'Saldo dompet: ${widget.formatCurrency(selectedDompet.jumlah)}',
                style: TextStyle(
                  color: insufficient ? Colors.red : primaryGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (insufficient)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Saldo tidak mencukupi, pilih dompet lain.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: (_selectedDompetId == null || insufficient)
              ? null
              : () => Navigator.pop(context, _selectedDompetId),
          child: const Text(
            'Konfirmasi',
            style: TextStyle(color: primaryGreen, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
