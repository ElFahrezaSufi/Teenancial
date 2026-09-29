import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/common/custom_card.dart';
import '../utils/currency_formatter.dart';

const Color _primaryGreen = Color(0xFF627931);
const Color _scaffoldBg = Color(0xFFEDEFE2);
const Color _appBarBg = Color(0xFFF8FFE8);
const Color _fieldBg = Color(0xFFF8FFE8);

class BuatTargetScreen extends StatefulWidget {
  const BuatTargetScreen({super.key});

  @override
  State<BuatTargetScreen> createState() => _BuatTargetScreenState();
}

class _BuatTargetScreenState extends State<BuatTargetScreen> {
  final _namaBarangController = TextEditingController();
  final _hargaBarangController = TextEditingController();
  File? _selectedImage;

  @override
  void dispose() {
    _namaBarangController.dispose();
    _hargaBarangController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (!mounted) return;
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint("Gagal mengambil gambar: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terjadi kesalahan saat membuka galeri.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _simpanData() {
    final nama = _namaBarangController.text.trim();
    final harga = _hargaBarangController.text.trim();

    if (nama.isEmpty || harga.isEmpty || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tolong isi semua data dan pilih gambar!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final dataTargetBaru = {
      'nama': nama,
      'harga': harga,
      'imagePath': _selectedImage!.path,
    };

    Navigator.pop(context, dataTargetBaru);
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
                    'Target Menabung',
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
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Foto Barang Impian',
                    style: TextStyle(
                      color: _primaryGreen,
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickImage,
                    child: CustomCard(
                      backgroundColor: _appBarBg,
                      borderRadius: 16,
                      padding: EdgeInsets.zero,
                      child: SizedBox(
                        height: 160,
                        child: _selectedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined,
                                      size: 40,
                                      color:
                                          _primaryGreen.withValues(alpha: 0.7)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Ketuk untuk unggah foto',
                                    style: TextStyle(
                                      color:
                                          _primaryGreen.withValues(alpha: 0.7),
                                      fontSize: 14,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomTextField(
                    label: 'Barang Target',
                    hint: 'Contoh: Sepeda, Ipad...',
                    prefixIcon: const Icon(Icons.shopping_bag_outlined,
                        color: _primaryGreen),
                    controller: _namaBarangController,
                  ),
                  const SizedBox(height: 24),
                  CustomTextField(
                    label: 'Perkiraan Harga Barang',
                    hint: 'Rp 0',
                    prefixIcon: const Icon(Icons.payments_outlined,
                        color: _primaryGreen),
                    keyboardType: TextInputType.number,
                    controller: _hargaBarangController,
                    inputFormatters: [CurrencyInputFormatter()],
                  ),
                  const SizedBox(height: 48),
                  GestureDetector(
                    onTap: _simpanData,
                    child: CustomCard(
                      borderRadius: 100,
                      backgroundColor: _primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: const Center(
                        child: Text(
                          'Simpan',
                          style: TextStyle(
                            color: _fieldBg,
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
}
