import 'package:flutter/material.dart';
import '../widgets/transaction_widgets.dart';

class PemasukanScreen extends StatefulWidget {
  const PemasukanScreen({super.key});

  @override
  State<PemasukanScreen> createState() => _PemasukanScreenState();
}

class _PemasukanScreenState extends State<PemasukanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahController = TextEditingController();
  final _kategoriController = TextEditingController();
  final _catatanController = TextEditingController();

  int _selectedSource = 0; // 0 = Cash, 1 = Digital
  int? _selectedAccount; // Akun digital yang dipilih
  String? _selectedKategori;

  @override
  void dispose() {
    _jumlahController.dispose();
    _kategoriController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TransactionScaffold(
      title: 'Pemasukan',
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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

                // Tampilkan daftar akun digital jika "Digital" dipilih
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
                    if (value == null || value.isEmpty)
                      return 'Jumlah uang tidak boleh kosong';
                    return null;
                  },
                ),
                CustomDropdownField(
                  label: 'Kategori',
                  hint: 'Pilih Kategori',
                  value: _selectedKategori,
                  items: const ['Uang Jajan', 'Hadiah', 'Gaji', 'Lainnya'],
                  onChanged: (value) {
                    setState(() {
                      _selectedKategori = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Kategori tidak boleh kosong';
                    return null;
                  },
                ),
                CustomTextField(
                  label: 'Catatan',
                  hint: 'Tambah catatan (opsional)',
                  controller: _catatanController,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Simpan',
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Data berhasil disimpan!'),
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
