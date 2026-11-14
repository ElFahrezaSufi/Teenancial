import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/category_catalog.dart';
import '../../models/dompet_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/dompet_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_helper.dart';
import '../../utils/error_mapper.dart';
import '../common/custom_text_field.dart';
import '../common/date_picker_field.dart';
import '../common/primary_button.dart';
import 'category_selection_field.dart';
import 'dompet_selection_dropdown.dart';
import 'transaction_scaffold.dart';

class TransactionFormScreen extends StatefulWidget {
  final TransactionType type;
  final TransactionModel? transactionToEdit;

  const TransactionFormScreen({
    super.key,
    required this.type,
    this.transactionToEdit,
  });

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahController = TextEditingController();
  final _catatanController = TextEditingController();

  String? _selectedDompetId;
  String? _selectedCategoryId;
  DateTime _selectedTransactionDate = DateTime.now();
  bool _isLoading = false;

  late final List<CategoryModel> _categories;

  String get _baseTitle =>
      widget.type == TransactionType.income ? 'Pemasukan' : 'Pengeluaran';

  @override
  void initState() {
    super.initState();
    _categories = CategoryCatalog.getByType(widget.type);

    if (widget.transactionToEdit != null) {
      final t = widget.transactionToEdit!;
      _jumlahController.text =
          CurrencyInputFormatter.formatValue(t.amount.toStringAsFixed(0));
      _catatanController.text = t.notes;
      _selectedCategoryId = t.categoryId;
      _selectedDompetId = t.dompetId;
      _selectedTransactionDate = t.date;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final dompetProvider = context.read<DompetProvider>();
      if (dompetProvider.items.isEmpty && !dompetProvider.isLoading) {
        dompetProvider.loadDompets();
      }
      final catProvider = Provider.of<CategoryProvider?>(
        context,
        listen: false,
      );
      if (catProvider != null &&
          catProvider.customCategories.isEmpty &&
          !catProvider.isLoading) {
        catProvider.loadCategories(silent: true);
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
      final catProvider = Provider.of<CategoryProvider?>(
        context,
        listen: false,
      );
      final categoryId = _selectedCategoryId ?? _categories.first.id;
      final cat = catProvider != null
          ? catProvider.resolve(categoryId, fallbackType: widget.type)
          : CategoryCatalog.getById(
              categoryId,
              fallbackType: widget.type,
            );

      final transaction = TransactionModel(
        id: widget.transactionToEdit?.id ?? '',
        title: _catatanController.text.isNotEmpty
            ? _catatanController.text
            : cat.name,
        amount: amount,
        date: DateHelper.withCurrentTime(
          _selectedTransactionDate,
          original: widget.transactionToEdit?.date,
        ),
        notes: _catatanController.text,
        categoryId: categoryId,
        type: widget.type,
        dompetId: _selectedDompetId!,
        isAdjustment: widget.transactionToEdit?.isAdjustment ?? false,
        recurringId: widget.transactionToEdit?.recurringId,
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
        context.pop(true);
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dompetProvider = context.watch<DompetProvider>();
    final dompets = dompetProvider.items;
    _ensureDefaultDompetSelected(dompets);

    final title = widget.transactionToEdit != null
        ? 'Edit $_baseTitle'
        : _baseTitle;

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
                      CategorySelectionField(
                        type: widget.type,
                        selectedCategoryId: _selectedCategoryId,
                        onChanged: (catId) {
                          setState(() => _selectedCategoryId = catId);
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
                      DatePickerField(
                        label: 'Tanggal Transaksi',
                        hint: 'Pilih tanggal transaksi',
                        value: _selectedTransactionDate,
                        lastDate: DateTime.now(),
                        onChanged: (picked) {
                          if (picked != null) {
                            setState(() => _selectedTransactionDate = picked);
                          }
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Tanggal transaksi harus dipilih';
                          }
                          if (DateHelper.daysBetween(DateTime.now(), value) >
                              0) {
                            return 'Tanggal transaksi tidak boleh di masa depan';
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
