import 'package:flutter/material.dart';
import '../widgets/transaction_widgets.dart';





class PengeluaranScreen extends StatefulWidget {
  const PengeluaranScreen({super.key});

  @override
  State<PengeluaranScreen> createState() => _PengeluaranScreenState();
}

class _PengeluaranScreenState extends State<PengeluaranScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahController = TextEditingController();
  final _kategoriController = TextEditingController();
  final _catatanController = TextEditingController();

  int _selectedSource = 0; // 0 = Cash, 1 = Digital
  int? _selectedAccount;
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
    return Scaffold(
      backgroundColor: scaffoldBg,
      //header
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            color: appBarBg,
            border: Border(
              bottom: BorderSide(color: primaryGreen, width: 1.5),
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: primaryGreen, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    'Pengeluaran',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 25,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      //body
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: scaffoldBg,
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                'assets/images/bg_curve.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),

          SafeArea(
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
                      if (value == null || value.isEmpty) return 'Jumlah uang tidak boleh kosong';
                      return null;
                    },
                  ),
                  CustomDropdownField(
                    label: 'Kategori',
                    hint: 'Pilih Kategori',
                    value: _selectedKategori,
                    items: const ['Makanan', 'Transportasi', 'Hiburan', 'Elektronik', 'Lainnya'],
                    onChanged: (value) {
                      setState(() {
                        _selectedKategori = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Kategori tidak boleh kosong';
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
      ],
    )
    );
  }
}
