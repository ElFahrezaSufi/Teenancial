import 'package:flutter/material.dart';
import '../widgets/transaction_widgets.dart';

const Color _primaryGreen = Color(0xFF627931);
const Color _scaffoldBg = Color(0xFFEDEFE2);
const Color _appBarBg = Color(0xFFF8FFE8);

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            color: _appBarBg,
            border: Border(
              bottom: BorderSide(color: _primaryGreen, width: 1.5),
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
                          color: _primaryGreen, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    'Transfer',
                    style: TextStyle(
                      color: _primaryGreen,
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: _scaffoldBg,
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
                            color: _primaryGreen,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Transfer ke diri sendiri',
                            style: TextStyle(
                              color: _primaryGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const CustomTextField(
                    label: 'Jumlah Uang',
                    hint: 'Rp 0',
                    keyboardType: TextInputType.number,
                  ),
                  const CustomTextField(
                    label: 'Kategori',
                    hint: 'e.g. Elektronik',
                  ),
                  const CustomTextField(
                    label: 'Catatan',
                    hint: 'Tambah catatan (opsional)',
                  ),

                  // Animasi memunculkan/menghilangkan field "Untuk" & "Simpan ke daftar"
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: !_isSelfTransfer
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CustomTextField(
                                label: 'Untuk',
                                hint: 'Nama teman',
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
                                        color: _primaryGreen,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Simpan ke daftar',
                                        style: TextStyle(
                                          color: _primaryGreen,
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
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
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
