import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/category_catalog.dart';
import '../models/dompet_model.dart';
import '../models/recurring_model.dart';
import '../models/transaction_model.dart';
import '../providers/category_provider.dart';
import '../providers/contact_provider.dart';
import '../providers/dompet_provider.dart';
import '../providers/recurring_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../utils/error_mapper.dart';
import '../widgets/common/custom_dropdown_field.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/common/date_picker_field.dart';
import '../widgets/common/primary_button.dart';
import '../widgets/transaction/category_selection_field.dart';
import '../widgets/transaction/contact_selection_autocomplete.dart';
import '../widgets/transaction/dompet_selection_dropdown.dart';
import '../widgets/transaction/transaction_scaffold.dart';

class BuatBerulangArgs {
  final RecurringModel? itemToEdit;
  final TransactionType? initialType;

  const BuatBerulangArgs({
    this.itemToEdit,
    this.initialType,
  });
}

class BuatBerulangScreen extends StatefulWidget {
  final RecurringModel? itemToEdit;
  final TransactionType? initialType;

  const BuatBerulangScreen({
    super.key,
    this.itemToEdit,
    this.initialType,
  });

  @override
  State<BuatBerulangScreen> createState() => _BuatBerulangScreenState();
}

class _BuatBerulangScreenState extends State<BuatBerulangScreen> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _jumlahController = TextEditingController();
  final _catatanController = TextEditingController();
  final _untukController = TextEditingController();
  final _intervalController = TextEditingController(text: '1');

  late TransactionType _selectedType;
  bool _isSelfTransfer = true;
  String? _selectedSourceDompetId;
  String? _selectedDestDompetId;
  String? _selectedCategoryId;

  RecurrenceFrequency _selectedFrequency = RecurrenceFrequency.monthly;
  DateTime _startDate = RecurrenceRule.dateOnly(DateTime.now());
  bool _useEndDate = false;
  DateTime? _endDate;
  bool _isLoading = false;

  bool get _isEdit => widget.itemToEdit != null;

  static const List<TransactionType> _supportedTypes = [
    TransactionType.expense,
    TransactionType.income,
    TransactionType.transfer,
  ];

  @override
  void initState() {
    super.initState();
    final editing = widget.itemToEdit;
    if (editing != null) {
      _selectedType = editing.type;
      _isSelfTransfer = editing.isInternalTransfer;
      _selectedSourceDompetId = editing.dompetId;
      _selectedDestDompetId = editing.destinationDompetId;
      _selectedCategoryId = editing.categoryId;
      _judulController.text = editing.title;
      _jumlahController.text = CurrencyInputFormatter.formatValue(
        editing.amount.toStringAsFixed(0),
      );
      _catatanController.text = editing.notes;
      _untukController.text = editing.counterpartyName ?? '';
      _selectedFrequency = editing.frequency;
      _intervalController.text = editing.intervalCount.toString();
      _startDate = editing.startDate;
      _useEndDate = editing.endDate != null;
      _endDate = editing.endDate;
    } else {
      final initType = widget.initialType;
      _selectedType = (initType != null && _supportedTypes.contains(initType))
          ? initType
          : TransactionType.expense;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final dompetProvider = context.read<DompetProvider>();
      final contactProvider = context.read<ContactProvider>();
      final catProvider = Provider.of<CategoryProvider?>(
        context,
        listen: false,
      );
      if (dompetProvider.items.isEmpty && !dompetProvider.isLoading) {
        await dompetProvider.loadDompets();
      }
      if (contactProvider.contacts.isEmpty && !contactProvider.isLoading) {
        await contactProvider.loadContacts();
      }
      if (catProvider != null &&
          catProvider.customCategories.isEmpty &&
          !catProvider.isLoading) {
        await catProvider.loadCategories(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _judulController.dispose();
    _jumlahController.dispose();
    _catatanController.dispose();
    _untukController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  void _ensureDefaultDompetSelected(List<DompetItem> dompets) {
    if (dompets.isEmpty) return;
    if (_selectedSourceDompetId == null ||
        !dompets.any((d) => d.id == _selectedSourceDompetId)) {
      _selectedSourceDompetId = dompets.first.id;
    }
    if (_selectedType == TransactionType.transfer &&
        _isSelfTransfer &&
        (_selectedDestDompetId == null ||
            _selectedDestDompetId == _selectedSourceDompetId) &&
        dompets.length > 1) {
      _selectedDestDompetId =
          dompets.firstWhere((d) => d.id != _selectedSourceDompetId).id;
    }
  }

  String _typeTabLabel(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return 'Pengeluaran';
      case TransactionType.income:
        return 'Pemasukan';
      case TransactionType.transfer:
        return 'Transfer';
      default:
        return '';
    }
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSourceDompetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih dompet sumber terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedType == TransactionType.transfer && _isSelfTransfer) {
      if (_selectedDestDompetId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilih dompet tujuan terlebih dahulu'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (_selectedSourceDompetId == _selectedDestDompetId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dompet asal dan tujuan tidak boleh sama'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final int intervalCount =
        int.tryParse(_intervalController.text.trim()) ?? 1;
    if (intervalCount < 1 || intervalCount > 99) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Interval pengulangan harus antara 1 sampai 99'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_useEndDate && _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih tanggal berakhir terlebih dahulu'),
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
      final defaultCatId =
          CategoryCatalog.defaultCategoryIdForType(_selectedType);
      final categoryId = _selectedCategoryId ?? defaultCatId;
      final cat = catProvider != null
          ? catProvider.resolve(categoryId, fallbackType: _selectedType)
          : CategoryCatalog.getById(categoryId, fallbackType: _selectedType);

      final rawTitle = _judulController.text.trim();
      final recipientName = _untukController.text.trim();

      final String resolvedTitle;
      if (rawTitle.isNotEmpty) {
        resolvedTitle = rawTitle;
      } else if (_selectedType == TransactionType.transfer) {
        resolvedTitle = _isSelfTransfer
            ? 'Transfer Rutin'
            : (recipientName.isNotEmpty
                ? 'Transfer ke $recipientName'
                : cat.name);
      } else {
        resolvedTitle = cat.name;
      }

      final editing = widget.itemToEdit;
      final DateTime normalizedStart = RecurrenceRule.dateOnly(_startDate);

      // Bila membuat jadwal baru atau tanggal mulai diubah ke masa depan,
      // setel nextRunDate mengikuti normalizedStart; bila mengedit jadwal yang
      // sudah pernah berjalan, pertahankan nextRunDate jika masih relevan.
      DateTime nextRun = normalizedStart;
      if (editing != null && editing.lastRunDate != null) {
        final today = RecurrenceRule.dateOnly(DateTime.now());
        if (!normalizedStart.isAfter(today)) {
          nextRun = editing.nextRunDate;
        }
      }

      final model = RecurringModel(
        id: editing?.id ?? '',
        title: resolvedTitle,
        amount: amount,
        notes: _catatanController.text.trim(),
        categoryId: categoryId,
        type: _selectedType,
        dompetId: _selectedSourceDompetId!,
        destinationDompetId:
            (_selectedType == TransactionType.transfer && _isSelfTransfer)
                ? _selectedDestDompetId
                : null,
        counterpartyName:
            (_selectedType == TransactionType.transfer && !_isSelfTransfer)
                ? recipientName
                : null,
        frequency: _selectedFrequency,
        intervalCount: intervalCount,
        startDate: normalizedStart,
        nextRunDate: nextRun,
        endDate: _useEndDate ? _endDate : null,
        lastRunDate: editing?.lastRunDate,
        isActive: editing?.isActive ?? true,
        generatedCount: editing?.generatedCount ?? 0,
        skippedCount: editing?.skippedCount ?? 0,
        createdAt: editing?.createdAt ?? DateTime.now(),
      );

      await NotificationService.instance.requestPermissionIfNeeded();
      if (!mounted) return;
      final recProvider = context.read<RecurringProvider>();
      if (_isEdit) {
        await recProvider.updateRecurring(model);
      } else {
        await recProvider.addRecurring(model);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEdit
                  ? '✅ Jadwal transaksi berulang diperbarui!'
                  : '✅ Jadwal transaksi berulang disimpan!',
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

    final today = RecurrenceRule.dateOnly(DateTime.now());
    final bool startsTodayOrEarlier =
        !RecurrenceRule.dateOnly(_startDate).isAfter(today);

    return TransactionScaffold(
      title: _isEdit ? 'Edit Berulang' : 'Buat Berulang',
      child: SafeArea(
        child: dompetProvider.isLoading && dompets.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: primaryGreen),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
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
                            children: _supportedTypes.map((t) {
                              final selected = _selectedType == t;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedType = t;
                                      _selectedCategoryId = null;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 140),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? const Color(0xFFF8FFE8)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(
                                        color: selected
                                            ? primaryGreen
                                            : Colors.transparent,
                                        width: 1.6,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _typeTabLabel(t),
                                        style: TextStyle(
                                          color: primaryGreen,
                                          fontSize: 12,
                                          fontFamily: 'Inter',
                                          fontWeight: selected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_selectedType == TransactionType.transfer) ...[
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isSelfTransfer = !_isSelfTransfer;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              children: [
                                Icon(
                                  _isSelfTransfer
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  color: primaryGreen,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Transfer ke diri sendiri (antar dompet)',
                                  style: TextStyle(
                                    color: primaryGreen,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      DompetSelectionDropdown(
                        label: _selectedType == TransactionType.transfer &&
                                _isSelfTransfer
                            ? 'Dari Dompet'
                            : 'Sumber Uang',
                        hint: 'Pilih Dompet',
                        dompets: dompets,
                        selectedDompetId: _selectedSourceDompetId,
                        onChanged: (val) =>
                            setState(() => _selectedSourceDompetId = val),
                      ),
                      if (_selectedType == TransactionType.transfer &&
                          _isSelfTransfer)
                        DompetSelectionDropdown(
                          label: 'Ke Dompet',
                          hint: 'Pilih Dompet Tujuan',
                          dompets: dompets,
                          selectedDompetId: _selectedDestDompetId,
                          onChanged: (val) =>
                              setState(() => _selectedDestDompetId = val),
                        ),
                      if (_selectedType == TransactionType.transfer &&
                          !_isSelfTransfer)
                        ContactSelectionAutocomplete(
                          label: 'Untuk',
                          hint: 'Nama penerima',
                          controller: _untukController,
                          contacts: contacts,
                          validator: (value) {
                            if (_selectedType == TransactionType.transfer &&
                                !_isSelfTransfer &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Nama penerima tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                      CustomTextField(
                        label: 'Judul Jadwal',
                        hint: _selectedType == TransactionType.income
                            ? 'Contoh: Uang Saku Bulanan'
                            : (_selectedType == TransactionType.transfer
                                ? 'Contoh: Tabungan Rutin'
                                : 'Contoh: Langganan Spotify'),
                        controller: _judulController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Judul jadwal tidak boleh kosong';
                          }
                          if (value.trim().length > 40) {
                            return 'Judul maksimal 40 karakter';
                          }
                          return null;
                        },
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
                        type: _selectedType,
                        selectedCategoryId: _selectedCategoryId,
                        onChanged: (catId) =>
                            setState(() => _selectedCategoryId = catId),
                      ),
                      CustomTextField(
                        label: 'Catatan (Opsional)',
                        hint: 'Tambah keterangan singkat',
                        controller: _catatanController,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Aturan Pengulangan',
                        style: TextStyle(
                          color: primaryGreen,
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 110,
                            child: CustomTextField(
                              label: 'Setiap',
                              hint: '1',
                              keyboardType: TextInputType.number,
                              controller: _intervalController,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2),
                              ],
                              validator: (val) {
                                final n = int.tryParse(val ?? '') ?? 0;
                                if (n < 1) return 'Min 1';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomDropdownField(
                              label: 'Satuan Waktu',
                              hint: 'Pilih frekuensi',
                              value: _selectedFrequency.unitLabel,
                              items: RecurrenceFrequency.values
                                  .map((f) => f.unitLabel)
                                  .toList(),
                              onChanged: (val) {
                                final match = RecurrenceFrequency.values
                                    .where((f) => f.unitLabel == val);
                                if (match.isNotEmpty) {
                                  setState(
                                    () => _selectedFrequency = match.first,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      DatePickerField(
                        label: 'Mulai Tanggal',
                        hint: 'Pilih tanggal mulai',
                        value: _startDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2035),
                        onChanged: (picked) {
                          if (picked != null) {
                            setState(
                              () => _startDate = RecurrenceRule.dateOnly(picked),
                            );
                          }
                        },
                      ),
                      if (!_isEdit && startsTodayOrEarlier)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: primaryGreen.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                  color: primaryGreen,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Karena tanggal mulai adalah ${DateHelper.formatShort(_startDate)}, transaksi pertama akan langsung dicatat otomatis saat disimpan.',
                                    style: const TextStyle(
                                      color: primaryGreen,
                                      fontSize: 11.5,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _useEndDate = !_useEndDate;
                            if (_useEndDate && _endDate == null) {
                              _endDate = DateTime(
                                _startDate.year,
                                _startDate.month + 3,
                                _startDate.day,
                              );
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Icon(
                                _useEndDate
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: primaryGreen,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Tetapkan batas tanggal berakhir (opsional)',
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontSize: 13,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_useEndDate)
                        DatePickerField(
                          label: 'Berakhir Tanggal',
                          hint: 'Pilih tanggal berakhir',
                          value: _endDate,
                          firstDate: _startDate,
                          lastDate: DateTime(2035),
                          onChanged: (picked) {
                            if (picked != null) {
                              setState(
                                () => _endDate = RecurrenceRule.dateOnly(picked),
                              );
                            }
                          },
                          validator: (val) {
                            if (_useEndDate && val == null) {
                              return 'Pilih tanggal berakhir';
                            }
                            if (_useEndDate &&
                                val != null &&
                                RecurrenceRule.dateOnly(val)
                                    .isBefore(RecurrenceRule.dateOnly(_startDate))) {
                              return 'Tidak boleh sebelum tanggal mulai';
                            }
                            return null;
                          },
                        ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: _isLoading ? 'Menyimpan...' : 'Simpan Jadwal',
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
