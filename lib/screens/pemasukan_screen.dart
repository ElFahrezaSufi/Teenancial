import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/category_catalog.dart';
import '../models/dompet_model.dart';
import '../models/transaction_model.dart';
import '../providers/dompet_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/common/custom_dropdown_field.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/common/primary_button.dart';
import '../widgets/transaction/dompet_selection_dropdown.dart';
import '../widgets/transaction/transaction_scaffold.dart';

class PemasukanScreen extends StatefulWidget {
  final TransactionModel? transactionToEdit;

  const PemasukanScreen({super.key, this.transactionToEdit});

  @override
  State<PemasukanScreen> createState() => _PemasukanScreenState();
}

class _PemasukanScreenState extends State<PemasukanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahController = TextEditingController();
  final _catatanController = TextEditingController();

  String? _selectedDompetId;
  String? _selectedCategoryId;
  bool _isLoading = false;

  late final List<CategoryModel> _incomeCategories;

  @override
  void initState() {
    super.initState();
    _incomeCategories = CategoryCatalog.getByType(TransactionType.income);

    if (widget.transactionToEdit != null) {
      final t = widget.transactionToEdit!;
      _jumlahController.text =
          CurrencyInputFormatter.formatValue(t.amount.toStringAsFixed(0));
      _catatanController.text = t.notes;
      _selectedCategoryId = t.categoryId;
      _selectedDompetId = t.dompetId;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final dompetProvider = context.read<DompetProvider>();
      if (dompetProvider.items.isEmpty && !dompetProvider.isLoading) {
        dompetProvider.loadDompets();
      }
    });
  }

  @override
  void dispose() {
    _jumlahController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  void _ensureDefaultDompetSelected(List<DompetItem> dompets) {
    if (dompets.isEmpty) return;
    if (_selectedDompetId == null ||
        !dompets.any((d) => d.id == _selectedDompetId)) {
      _selectedDompetId = dompets.first.id;
    }
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDompetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih sumber dana terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amountStr =
          _jumlahController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final amount = double.tryParse(amountStr) ?? 0.0;
      final categoryId = _selectedCategoryId ?? _incomeCategories.first.id;
      final cat = CategoryCatalog.getById(categoryId);

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
        type: TransactionType.income,
        dompetId: _selectedDompetId!,
      );

      final txProvider = context.read<TransactionProvider>();
      if (widget.transactionToEdit != null) {
        await txProvider.updateTransaction(transaction);
      } else {
        await txProvider.addTransaction(transaction);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data berhasil disimpan!'),
            backgroundColor: primaryGreen,
          ),
        );
        Navigator.pop(context, true);
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dompetProvider = context.watch<DompetProvider>();
    final dompets = dompetProvider.items;
    _ensureDefaultDompetSelected(dompets);

    final title =
        widget.transactionToEdit != null ? 'Edit Pemasukan' : 'Pemasukan';

    final dropdownItems = _incomeCategories.map((c) => c.name).toList();
    final selectedCatName = _selectedCategoryId != null
        ? _incomeCategories
            .firstWhere(
              (c) => c.id == _selectedCategoryId,
              orElse: () => _incomeCategories.first,
            )
            .name
        : null;

    return TransactionScaffold(
      title: title,
      child: SafeArea(
        child: dompetProvider.isLoading && dompets.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: primaryGreen),
              )
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
                        dompets: dompets,
                        selectedDompetId: _selectedDompetId,
                        onChanged: (val) =>
                            setState(() => _selectedDompetId = val),
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
                            _selectedCategoryId = _incomeCategories
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
