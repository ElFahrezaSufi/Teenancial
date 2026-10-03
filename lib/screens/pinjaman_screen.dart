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

class PinjamanScreen extends StatefulWidget {
  const PinjamanScreen({super.key});

  @override
  State<PinjamanScreen> createState() => _PinjamanScreenState();
}

class _PinjamanScreenState extends State<PinjamanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahController = TextEditingController();
  final _catatanController = TextEditingController();
  final _temanController = TextEditingController();

  int _selectedTab = 0; // 0 = Hutang (Debt), 1 = Piutang (Receivable)
  
  String? _selectedDompetId;
  String? _selectedCategoryId;
  
  DateTime? _selectedDateObj;
  String get _selectedDate => _selectedDateObj != null
      ? "${_selectedDateObj!.day}/${_selectedDateObj!.month}/${_selectedDateObj!.year}"
      : '';
  bool _simpanKeDaftar = false;

  bool _isLoading = false;
  bool _isFetchingData = true;

  List<DompetItem> _dompets = [];
  List<ContactModel> _contacts = [];
  List<CategoryModel> _debtCategories = [];
  List<CategoryModel> _receivableCategories = [];

  @override
  void initState() {
    super.initState();
    _debtCategories = TransactionRepository.instance.getCategoriesByType(TransactionType.debt);
    _receivableCategories = TransactionRepository.instance.getCategoriesByType(TransactionType.receivable);
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
           _selectedDompetId = dompets.first.id;
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
    _temanController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryGreen,
              onPrimary: Colors.white,
              onSurface: primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDateObj = picked;
      });
    }
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedDompetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih sumber dana terlebih dahulu'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amountStr = _jumlahController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final amount = double.tryParse(amountStr) ?? 0.0;
      final isDebt = _selectedTab == 0;
      
      final currentCategories = isDebt ? _debtCategories : _receivableCategories;
      final categoryId = _selectedCategoryId ?? currentCategories.first.id;

      String? contactId;
      if (_simpanKeDaftar && _temanController.text.isNotEmpty) {
        final newContact = await ContactRepository.instance.addContact(_temanController.text);
        contactId = newContact.id;
      } else if (_temanController.text.isNotEmpty) {
        final existing = _contacts.where((c) => c.name.toLowerCase() == _temanController.text.toLowerCase());
        if (existing.isNotEmpty) {
          contactId = existing.first.id;
        }
      }

      final transaction = TransactionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '${isDebt ? 'Hutang dari' : 'Piutang ke'} ${_temanController.text}',
        amount: amount,
        date: DateTime.now(),
        notes: _catatanController.text,
        categoryId: categoryId,
        type: isDebt ? TransactionType.debt : TransactionType.receivable,
        dompetId: _selectedDompetId!,
        dueDate: _selectedDateObj,
        contactId: contactId,
      );

      await TransactionRepository.instance.addTransaction(transaction);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isDebt ? '✅ Data Pinjaman Tersimpan!' : '✅ Data Piutang Tersimpan!'),
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

  Widget _buildTabButton(int index, String title, Color activeColor) {
    final isSelected = _selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
            _selectedCategoryId = null; // Reset category when tab changes
          });
        },
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
                color: isSelected ? activeColor : activeColor.withValues(alpha: 0.3),
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

  @override
  Widget build(BuildContext context) {
    final currentCategories = _selectedTab == 0 ? _debtCategories : _receivableCategories;
    final dropdownItems = currentCategories.map((c) => c.name).toList();
    final selectedCatName = _selectedCategoryId != null
        ? currentCategories
            .firstWhere((c) => c.id == _selectedCategoryId,
                orElse: () => currentCategories.first)
            .name
        : null;

    return TransactionScaffold(
      title: 'Pinjaman',
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
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4DFBA),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          children: [
                            _buildTabButton(0, 'Pinjam Uang', const Color(0xFF415121)),
                            const SizedBox(width: 6),
                            _buildTabButton(1, 'Kasih Pinjam', const Color(0xFF415121)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedTab == 0
                            ? 'Lagi pinjam uang teman? Sini kami bantu catat, biar kamu nggak lupa balikin!'
                            : 'Pinjamkan uang ke teman? Kami akan ingatkan saat batas waktunya tiba',
                        style: const TextStyle(
                          color: primaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),

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
                            _selectedCategoryId = currentCategories
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
                      
                      CustomTextField(
                        label: 'Batas Waktu',
                        hint: _selectedDate.isEmpty ? 'Pilih tanggal' : _selectedDate,
                        readOnly: true,
                        onTap: () => _selectDate(context),
                        suffixIcon: const Icon(Icons.calendar_today, color: primaryGreen),
                        validator: (value) {
                          if (_selectedDate.isEmpty) {
                            return 'Batas waktu harus dipilih';
                          }
                          return null;
                        },
                      ),
                      
                      ContactSelectionAutocomplete(
                        label: _selectedTab == 0 ? 'Dari' : 'Untuk',
                        hint: 'Nama teman',
                        controller: _temanController,
                        contacts: _contacts,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Nama teman tidak boleh kosong';
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
