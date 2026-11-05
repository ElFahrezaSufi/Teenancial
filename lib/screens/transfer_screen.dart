import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/category_catalog.dart';
import '../models/dompet_model.dart';
import '../models/transaction_model.dart';
import '../providers/contact_provider.dart';
import '../providers/dompet_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/common/custom_dropdown_field.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/common/primary_button.dart';
import '../widgets/transaction/contact_selection_autocomplete.dart';
import '../widgets/transaction/dompet_selection_dropdown.dart';
import '../widgets/transaction/transaction_scaffold.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

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
  bool _simpanKeDaftar = false;
  bool _isLoading = false;

  late final List<CategoryModel> _transferCategories;

  @override
  void initState() {
    super.initState();
    _transferCategories = CategoryCatalog.getByType(TransactionType.transfer);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final dompetProvider = context.read<DompetProvider>();
      final contactProvider = context.read<ContactProvider>();
      if (dompetProvider.items.isEmpty && !dompetProvider.isLoading) {
        dompetProvider.loadDompets();
      }
      if (contactProvider.contacts.isEmpty && !contactProvider.isLoading) {
        contactProvider.loadContacts();
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
      final categoryId = _selectedCategoryId ?? _transferCategories.first.id;
      final cat = CategoryCatalog.getById(categoryId);

      final contactProvider = context.read<ContactProvider>();
      final txProvider = context.read<TransactionProvider>();

      String? contactId;
      final recipientName = _untukController.text.trim();

      if (!_isSelfTransfer && _simpanKeDaftar && recipientName.isNotEmpty) {
        final newContact = await contactProvider.addContact(recipientName);
        contactId = newContact.id;
      } else if (!_isSelfTransfer && recipientName.isNotEmpty) {
        final existing = contactProvider.contacts.where(
          (c) => c.name.toLowerCase() == recipientName.toLowerCase(),
        );
        if (existing.isNotEmpty) {
          contactId = existing.first.id;
        }
      }

      final transaction = TransactionModel(
        id: '',
        title: _isSelfTransfer
            ? 'Transfer Internal'
            : (recipientName.isNotEmpty
                ? 'Transfer ke $recipientName'
                : cat.name),
        amount: amount,
        date: DateTime.now(),
        notes: _catatanController.text,
        categoryId: categoryId,
        type: TransactionType.transfer,
        dompetId: _selectedSourceDompetId!,
        destinationDompetId: _isSelfTransfer ? _selectedDestDompetId : null,
        contactId: contactId,
      );

      await txProvider.addTransaction(transaction);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Transfer berhasil disimpan!'),
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
    final contactProvider = context.watch<ContactProvider>();
    final dompets = dompetProvider.items;
    final contacts = contactProvider.contacts;
    _ensureDefaultDompetSelected(dompets);

    final dropdownItems = _transferCategories.map((c) => c.name).toList();
    final selectedCatName = _selectedCategoryId != null
        ? _transferCategories
            .firstWhere(
              (c) => c.id == _selectedCategoryId,
              orElse: () => _transferCategories.first,
            )
            .name
        : null;

    return TransactionScaffold(
      title: 'Transfer',
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
                      CustomDropdownField(
                        label: 'Kategori',
                        hint: 'Pilih Kategori',
                        value: selectedCatName,
                        items: dropdownItems,
                        onChanged: (value) {
                          setState(() {
                            _selectedCategoryId = _transferCategories
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
                                          (value == null || value.isEmpty)) {
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
