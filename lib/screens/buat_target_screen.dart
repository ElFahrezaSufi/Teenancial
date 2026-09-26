import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: _appBarBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _primaryGreen.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        image: _selectedImage != null
                            ? DecorationImage(
                                image: FileImage(_selectedImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _selectedImage == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined,
                                    size: 40,
                                    color: _primaryGreen.withValues(alpha: 0.7)),
                                const SizedBox(height: 8),
                                Text(
                                  'Ketuk untuk unggah foto',
                                  style: TextStyle(
                                    color: _primaryGreen.withValues(alpha: 0.7),
                                    fontSize: 14,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Barang Target',
                    style: TextStyle(
                      color: _primaryGreen,
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildCustomTextField(
                    controller: _namaBarangController,
                    hintText: 'Contoh: Sepeda, Ipad...',
                    icon: Icons.shopping_bag_outlined,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Perkiraan Harga Barang',
                    style: TextStyle(
                      color: _primaryGreen,
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildCustomTextField(
                    controller: _hargaBarangController,
                    hintText: 'Contoh: 1500000',
                    icon: Icons.payments_outlined,
                    isNumber: true,
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _simpanData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isNumber = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _primaryGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.only(bottom: 2),
      child: Container(
        decoration: BoxDecoration(
          color: _fieldBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _primaryGreen, width: 2),
        ),
        child: TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(
            color: _primaryGreen,
            fontSize: 15,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: _primaryGreen.withValues(alpha: 0.5),
              fontSize: 15,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(icon, color: _primaryGreen, size: 22),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }
}
