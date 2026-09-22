import 'package:flutter/material.dart';
import '../widgets/transaction_widgets.dart';

const Color _primaryGreen = Color(0xFF627931);
const Color _scaffoldBg = Color(0xFFEDEFE2);
const Color _appBarBg = Color(0xFFF8FFE8);

class PengeluaranScreen extends StatefulWidget {
  const PengeluaranScreen({super.key});

  @override
  State<PengeluaranScreen> createState() => _PengeluaranScreenState();
}

class _PengeluaranScreenState extends State<PengeluaranScreen> {
  int _selectedSource = 0; // 0 = Cash, 1 = Digital
  int? _selectedAccount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      //header
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
                    'Pengeluaran',
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

      //body
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
                  const SizedBox(height: 24),
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
}
