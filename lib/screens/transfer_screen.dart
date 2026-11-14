import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/category_catalog.dart';
import '../models/dompet_model.dart';
import '../models/transaction_model.dart';
import '../providers/category_provider.dart';
import '../providers/contact_provider.dart';
import '../providers/dompet_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../utils/error_mapper.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/common/date_picker_field.dart';
import '../widgets/common/primary_button.dart';
import '../widgets/transaction/category_selection_field.dart';
import '../widgets/transaction/contact_selection_autocomplete.dart';
import '../widgets/transaction/dompet_selection_dropdown.dart';
import '../widgets/transaction/transaction_scaffold.dart';

class TransferScreen extends StatefulWidget {
  final TransactionModel? transactionToEdit;

  const TransferScreen({
    super.key,
    this.transactionToEdit,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahController = TextEditingController();
  final _catatanController = TextEditingController();
  final _untukController = TextEditingController();

  bool _isSelfTransfer = false;
  String? _selectedSourceDompetId;
  String? _selectedDestDompetId;
  String? _selectedCategoryId;
  DateTime _selectedTransactionDate = DateTime.now();
  bool _simpanKeDaftar = false;
  bool _isLoading = false;

  late final List<CategoryModel> _transferCategories;

  bool get _isEdit => widget.transactionToEdit != null;

  @override
  void initState() {
    super.initState();
    final baseCategories = CategoryCatalog.getByType(TransactionType.transfer);
    final editing = widget.transactionToEdit;

    if (editing != null &&
        !baseCategories.any((c) => c.id == editing.categoryId)) {
      _transferCategories = [
        ...baseCategories,
        CategoryCatalog.getById(
          editing.categoryId,
          fallbackType: TransactionType.transfer,
        ),
      ];
    } else {
      _transferCategories = baseCategories;
    }

    if (editing != null) {
      _isSelfTransfer = editing.destinationDompetId != null &&
          editing.destinationDompetId!.isNotEmpty;
      _selectedSourceDompetId = editing.dompetId;
      _selectedDestDompetId = editing.destinationDompetId;
      _selectedCategoryId = editing.categoryId;
      _jumlahController.text = CurrencyInputFormatter.formatValue(
        editing.amount.toStringAsFixed(0),
      );
      _catatanController.text = editing.notes;
      _selectedTransactionDate = editing.date;

      if (!_isSelfTransfer) {
        if (editing.counterpartyName != null &&
            editing.counterpartyName!.trim().isNotEmpty) {
          _untukController.text = editing.counterpartyName!.trim();
        } else if (editing.title.startsWith('Transfer ke ')) {
          _untukController.text =
              editing.title.substring('Transfer ke '.length).trim();
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final dompetProvider = context.read<DompetProvider>();
      final contactProvider = context.read<ContactProvider>();
      if (dompetProvider.items.isEmpty && !dompetProvider.isLoading) {
        await dompetProvider.loadDompets();
      }
      if (contactProvider.contacts.isEmpty && !contactProvider.isLoading) {
        await contactProvider.loadContacts();
      }
      if (!mounted) return;
      final catProvider = Provider.of<CategoryProvider?>(
        context,
        listen: false,
      );
      if (catProvider != null &&
          catProvider.customCategories.isEmpty &&
          !catProvider.isLoading) {
        await catProvider.loadCategories(silent: true);
      }
      if (!mounted) return;
      if (editing != null &&
          !_isSelfTransfer &&
          _untukController.text.isEmpty &&
          editing.contactId != null) {
        final contact = contactProvider.getContactById(editing.contactId);
        if (contact != null) {
          setState(() {
            _untukController.text = contact.name;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _jumlahController.dispose();
    _catatanController.dispose();
    _untukController.dispose();
    super.dispose();
  }

  void _ensureDefaultDompetSelected(List<DompetItem> dompets) {
    if (dompets.isEmpty) return;
    if (_selectedSourceDompetId == null ||
        !dompets.any((d) => d.id == _selectedSourceDompetId)) {
      _selectedSourceDompetId = dompets.first.id;
    }
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSourceDompetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih sumber dana terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isSelfTransfer && _selectedDestDompetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih dompet tujuan terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isSelfTransfer && _selectedSourceDompetId == _selectedDestDompetId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dompet asal dan tujuan tidak boleh sama'),
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
      final categoryId = _selectedCategoryId ?? _transferCategories.first.id;
      final cat = catProvider != null
          ? catProvider.resolve(
              categoryId,
              fallbackType: TransactionType.transfer,
            )
          : CategoryCatalog.getById(
              categoryId,
              fallbackType: TransactionType.transfer,
            );

      final contactProvider = context.read<ContactProvider>();
      final txProvider = context.read<TransactionProvider>();

      String? contactId;
      final recipientName = _untukController.text.trim();

      if (!_isSelfTransfer && recipientName.isNotEmpty) {
        final existing = contactProvider.contacts.where(
          (c) => c.name.trim().toLowerCase() == recipientName.toLowerCase(),
        );
        if (existing.isNotEmpty) {
          contactId = existing.first.id;
        } else if (_simpanKeDaftar) {
          final newContact = await contactProvider.addContact(recipientName);
          contactId = newContact.id;
        }
      }

      final transaction = TransactionModel(
        id: widget.transactionToEdit?.id ?? '',
        title: _isSelfTransfer
            ? 'Transfer Internal'
            : (recipientName.isNotEmpty
                ? 'Transfer ke $recipientName'
                : cat.name),
        amount: amount,
        date: DateHelper.withCurrentTime(
          _selectedTransactionDate,
          original: widget.transactionToEdit?.date,
        ),
        notes: _catatanController.text,
        categoryId: categoryId,
        type: TransactionType.transfer,
        dompetId: _selectedSourceDompetId!,
        destinationDompetId: _isSelfTransfer ? _selectedDestDompetId : null,
        contactId: contactId,
        counterpartyName: !_isSelfTransfer && recipientName.isNotEmpty
            ? recipientName
            : null,
      );

      if (_isEdit) {
        await txProvider.updateTransaction(transaction);
      } else {
        await txProvider.addTransaction(transaction);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEdit
                  ? '✅ Transfer berhasil diperbarui!'
                  : '✅ Transfer berhasil disimpan!',
            ),
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
    final contactProvider = context.watch<ContactProvider>();
    final dompets = dompetProvider.items;
    final contacts = contactProvider.contacts;
    _ensureDefaultDompetSelected(dompets);

    return TransactionScaffold(
      title: _isEdit ? 'Edit Transfer' : 'Transfer',
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
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isSelfTransfer = !_isSelfTransfer;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            children: [
                              Icon(
                                _isSelfTransfer
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: primaryGreen,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Transfer ke diri sendiri',
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: _isSelfTransfer
                            ? _buildSelfTransferUI(dompets)
                            : _buildNormalTransferUI(dompets),
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
                        type: TransactionType.transfer,
                        selectedCategoryId: _selectedCategoryId,
                        onChanged: (catId) {
                          setState(() => _selectedCategoryId = catId);
                        },
                      ),
                      CustomTextField(
                        label: 'Catatan',
                        hint: 'Tambah catatan (opsional)',
                        controller: _catatanController,
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
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: !_isSelfTransfer
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ContactSelectionAutocomplete(
                                    label: 'Untuk',
                                    hint: 'Nama teman',
                                    controller: _untukController,
                                    contacts: contacts,
                                    validator: (value) {
                                      if (!_isSelfTransfer &&
                                          (value == null ||
                                              value.trim().isEmpty)) {
                                        return 'Nama tujuan tidak boleh kosong';
                                      }
                                      return null;
                                    },
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _simpanKeDaftar = !_simpanKeDaftar;
                                      });
                                    },
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 24.0),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _simpanKeDaftar
                                                ? Icons.check_box
                                                : Icons.check_box_outline_blank,
                                            color: primaryGreen,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Simpan ke daftar',
                                            style: TextStyle(
                                              color: primaryGreen,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox(height: 24),
                      ),
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

  Widget _buildNormalTransferUI(List<DompetItem> dompets) {
    return Column(
      key: const ValueKey('normal_transfer'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DompetSelectionDropdown(
          label: 'Sumber Uang',
          hint: 'Pilih Sumber Uang',
          dompets: dompets,
          selectedDompetId: _selectedSourceDompetId,
          onChanged: (val) => setState(() => _selectedSourceDompetId = val),
        ),
      ],
    );
  }

  Widget _buildSelfTransferUI(List<DompetItem> dompets) {
    return Column(
      key: const ValueKey('self_transfer'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DompetSelectionDropdown(
          label: 'Dari',
          hint: 'Pilih Dompet Asal',
          dompets: dompets,
          selectedDompetId: _selectedSourceDompetId,
          onChanged: (val) => setState(() => _selectedSourceDompetId = val),
        ),
        DompetSelectionDropdown(
          label: 'Ke',
          hint: 'Pilih Dompet Tujuan',
          dompets: dompets,
          selectedDompetId: _selectedDestDompetId,
          onChanged: (val) => setState(() => _selectedDestDompetId = val),
        ),
      ],
    );
  }
}
