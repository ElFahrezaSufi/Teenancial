import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/common/custom_dropdown_field.dart';
import '../widgets/common/primary_button.dart';
import '../widgets/transaction/source_toggle.dart';
import '../widgets/transaction/account_selection_list.dart';
import '../widgets/transaction/transaction_scaffold.dart';
import '../data/pinjaman_model.dart';
import '../repositories/dompet_repository.dart';
import '../repositories/pinjaman_repository.dart';
import 'pinjaman_list_screen.dart';

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

  int _selectedTab = 0;
  int _selectedSource = 0;
  int? _selectedAccount;
  String? _selectedKategori;
  DateTime? _selectedDateObj;
  String get _selectedDate => _selectedDateObj != null
      ? "${_selectedDateObj!.day}/${_selectedDateObj!.month}/${_selectedDateObj!.year}"
      : '';
  bool _simpanKeDaftar = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _jumlahController.dispose();
    _kategoriController.dispose();
    _catatanController.dispose();
    _temanController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    final repo = DompetRepository.instance;
    final dompetId = repo.idFromSelection(_selectedSource, _selectedAccount);
    if (dompetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pilih akun digital terlebih dahulu'),
            backgroundColor: Colors.red),
      );
      return;
    }
    final amount = double.tryParse(
            _jumlahController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Jumlah uang harus lebih dari 0'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final jenis =
          _selectedTab == 0 ? JenisPinjaman.pinjaman : JenisPinjaman.piutang;
      // Pinjaman = uang masuk ke dompet. Piutang = uang keluar dari dompet.
      if (jenis == JenisPinjaman.pinjaman) {
        await repo.tambahSaldo(dompetId, amount);
      } else {
        await repo.transfer(fromId: dompetId, amount: amount);
      }
      await PinjamanRepository.instance.add(PinjamanItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        jenis: jenis,
        nama: _temanController.text.trim(),
        jumlah: amount,
        kategori: _selectedKategori ?? 'Lainnya',
        jatuhTempo: _selectedDateObj!,
        catatan: _catatanController.text,
        dompetId: dompetId,
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(jenis == JenisPinjaman.pinjaman
              ? '✅ Data Pinjaman Tersimpan!'
              : '✅ Data Piutang Tersimpan!'),
          backgroundColor: primaryGreen,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '❌ Gagal menyimpan: ${e.toString().replaceFirst('Exception: ', '')}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  Widget _buildTabButton(int index, String title, Color activeColor) {
    final isSelected = _selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
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
              color: isSelected ? const Color(0xFFF8FFE8) : Colors.transparent,
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
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4DFBA),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton(
                          0, 'Pinjam Uang', const Color(0xFF415121)),
                      const SizedBox(width: 6),
                      _buildTabButton(
                          1, 'Kasih Pinjam', const Color(0xFF415121)),
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
                  option2: 'Digital',
                  icon1: Icons.money,
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
                  label: _isLoading ? 'Menyimpan...' : 'Simpan',
                  onPressed: _isLoading ? null : _submit,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PinjamanListScreen()),
                          ),
                  child: const Text(
                    'Lihat daftar pinjaman & piutang',
                    style: TextStyle(
                        color: primaryGreen, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
