import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dompet_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/dompet_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_helper.dart';
import '../common/custom_text_field.dart';
import '../common/date_picker_field.dart';
import 'dompet_selection_dropdown.dart';

/// Dialog untuk mencatat pembayaran cicilan (parsial) maupun pelunasan sisa
/// tagihan pada transaksi hutang/piutang.
class LoanPaymentDialog extends StatefulWidget {
  final TransactionModel item;
  final bool settleFull;

  const LoanPaymentDialog({
    super.key,
    required this.item,
    this.settleFull = false,
  });

  @override
  State<LoanPaymentDialog> createState() => _LoanPaymentDialogState();
}

class _LoanPaymentDialogState extends State<LoanPaymentDialog> {
  late final TextEditingController _amountController;
  final TextEditingController _noteController = TextEditingController();
  String? _selectedDompetId;
  DateTime _selectedDate = DateTime.now();
  String? _amountError;

  double get _remaining => widget.item.remainingAmount;
  bool get _isDebt => widget.item.type == TransactionType.debt;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.settleFull
          ? CurrencyInputFormatter.formatValue(_remaining.toStringAsFixed(0))
          : '',
    );

    final dompets = context.read<DompetProvider>().items;
    final hasOriginal = dompets.any((d) => d.id == widget.item.dompetId);
    _selectedDompetId = hasOriginal
        ? widget.item.dompetId
        : (dompets.isNotEmpty ? dompets.first.id : null);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double _parsedAmount() {
    if (widget.settleFull) return _remaining;
    final raw = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(raw) ?? 0.0;
  }

  void _fillRemaining() {
    setState(() {
      _amountController.text = CurrencyInputFormatter.formatValue(
        _remaining.toStringAsFixed(0),
      );
      _amountError = null;
    });
  }

  void _submit(DompetItem? selectedDompet) {
    FocusScope.of(context).unfocus();
    final amount = _parsedAmount();

    if (amount <= 0) {
      setState(() => _amountError = 'Masukkan nominal lebih dari Rp 0');
      return;
    }
    if (amount > _remaining + 0.0001) {
      setState(
        () => _amountError =
            'Nominal melebihi sisa tagihan (${Formatters.rupiah(_remaining)})',
      );
      return;
    }
    if (_selectedDompetId == null || selectedDompet == null) {
      return;
    }
    if (_isDebt && selectedDompet.jumlah + 0.0001 < amount) {
      return;
    }

    final payment = LoanPayment(
      id: 'pay_${DateTime.now().microsecondsSinceEpoch}',
      amount: amount > _remaining ? _remaining : amount,
      date: DateHelper.withCurrentTime(_selectedDate),
      dompetId: _selectedDompetId!,
      note: _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
    );

    Navigator.of(context).pop(payment);
  }

  @override
  Widget build(BuildContext context) {
    final dompets = context.watch<DompetProvider>().items;
    final selected = dompets.where((d) => d.id == _selectedDompetId);
    final DompetItem? selectedDompet =
        selected.isNotEmpty ? selected.first : null;
    final double currentAmount = _parsedAmount();
    final bool insufficient = _isDebt &&
        selectedDompet != null &&
        currentAmount > 0 &&
        selectedDompet.jumlah + 0.0001 < currentAmount;

    final String dialogTitle = widget.settleFull
        ? (_isDebt ? 'Lunasi Sisa Hutang' : 'Terima Pelunasan Piutang')
        : (_isDebt ? 'Bayar Cicilan Hutang' : 'Terima Cicilan Piutang');

    return AlertDialog(
      backgroundColor: scaffoldBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      title: Text(
        dialogTitle,
        style: const TextStyle(
          color: primaryGreen,
          fontSize: 17,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primaryGreen.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sisa Tagihan',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 12,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    Formatters.rupiah(_remaining),
                    style: const TextStyle(
                      color: primaryGreen,
                      fontSize: 14,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (!widget.settleFull) ...[
              const Text(
                'Nominal Cicilan',
                style: TextStyle(
                  color: primaryGreen,
                  fontSize: 14,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                autofocus: true,
                onChanged: (_) {
                  if (_amountError != null) {
                    setState(() => _amountError = null);
                  } else {
                    setState(() {});
                  }
                },
                style: const TextStyle(
                  color: primaryGreen,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Rp 0',
                  errorText: _amountError,
                  filled: true,
                  fillColor: inputBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: primaryGreen, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: primaryGreen, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryGreen, width: 2),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _fillRemaining,
                  child: const Text(
                    'Isi Sisa Penuh',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 12,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            DompetSelectionDropdown(
              label: _isDebt ? 'Bayar dari Dompet' : 'Masuk ke Dompet',
              hint: 'Pilih dompet',
              dompets: dompets,
              selectedDompetId: _selectedDompetId,
              onChanged: (val) => setState(() => _selectedDompetId = val),
            ),
            if (selectedDompet != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saldo tercatat di dompet:',
                      style: TextStyle(
                        color: insufficient ? Colors.red : primaryGreen,
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      Formatters.rupiah(selectedDompet.jumlah),
                      style: TextStyle(
                        color: insufficient ? Colors.red : primaryGreen,
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            if (insufficient)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Saldo catatan dompet tidak mencukupi. Pilih dompet lain atau kurangi nominal.',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            DatePickerField(
              label: 'Tanggal Pembayaran',
              hint: 'Pilih tanggal bayar',
              value: _selectedDate,
              firstDate: DateHelper.dateOnly(widget.item.date),
              lastDate: DateTime.now(),
              onChanged: (picked) {
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
            ),
            CustomTextField(
              label: 'Catatan (Opsional)',
              hint: 'Contoh: Cicilan ke-1 via transfer',
              controller: _noteController,
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
              : () => _submit(selectedDompet),
          child: const Text(
            'Simpan',
            style: TextStyle(
              color: primaryGreen,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
