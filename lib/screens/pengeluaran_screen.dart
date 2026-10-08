import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/common/custom_dropdown_field.dart';
import '../widgets/common/primary_button.dart';
import '../widgets/transaction/dompet_selection_dropdown.dart';
import '../widgets/transaction/transaction_scaffold.dart';
import '../data/transaction_model.dart';
import '../data/dompet_model.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/dompet_repository.dart';

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

  String? _selectedDompetId;
  String? _selectedCategoryId;

  bool _isLoading = false;
  bool _isFetchingDompets = true;
  late List<CategoryModel> _expenseCategories;
  List<DompetItem> _dompets = [];

  @override
  void initState() {
    super.initState();
    _expenseCategories = TransactionRepository.instance
        .getCategoriesByType(TransactionType.expense);
    _fetchDompets();
  }

  Future<void> _fetchDompets() async {
    try {
      final dompets = await DompetRepository.instance.getDompets();
      setState(() {
        _dompets = dompets;
        _isFetchingDompets = false;
        
        if (widget.transactionToEdit != null) {
          final t = widget.transactionToEdit!;
          _jumlahController.text =
              CurrencyInputFormatter.formatValue(t.amount.toStringAsFixed(0));
          _catatanController.text = t.notes;
          _selectedCategoryId = t.categoryId;
          _selectedDompetId = t.dompetId;
        } else if (dompets.isNotEmpty) {
           // Default to first dompet if available
           _selectedDompetId = dompets.first.id;
        }
      });
    } catch (e) {
      setState(() => _isFetchingDompets = false);
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
    if (_selectedDompetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pilih sumber dana terlebih dahulu'),
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
        dompetId: _selectedDompetId!,
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
        // Show exception message like "Saldo tidak mencukupi..."
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
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
        child: _isFetchingDompets
            ? const Center(child: CircularProgressIndicator(color: primaryGreen))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DompetSelectionDropdown(
                        label: 'Sumber Uang',
                        hint: 'Pilih Sumber Uang',
                        dompets: _dompets,
                        selectedDompetId: _selectedDompetId,
                        onChanged: (val) => setState(() => _selectedDompetId = val),
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

