import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/category_catalog.dart';
import '../models/dompet_model.dart';
import '../models/transaction_model.dart';
import '../providers/contact_provider.dart';
import '../providers/dompet_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../utils/error_mapper.dart';
import '../utils/loan_helper.dart';
import '../widgets/common/custom_dropdown_field.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/common/date_picker_field.dart';
import '../widgets/common/primary_button.dart';
import '../widgets/transaction/contact_selection_autocomplete.dart';
import '../widgets/transaction/dompet_selection_dropdown.dart';
import '../widgets/transaction/transaction_scaffold.dart';

class PinjamanScreen extends StatefulWidget {
  final TransactionModel? loanToEdit;

  const PinjamanScreen({
    super.key,
    this.loanToEdit,
  });

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

  DateTime _selectedTransactionDate = DateTime.now();
  DateTime? _selectedDateObj;
  bool _simpanKeDaftar = false;
  bool _isLoading = false;

  late final List<CategoryModel> _debtCategories;
  late final List<CategoryModel> _receivableCategories;

  bool get _isEdit => widget.loanToEdit != null;

  @override
  void initState() {
    super.initState();
    _debtCategories = CategoryCatalog.getByType(TransactionType.debt);
    _receivableCategories =
        CategoryCatalog.getByType(TransactionType.receivable);

    final editing = widget.loanToEdit;
    if (editing != null) {
      _selectedTab = editing.type == TransactionType.debt ? 0 : 1;
      _selectedDompetId = editing.dompetId;
      _selectedCategoryId = editing.categoryId;
      _jumlahController.text = CurrencyInputFormatter.formatValue(
        editing.amount.toStringAsFixed(0),
      );
      _catatanController.text = editing.notes;
      _selectedTransactionDate = editing.date;
      _selectedDateObj = editing.dueDate;
      _temanController.text = LoanHelper.counterpartyName(editing);
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
      if (editing != null && editing.contactId != null) {
        final contact = contactProvider.getContactById(editing.contactId);
        if (contact != null && _temanController.text.isEmpty) {
          setState(() {
            _temanController.text = contact.name;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _jumlahController.dispose();
    _catatanController.dispose();
    _temanController.dispose();
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

    final editing = widget.loanToEdit;
    if (editing != null && editing.isPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pinjaman yang sudah lunas tidak dapat diedit.'),
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
      final isDebt = _selectedTab == 0;

      if (editing != null && amount + 0.0001 < editing.paidAmount) {
        throw Exception(
          'Nominal pinjaman tidak boleh kurang dari cicilan yang sudah terbayar (${Formatters.rupiah(editing.paidAmount)}).',
        );
      }

      final dompetProvider = context.read<DompetProvider>();
      final contactProvider = context.read<ContactProvider>();
      final txProvider = context.read<TransactionProvider>();

      // Validasi kecukupan saldo saat membuat piutang baru sebelum menulis kontak
      if (!_isEdit && !isDebt) {
        final selectedDompets =
            dompetProvider.items.where((d) => d.id == _selectedDompetId);
        if (selectedDompets.isNotEmpty &&
            selectedDompets.first.jumlah < amount) {
          throw Exception(
            'Saldo dompet "${selectedDompets.first.nama}" tidak mencukupi untuk memberikan pinjaman ini.',
          );
        }
      }

      final currentCategories =
          isDebt ? _debtCategories : _receivableCategories;
      final categoryId = _selectedCategoryId ?? currentCategories.first.id;

      String? contactId;
      final friendName = _temanController.text.trim();
      if (friendName.isNotEmpty) {
        final existing = contactProvider.contacts.where(
          (c) => c.name.trim().toLowerCase() == friendName.toLowerCase(),
        );
        if (existing.isNotEmpty) {
          contactId = existing.first.id;
        } else if (_simpanKeDaftar) {
          final newContact = await contactProvider.addContact(friendName);
          contactId = newContact.id;
        }
      }

      final existingPayments = editing?.payments ?? const <LoanPayment>[];
      final double paidSoFar = editing?.paidAmount ?? 0.0;
      final bool nowPaid = amount > 0 && paidSoFar + 0.0001 >= amount;

      final transaction = TransactionModel(
        id: editing?.id ?? '',
        title: '${isDebt ? 'Hutang dari' : 'Piutang ke'} $friendName',
        amount: amount,
        date: DateHelper.withCurrentTime(
          _selectedTransactionDate,
          original: editing?.date,
        ),
        notes: _catatanController.text.trim(),
        categoryId: categoryId,
        type: isDebt ? TransactionType.debt : TransactionType.receivable,
        dompetId: _selectedDompetId!,
        dueDate: _selectedDateObj,
        contactId: contactId,
        counterpartyName: friendName,
        isPaid: nowPaid,
        paidDompetId: nowPaid && existingPayments.isNotEmpty
            ? existingPayments.last.dompetId
            : editing?.paidDompetId,
        payments: existingPayments,
      );

      await NotificationService.instance.requestPermissionIfNeeded();
      if (_isEdit) {
        await txProvider.updateTransaction(transaction);
      } else {
        await txProvider.addTransaction(transaction);
        await NotificationService.instance.showLoanCreatedNotification(
          transaction,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEdit
                  ? '✅ Data Pinjaman Berhasil Diperbarui!'
                  : (isDebt
                      ? '✅ Data Pinjaman Tersimpan!'
                      : '✅ Data Piutang Tersimpan!'),
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

  Widget _buildTabButton(int index, String title, Color activeColor) {
    final isSelected = _selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
            _selectedCategoryId = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.only(top: isSelected ? 0.0 : 4.0),
          decoration: BoxDecoration(
            color:
                isSelected ? activeColor : activeColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(50),
          ),
          padding: EdgeInsets.only(bottom: isSelected ? 6.0 : 2.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color:
                  isSelected ? const Color(0xFFF8FFE8) : Colors.transparent,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: isSelected
                    ? activeColor
                    : activeColor.withValues(alpha: 0.3),
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
    final dompetProvider = context.watch<DompetProvider>();
    final contactProvider = context.watch<ContactProvider>();
    final dompets = dompetProvider.items;
    final contacts = contactProvider.contacts;
    _ensureDefaultDompetSelected(dompets);

    final currentCategories =
        _selectedTab == 0 ? _debtCategories : _receivableCategories;
    final dropdownItems = currentCategories.map((c) => c.name).toList();
    final selectedCatName = _selectedCategoryId != null
        ? currentCategories
            .firstWhere(
              (c) => c.id == _selectedCategoryId,
              orElse: () => currentCategories.first,
            )
            .name
        : null;

    final editing = widget.loanToEdit;
    final double paidAmount = editing?.paidAmount ?? 0.0;
    final DateTime? earliestPaymentDate =
        (editing != null && editing.payments.isNotEmpty)
            ? editing.payments.first.date
            : null;

    return TransactionScaffold(
      title: _isEdit
          ? (_selectedTab == 0 ? 'Edit Hutang' : 'Edit Piutang')
          : 'Pinjaman',
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
                      if (!_isEdit) ...[
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4DFBA),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            children: [
                              _buildTabButton(
                                0,
                                'Pinjam Uang',
                                const Color(0xFF415121),
                              ),
                              const SizedBox(width: 6),
                              _buildTabButton(
                                1,
                                'Kasih Pinjam',
                                const Color(0xFF415121),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
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
                          final parsed = double.tryParse(
                                value.replaceAll(RegExp(r'[^0-9]'), ''),
                              ) ??
                              0.0;
                          if (parsed <= 0) {
                            return 'Jumlah harus lebih dari 0';
                          }
                          if (paidAmount > 0 && parsed + 0.0001 < paidAmount) {
                            return 'Minimal ${Formatters.rupiah(paidAmount)} (sudah dicicil)';
                          }
                          return null;
                        },
                      ),
                      if (_isEdit && paidAmount > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, left: 4),
                          child: Text(
                            'Sudah dicicil sebesar ${Formatters.rupiah(paidAmount)}. Nominal sama dengan cicilan akan menandai pinjaman lunas.',
                            style: TextStyle(
                              color: primaryGreen.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
                      DatePickerField(
                        label: 'Tanggal Pinjaman',
                        hint: 'Pilih tanggal pinjaman',
                        value: _selectedTransactionDate,
                        lastDate: earliestPaymentDate ?? DateTime.now(),
                        onChanged: (picked) {
                          if (picked != null) {
                            setState(() => _selectedTransactionDate = picked);
                          }
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Tanggal pinjaman harus dipilih';
                          }
                          if (DateHelper.daysBetween(DateTime.now(), value) >
                              0) {
                            return 'Tanggal pinjaman tidak boleh di masa depan';
                          }
                          if (earliestPaymentDate != null &&
                              DateHelper.daysBetween(
                                    earliestPaymentDate,
                                    value,
                                  ) >
                                  0) {
                            return 'Tidak boleh setelah tanggal cicilan pertama';
                          }
                          return null;
                        },
                      ),
                      DatePickerField(
                        label: 'Batas Waktu',
                        hint: 'Pilih tanggal',
                        value: _selectedDateObj,
                        firstDate: _selectedTransactionDate,
                        onChanged: (picked) =>
                            setState(() => _selectedDateObj = picked),
                        validator: (value) {
                          if (value == null) {
                            return 'Batas waktu harus dipilih';
                          }
                          if (DateHelper.daysBetween(
                                _selectedTransactionDate,
                                value,
                              ) <
                              0) {
                            return 'Batas waktu tidak boleh sebelum tanggal pinjaman';
                          }
                          return null;
                        },
                      ),
                      ContactSelectionAutocomplete(
                        label: _selectedTab == 0 ? 'Dari' : 'Untuk',
                        hint: 'Nama teman',
                        controller: _temanController,
                        contacts: contacts,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
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
