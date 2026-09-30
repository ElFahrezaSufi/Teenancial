import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/dompet_model.dart';
import '../theme/app_colors.dart';
import '../widgets/common/custom_card.dart';

class TambahDompetScreen extends StatefulWidget {
  const TambahDompetScreen({super.key});

  @override
  State<TambahDompetScreen> createState() => _TambahDompetScreenState();
}

class _TambahDompetScreenState extends State<TambahDompetScreen> {
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
          backgroundColor: primaryGreen,
        ),
      );
      return;
    }

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
      backgroundColor: scaffoldBg,
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
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left,
                        color: primaryGreen, size: 32),
                  ),
                ),
                const Text(
                  'Tambah Baru',
                  style: TextStyle(
                    color: primaryGreen,
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
                  const _FieldLabel(label: 'Jenis Dompet'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _showJenisPicker,
                    child: AbsorbPointer(
                      child: _InputField(
                        controller: _jenisDompetCtrl,
                        hint: 'Cash, card, accounts, etc',
                        suffixIcon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: primaryGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _FieldLabel(label: 'Nama Dompet'),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _namaDompetCtrl,
                    hint: 'Opsional',
                  ),
                  const SizedBox(height: 20),
                  const _FieldLabel(label: 'Jumlah Uang'),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _jumlahCtrl,
                    hint: 'Rp 0',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    prefixText: 'Rp ',
                  ),
                  const SizedBox(height: 20),
                  const _FieldLabel(label: 'Catatan'),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _catatanCtrl,
                    hint: 'Opsional',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  GestureDetector(
                    onTap: _simpan,
                    child: CustomCard(
                      borderRadius: 100,
                      backgroundColor: primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 18),
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
      backgroundColor: appBarBg,
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
                color: lightGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pilih Jenis Dompet',
              style: TextStyle(
                color: primaryGreen,
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
                    color: primaryGreen,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: _selectedJenis == e.value
                    ? const Icon(Icons.check, color: primaryGreen)
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

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: primaryGreen,
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
    return CustomCard(
      backgroundColor: cardBg,
      padding: EdgeInsets.zero,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        style: const TextStyle(
          color: primaryGreen,
          fontSize: 14,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: primaryGreen.withValues(alpha: 0.45),
            fontFamily: 'Inter',
            fontSize: 14,
          ),
          prefixText: prefixText,
          prefixStyle: const TextStyle(
            color: primaryGreen,
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