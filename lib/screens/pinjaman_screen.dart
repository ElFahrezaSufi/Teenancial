import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/common/custom_dropdown_field.dart';
import '../widgets/common/primary_button.dart';
import '../widgets/transaction/source_toggle.dart';
import '../widgets/transaction/account_selection_list.dart';
import '../widgets/transaction/transaction_scaffold.dart';

class PinjamanScreen extends StatefulWidget {
  const PinjamanScreen({super.key});

  @override
  State<PinjamanScreen> createState() => _PinjamanScreenState();
}

class _PinjamanScreenState extends State<PinjamanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahController = TextEditingController();
  final _kategoriController = TextEditingController();
  final _catatanController = TextEditingController();
  final _temanController = TextEditingController();

  int _selectedTab = 0; // 0 = Pinjam Uang, 1 = Kasih Pinjam
  int _selectedSource = 0; // 0 = Cash, 1 = Digital
  int? _selectedAccount;
  String? _selectedKategori;
  // PERBAIKAN: Menggunakan objek DateTime? untuk kemudahan Database di masa depan
  DateTime? _selectedDateObj;
  String get _selectedDate => _selectedDateObj != null
      ? "${_selectedDateObj!.day}/${_selectedDateObj!.month}/${_selectedDateObj!.year}"
      : '';
  bool _simpanKeDaftar = false;

  @override
  void dispose() {
    _jumlahController.dispose();
    _kategoriController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return TransactionScaffold(
      title: 'Pinjaman',
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Custom Tab Toggle (Pinjam Uang vs Kasih Pinjam)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4DFBA), // Warna hijau pucat/abu
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedTab == 0
                                  ? appBarBg
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(26),
                              border: _selectedTab == 0
                                  ? Border.all(color: primaryGreen, width: 2)
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'Pinjam Uang',
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontWeight: _selectedTab == 0
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedTab == 1
                                  ? appBarBg
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(26),
                              border: _selectedTab == 1
                                  ? Border.all(color: primaryGreen, width: 2)
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'Kasih Pinjam',
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontWeight: _selectedTab == 1
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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
                    return null;
                  },
                ),
                CustomDropdownField(
                  label: 'Kategori',
                  hint: 'Pilih Kategori',
                  value: _selectedKategori,
                  items: const [
                    'Teman Sekolah',
                    'Keluarga',
                    'Mendesak',
                    'Lainnya'
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedKategori = value;
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
                  suffixIcon:
                      const Icon(Icons.calendar_today, color: primaryGreen),
                  validator: (value) {
                    if (_selectedDate.isEmpty) {
                      return 'Batas waktu harus dipilih';
                    }
                    return null;
                  },
                ),

                CustomTextField(
                  label: _selectedTab == 0 ? 'Dari' : 'Untuk',
                  hint: 'Nama teman',
                  controller: _temanController,
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
                  label: 'Simpan',
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_selectedTab == 0
                              ? '✅ Data Pinjaman Tersimpan!'
                              : '✅ Data Piutang Tersimpan!'),
                          backgroundColor: primaryGreen,
                        ),
                      );
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
