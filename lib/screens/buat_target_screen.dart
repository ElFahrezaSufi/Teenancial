import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/target_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../utils/error_mapper.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/common/custom_text_field.dart';

class BuatTargetScreen extends StatefulWidget {
  const BuatTargetScreen({super.key});

  @override
  State<BuatTargetScreen> createState() => _BuatTargetScreenState();
}

class _BuatTargetScreenState extends State<BuatTargetScreen> {
  final _namaBarangController = TextEditingController();
  final _hargaBarangController = TextEditingController();
  File? _selectedImage;
  bool _isSaving = false;

  @override
  void dispose() {
    _namaBarangController.dispose();
    _hargaBarangController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isSaving) return;
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
      debugPrint('Gagal mengambil gambar: $e');
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

  Future<void> _simpanData() async {
    if (_isSaving) return;
    final nama = _namaBarangController.text.trim();
    final hargaText = _hargaBarangController.text.trim();
    final double harga = double.tryParse(
          hargaText.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0.0;

    if (nama.isEmpty || harga <= 0 || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tolong isi semua data dan pilih foto barang impian!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<TargetProvider>().createTarget(
            nama: nama,
            targetAmount: harga,
            imageFile: _selectedImage!,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Target menabung berhasil disimpan!'),
          backgroundColor: primaryGreen,
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Gagal menyimpan target: ${ErrorMapper.message(e)}',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: primaryGreen,
                        size: 20,
                      ),
                      onPressed: _isSaving ? null : () => context.pop(),
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    'Target Menabung',
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
                    'Foto Barang Impian *',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickImage,
                    child: CustomCard(
                      backgroundColor: appBarBg,
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
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 40,
                                    color:
                                        primaryGreen.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Ketuk untuk unggah foto (Wajib)',
                                    style: TextStyle(
                                      color:
                                          primaryGreen.withValues(alpha: 0.7),
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
                    prefixIcon: const Icon(
                      Icons.shopping_bag_outlined,
                      color: primaryGreen,
                    ),
                    controller: _namaBarangController,
                  ),
                  const SizedBox(height: 24),
                  CustomTextField(
                    label: 'Perkiraan Harga Barang',
                    hint: 'Rp 0',
                    prefixIcon: const Icon(
                      Icons.payments_outlined,
                      color: primaryGreen,
                    ),
                    keyboardType: TextInputType.number,
                    controller: _hargaBarangController,
                    inputFormatters: [CurrencyInputFormatter()],
                  ),
                  const SizedBox(height: 48),
                  GestureDetector(
                    onTap: _isSaving ? null : _simpanData,
                    child: CustomCard(
                      borderRadius: 100,
                      backgroundColor:
                          _isSaving ? Colors.grey : primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: _isSaving
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: inputBg,
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Mengunggah & Menyimpan...',
                                    style: TextStyle(
                                      color: inputBg,
                                      fontSize: 15,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                'Simpan',
                                style: TextStyle(
                                  color: inputBg,
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
