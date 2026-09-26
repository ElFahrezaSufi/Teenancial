import 'package:flutter/material.dart';
import '../widgets/transaction_widgets.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahController = TextEditingController();
  final _kategoriController = TextEditingController();
  final _catatanController = TextEditingController();
  final _untukController = TextEditingController();

  bool _isSelfTransfer = false;

  // State untuk mode Normal (Ke Orang Lain)
  int _selectedSourceNormal = 0;
  int? _selectedAccountNormal;
  bool _simpanKeDaftar = false;

  // State untuk mode Diri Sendiri
  int _selectedSourceDari = 0;
  int? _selectedAccountDari;
  int _selectedSourceKe = 1;
  int? _selectedAccountKe;
  String? _selectedKategori;

  @override
  void dispose() {
    _jumlahController.dispose();
    _kategoriController.dispose();
    _catatanController.dispose();
    _untukController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TransactionScaffold(
      title: 'Transfer',
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Animasi pergantian antara Transfer Normal vs Diri Sendiri
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _isSelfTransfer
                      ? _buildSelfTransferUI()
                      : _buildNormalTransferUI(),
                ),

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
                  items: const [
                    'Transfer Teman',
                    'Bayar Hutang',
                    'Donasi',
                    'Lainnya'
                  ],
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

                // Animasi memunculkan/menghilangkan field "Untuk" & "Simpan ke daftar"
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: !_isSelfTransfer
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomTextField(
                              label: 'Untuk',
                              hint: 'Nama teman',
                              controller: _untukController,
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

  // --- UI Untuk Transfer Normal ---
  Widget _buildNormalTransferUI() {
    return Column(
      key: const ValueKey('normal_transfer'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SourceToggle(
          label: 'Sumber Uang',
          option1: 'Cash',
          icon1: Icons.money,
          option2: 'Digital',
          icon2: Icons.phone_android,
          selectedIndex: _selectedSourceNormal,
          onSelect: (index) {
            setState(() {
              _selectedSourceNormal = index;
              if (index == 0) _selectedAccountNormal = null;
            });
          },
        ),
        if (_selectedSourceNormal == 1)
          AccountSelectionList(
            selectedIndex: _selectedAccountNormal,
            onSelect: (index) {
              setState(() {
                _selectedAccountNormal = index;
              });
            },
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
        SourceToggle(
          label: 'Dari',
          option1: 'Cash',
          icon1: Icons.money,
          option2: 'Digital',
          icon2: Icons.phone_android,
          selectedIndex: _selectedSourceDari,
          onSelect: (index) {
            setState(() {
              _selectedSourceDari = index;
              if (index == 0) _selectedAccountDari = null;
            });
          },
        ),
        if (_selectedSourceDari == 1)
          AccountSelectionList(
            selectedIndex: _selectedAccountDari,
            onSelect: (index) {
              setState(() {
                _selectedAccountDari = index;
              });
            },
          ),
        SourceToggle(
          label: 'Ke',
          option1: 'Cash',
          icon1: Icons.money,
          option2: 'Digital',
          icon2: Icons.phone_android,
          selectedIndex: _selectedSourceKe,
          onSelect: (index) {
            setState(() {
              _selectedSourceKe = index;
              if (index == 0) _selectedAccountKe = null;
            });
          },
        ),
        if (_selectedSourceKe == 1)
          AccountSelectionList(
            selectedIndex: _selectedAccountKe,
            onSelect: (index) {
              setState(() {
                _selectedAccountKe = index;
              });
            },
          ),
      ],
    );
  }
}
