import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────
enum JenisDompet { cash, accounts, card }

extension JenisDompetLabel on JenisDompet {
  String get label {
    switch (this) {
      case JenisDompet.cash:
        return 'Cash';
      case JenisDompet.accounts:
        return 'Accounts';
      case JenisDompet.card:
        return 'Card';
    }
  }
}

class DompetItem {
  final String id;
  final JenisDompet jenis;
  final String nama;
  double jumlah;
  final String? catatan;

  DompetItem({
    required this.id,
    required this.jenis,
    required this.nama,
    required this.jumlah,
    this.catatan,
  });
}

class DompetData {
  DompetData._();
  static final DompetData instance = DompetData._();

  final List<DompetItem> items = [
    DompetItem(id: '1', jenis: JenisDompet.cash, nama: 'Cash', jumlah: 0),
    DompetItem(
        id: '2', jenis: JenisDompet.accounts, nama: 'SeaBank', jumlah: 0),
    DompetItem(id: '3', jenis: JenisDompet.accounts, nama: 'Go-Pay', jumlah: 0),
    DompetItem(id: '4', jenis: JenisDompet.accounts, nama: 'Dana', jumlah: 0),
    DompetItem(id: '5', jenis: JenisDompet.accounts, nama: 'Ovo', jumlah: 0),
    DompetItem(id: '6', jenis: JenisDompet.card, nama: 'Mandiri', jumlah: 0),
  ];

  void tambah(DompetItem item) => items.add(item);

  List<DompetItem> byJenis(JenisDompet jenis) =>
      items.where((e) => e.jenis == jenis).toList();

  double get totalSaldo => items.fold(0, (sum, item) => sum + item.jumlah);
}

const Color _primaryGreen = Color(0xFF627931);
const Color _lightGreen = Color(0xFFCADCA4);
const Color _cardBg = Color(0xFFF7FFE7);
const Color _scaffoldBg = Color(0xFFEDEFE2);
const Color _appBarBg = Color(0xFFF8FFE8);

// ─────────────────────────────────────────────
//  DOMPET SCREEN
// ─────────────────────────────────────────────
class DompetScreen extends StatefulWidget {
  const DompetScreen({super.key});

  @override
  State<DompetScreen> createState() => _DompetScreenState();
}

class _DompetScreenState extends State<DompetScreen> {
  final _data = DompetData.instance;

  void _openTambahDompet() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _TambahDompetScreen()),
    );
    if (result == true) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final groupedJenis = [
      JenisDompet.cash,
      JenisDompet.accounts,
      JenisDompet.card,
    ];

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
          child: const SafeArea(
            child: Center(
              child: Text(
                'Dompet',
                style: TextStyle(
                  color: _primaryGreen,
                  fontSize: 25,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Opacity(
            opacity: 0.4,
            child: Image.asset(
              'assets/images/bg_curve.png',
              fit: BoxFit.cover,
            ),
          ),

          // Konten
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Kelompok per jenis
                  ...groupedJenis.map((jenis) {
                    final list = _data.byJenis(jenis);
                    if (list.isEmpty) return const SizedBox.shrink();
                    return _DompetGroup(
                      jenis: jenis,
                      items: list,
                    );
                  }),

                  const SizedBox(height: 16),

                  // Tombol tambah
                  GestureDetector(
                    onTap: _openTambahDompet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _primaryGreen,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            '+ Tambah dompet digital',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
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

// ─────────────────────────────────────────────
//  GROUP PER JENIS
// ─────────────────────────────────────────────
class _DompetGroup extends StatelessWidget {
  final JenisDompet jenis;
  final List<DompetItem> items;

  const _DompetGroup({required this.jenis, required this.items});

  String _formatRupiah(double value) {
    final parts = value.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i != 0 && (parts.length - i) % 3 == 0) buffer.write('.');
      buffer.write(parts[i]);
    }
    return 'Rp ${buffer.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          jenis.label,
          style: const TextStyle(
            color: _primaryGreen,
            fontSize: 14,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _primaryGreen, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.nama,
                    style: const TextStyle(
                      color: _primaryGreen,
                      fontSize: 15,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    item.jumlah == 0
                        ? 'Rp xx.xxx,xx'
                        : _formatRupiah(item.jumlah),
                    style: const TextStyle(
                      color: _primaryGreen,
                      fontSize: 14,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  TAMBAH DOMPET SCREEN
// ─────────────────────────────────────────────
class _TambahDompetScreen extends StatefulWidget {
  const _TambahDompetScreen();

  @override
  State<_TambahDompetScreen> createState() => _TambahDompetScreenState();
}

class _TambahDompetScreenState extends State<_TambahDompetScreen> {
  final _jenisDompetCtrl = TextEditingController();
  final _namaDompetCtrl = TextEditingController();
  final _jumlahCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();

  JenisDompet? _selectedJenis;

  final Map<String, JenisDompet> _jenisMap = {
    'Cash': JenisDompet.cash,
    'Accounts': JenisDompet.accounts,
    'Card': JenisDompet.card,
  };

  @override
  void dispose() {
    _jenisDompetCtrl.dispose();
    _namaDompetCtrl.dispose();
    _jumlahCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  void _simpan() {
    final jenisText = _jenisDompetCtrl.text.trim();
    final nama = _namaDompetCtrl.text.trim();
    final jumlahText = _jumlahCtrl.text.trim();

    if (jenisText.isEmpty || nama.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jenis dan Nama dompet wajib diisi'),
          backgroundColor: _primaryGreen,
        ),
      );
      return;
    }

    // Cek apakah teks jenis cocok dengan salah satu kategori
    final jenis = _selectedJenis ??
        _jenisMap.entries
            .where((e) => jenisText.toLowerCase().contains(e.key.toLowerCase()))
            .map((e) => e.value)
            .firstOrNull ??
        JenisDompet.accounts;

    final jumlah = double.tryParse(
          jumlahText.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;

    DompetData.instance.tambah(DompetItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      jenis: jenis,
      nama: nama,
      jumlah: jumlah,
      catatan:
          _catatanCtrl.text.trim().isEmpty ? null : _catatanCtrl.text.trim(),
    ));

    Navigator.pop(context, true);
  }

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
              alignment: Alignment.center,
              children: [
                // Tombol back
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left,
                        color: _primaryGreen, size: 32),
                  ),
                ),
                // Judul
                const Text(
                  'Tambah Baru',
                  style: TextStyle(
                    color: _primaryGreen,
                    fontSize: 22,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
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
          Opacity(
            opacity: 0.4,
            child: Image.asset(
              'assets/images/bg_curve.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Jenis Dompet
                  _FieldLabel(label: 'Jenis Dompet'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _showJenisPicker,
                    child: AbsorbPointer(
                      child: _InputField(
                        controller: _jenisDompetCtrl,
                        hint: 'Cash, card, accounts, etc',
                        suffixIcon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _primaryGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Nama Dompet
                  _FieldLabel(label: 'Nama Dompet'),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _namaDompetCtrl,
                    hint: 'Opsional',
                  ),
                  const SizedBox(height: 20),

                  // Jumlah Uang
                  _FieldLabel(label: 'Jumlah Uang'),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _jumlahCtrl,
                    hint: 'Rp 0',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    prefixText: 'Rp ',
                  ),
                  const SizedBox(height: 20),

                  // Catatan
                  _FieldLabel(label: 'Catatan'),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _catatanCtrl,
                    hint: 'Opsional',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),

                  // Tombol Simpan
                  GestureDetector(
                    onTap: _simpan,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: _primaryGreen,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'Simpan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showJenisPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _appBarBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _lightGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pilih Jenis Dompet',
              style: TextStyle(
                color: _primaryGreen,
                fontSize: 16,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ..._jenisMap.entries.map(
              (e) => ListTile(
                title: Text(
                  e.key,
                  style: const TextStyle(
                    color: _primaryGreen,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: _selectedJenis == e.value
                    ? const Icon(Icons.check, color: _primaryGreen)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedJenis = e.value;
                    _jenisDompetCtrl.text = e.key;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  WIDGET HELPERS
// ─────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _primaryGreen,
        fontSize: 14,
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final Widget? suffixIcon;
  final int maxLines;

  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.prefixText,
    this.suffixIcon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primaryGreen, width: 2),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        style: const TextStyle(
          color: _primaryGreen,
          fontSize: 14,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: _primaryGreen.withValues(alpha: 0.45),
            fontFamily: 'Inter',
            fontSize: 14,
          ),
          prefixText: prefixText,
          prefixStyle: const TextStyle(
            color: _primaryGreen,
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
