import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/common/custom_dropdown_field.dart';
import '../widgets/common/primary_button.dart';
import '../widgets/transaction/source_toggle.dart';
import '../widgets/transaction/account_selection_list.dart';
import '../widgets/transaction/transaction_scaffold.dart';
import '../data/transaction_model.dart';
import '../repositories/transaction_repository.dart';

class PengeluaranScreen extends StatefulWidget {
  final TransactionModel? transactionToEdit;

  const PengeluaranScreen({super.key, this.transactionToEdit});

  @override
  State<PengeluaranScreen> createState() => _PengeluaranScreenState();
}

class _PengeluaranScreenState extends State<PengeluaranScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahController = TextEditingController();
  final _catatanController = TextEditingController();

  int _selectedSource = 0; // 0 = Cash, 1 = Digital
  int? _selectedAccount;
  String? _selectedCategoryId;

  bool _isLoading = false;
  late List<CategoryModel> _expenseCategories;

  @override
  void initState() {
    super.initState();
    _expenseCategories = TransactionRepository.instance
        .getCategoriesByType(TransactionType.expense);

    if (widget.transactionToEdit != null) {
      final t = widget.transactionToEdit!;
      _jumlahController.text =
          CurrencyInputFormatter.formatValue(t.amount.toStringAsFixed(0));
      _catatanController.text = t.notes;
      _selectedCategoryId = t.categoryId;
      if (t.dompetId == 'd1') {
        _selectedSource = 0;
        _selectedAccount = null;
      } else {
        _selectedSource = 1;
        _selectedAccount = (int.tryParse(t.dompetId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 2) - 2;
      }
    }
  }

  @override
  void dispose() {
    _jumlahController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSource == 1 && _selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pilih akun digital terlebih dahulu'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amountStr =
          _jumlahController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final amount = double.tryParse(amountStr) ?? 0.0;
      final categoryId = _selectedCategoryId ?? _expenseCategories.first.id;
      final cat = TransactionRepository.instance.getCategoryById(categoryId);

      final transaction = TransactionModel(
        id: widget.transactionToEdit?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: _catatanController.text.isNotEmpty
            ? _catatanController.text
            : cat.name,
        amount: amount,
        date: widget.transactionToEdit?.date ?? DateTime.now(),
        notes: _catatanController.text,
        categoryId: categoryId,
        type: TransactionType.expense,
        dompetId: _selectedSource == 0 ? 'd1' : 'd${(_selectedAccount ?? 0) + 2}',
      );

      if (widget.transactionToEdit != null) {
        await TransactionRepository.instance.updateTransaction(transaction);
      } else {
        await TransactionRepository.instance.addTransaction(transaction);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data berhasil disimpan!'),
            backgroundColor: primaryGreen,
          ),
        );
        Navigator.pop(context, true); // return true to indicate change
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('❌ Gagal menyimpan: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.transactionToEdit != null ? 'Edit Pengeluaran' : 'Pengeluaran';
    final dropdownItems = _expenseCategories.map((c) => c.name).toList();
    final selectedCatName = _selectedCategoryId != null
        ? _expenseCategories
            .firstWhere((c) => c.id == _selectedCategoryId,
                orElse: () => _expenseCategories.first)
            .name
        : null;

    return TransactionScaffold(
      title: title,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SourceToggle(
                  label: 'Sumber Uang',
                  option1: 'Cash',
                  icon1: Icons.money,
                  option2: 'Digital',
                  icon2: Icons.phone_android,
                  selectedIndex: _selectedSource,
                  onSelect: (index) {
                    setState(() {
                      _selectedSource = index;
                      if (index == 0) _selectedAccount = null;
                    });
                  },
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _selectedSource == 1
                      ? AccountSelectionList(
                          selectedIndex: _selectedAccount,
                          onSelect: (index) {
                            setState(() {
                              _selectedAccount = index;
                            });
                          },
                        )
                      : const SizedBox.shrink(),
                ),
                CustomTextField(
                  label: 'Jumlah Uang',
                  hint: 'Rp 0',
                  keyboardType: TextInputType.number,
                  controller: _jumlahController,
                  inputFormatters: [CurrencyInputFormatter()],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Jumlah uang tidak boleh kosong';
                    }
                    if (value == 'Rp 0' || value == '0') {
                      return 'Jumlah harus lebih dari 0';
                    }
                    return null;
                  },
                ),
                CustomDropdownField(
                  label: 'Kategori',
                  hint: 'Pilih Kategori',
                  value: selectedCatName,
                  items: dropdownItems,
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = _expenseCategories
                          .firstWhere((c) => c.name == value)
                          .id;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Kategori tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                CustomTextField(
                  label: 'Catatan',
                  hint: 'Tambah catatan (opsional)',
                  controller: _catatanController,
                  validator: (value) {
                    if (value != null && value.length > 50) {
                      return 'Catatan maksimal 50 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: _isLoading ? 'Menyimpan...' : 'Simpan',
                  onPressed: _isLoading ? null : _submitData,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
