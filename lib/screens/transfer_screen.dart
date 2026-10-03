import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/common/custom_dropdown_field.dart';
import '../widgets/common/primary_button.dart';
import '../widgets/transaction/dompet_selection_dropdown.dart';
import '../widgets/transaction/contact_selection_autocomplete.dart';
import '../widgets/transaction/transaction_scaffold.dart';
import '../data/transaction_model.dart';
import '../data/dompet_model.dart';
import '../data/contact_model.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/dompet_repository.dart';
import '../repositories/contact_repository.dart';

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

  // Source Dompet
  String? _selectedSourceDompetId;
  // Destination Dompet (Only for Self Transfer)
  String? _selectedDestDompetId;

  String? _selectedCategoryId;
  bool _simpanKeDaftar = false;

  bool _isLoading = false;
  bool _isFetchingData = true;

  List<DompetItem> _dompets = [];
  late List<CategoryModel> _transferCategories;
  List<ContactModel> _contacts = [];

  @override
  void initState() {
    super.initState();
    _transferCategories = TransactionRepository.instance
        .getCategoriesByType(TransactionType.transfer);
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final dompets = await DompetRepository.instance.getDompets();
      final contacts = await ContactRepository.instance.getContacts();
      setState(() {
        _dompets = dompets;
        _contacts = contacts;
        _isFetchingData = false;

        if (dompets.isNotEmpty) {
           _selectedSourceDompetId = dompets.first.id;
        }
      });
    } catch (e) {
      setState(() => _isFetchingData = false);
    }
  }

  @override
  void dispose() {
    _jumlahController.dispose();
    _catatanController.dispose();
    _untukController.dispose();
    super.dispose();
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedSourceDompetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih sumber dana terlebih dahulu'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_isSelfTransfer && _selectedDestDompetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih dompet tujuan terlebih dahulu'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_isSelfTransfer && _selectedSourceDompetId == _selectedDestDompetId) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dompet asal dan tujuan tidak boleh sama'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amountStr = _jumlahController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final amount = double.tryParse(amountStr) ?? 0.0;
      final categoryId = _selectedCategoryId ?? _transferCategories.first.id;
      final cat = TransactionRepository.instance.getCategoryById(categoryId);

      String? contactId;

      // Handle Simpan Kontak
      if (!_isSelfTransfer && _simpanKeDaftar && _untukController.text.isNotEmpty) {
        final newContact = await ContactRepository.instance.addContact(_untukController.text);
        contactId = newContact.id;
      } else if (!_isSelfTransfer && _untukController.text.isNotEmpty) {
        // Coba cari id kontak jika ada yang match namanya walau ga dicentang
        final existing = _contacts.where((c) => c.name.toLowerCase() == _untukController.text.toLowerCase());
        if (existing.isNotEmpty) {
          contactId = existing.first.id;
        }
      }

      final transaction = TransactionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _isSelfTransfer ? 'Transfer Internal' : (_untukController.text.isNotEmpty ? 'Transfer ke ${_untukController.text}' : cat.name),
        amount: amount,
        date: DateTime.now(),
        notes: _catatanController.text,
        categoryId: categoryId,
        type: TransactionType.transfer,
        dompetId: _selectedSourceDompetId!,
        destinationDompetId: _isSelfTransfer ? _selectedDestDompetId : null,
        contactId: contactId,
      );

      await TransactionRepository.instance.addTransaction(transaction);

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
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dropdownItems = _transferCategories.map((c) => c.name).toList();
    final selectedCatName = _selectedCategoryId != null
        ? _transferCategories
            .firstWhere((c) => c.id == _selectedCategoryId,
                orElse: () => _transferCategories.first)
            .name
        : null;

    return TransactionScaffold(
      title: 'Transfer',
      child: SafeArea(
        child: _isFetchingData
            ? const Center(child: CircularProgressIndicator(color: primaryGreen))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Checkbox "Transfer ke diri sendiri"
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
                            ? _buildSelfTransferUI()
                            : _buildNormalTransferUI(),
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

                      // Animasi memunculkan/menghilangkan field "Untuk" & "Simpan ke daftar"
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
                                    contacts: _contacts,
                                    validator: (value) {
                                      if (!_isSelfTransfer && (value == null || value.isEmpty)) {
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
                                      padding: const EdgeInsets.only(bottom: 24.0),
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

  // --- UI Untuk Transfer Normal ---
  Widget _buildNormalTransferUI() {
    return Column(
      key: const ValueKey('normal_transfer'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DompetSelectionDropdown(
          label: 'Sumber Uang',
          hint: 'Pilih Sumber Uang',
          dompets: _dompets,
          selectedDompetId: _selectedSourceDompetId,
          onChanged: (val) => setState(() => _selectedSourceDompetId = val),
        ),
      ],
    );
  }

  // --- UI Untuk Transfer Diri Sendiri ---
  Widget _buildSelfTransferUI() {
    return Column(
      key: const ValueKey('self_transfer'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DompetSelectionDropdown(
          label: 'Dari',
          hint: 'Pilih Dompet Asal',
          dompets: _dompets,
          selectedDompetId: _selectedSourceDompetId,
          onChanged: (val) => setState(() => _selectedSourceDompetId = val),
        ),
        DompetSelectionDropdown(
          label: 'Ke',
          hint: 'Pilih Dompet Tujuan',
          dompets: _dompets,
          selectedDompetId: _selectedDestDompetId,
          onChanged: (val) => setState(() => _selectedDestDompetId = val),
        ),
      ],
    );
  }
}

