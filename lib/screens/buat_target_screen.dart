import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/target_model.dart';
import '../providers/target_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../utils/error_mapper.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/common/date_picker_field.dart';
import '../widgets/common/target_image.dart';

class BuatTargetScreen extends StatefulWidget {
  final TargetItem? targetToEdit;

  const BuatTargetScreen({
    super.key,
    this.targetToEdit,
  });

  @override
  State<BuatTargetScreen> createState() => _BuatTargetScreenState();
}

class _BuatTargetScreenState extends State<BuatTargetScreen> {
  final _namaBarangController = TextEditingController();
  final _hargaBarangController = TextEditingController();
  File? _selectedImage;
  DateTime? _selectedDeadline;
  bool _isSaving = false;

  bool get _isEdit => widget.targetToEdit != null;

  @override
  void initState() {
    super.initState();
    final target = widget.targetToEdit;
    if (target != null) {
      _namaBarangController.text = target.nama;
      _hargaBarangController.text = CurrencyInputFormatter.formatValue(
        target.targetAmount.toStringAsFixed(0),
      );
      _selectedDeadline = target.deadline;
    }
  }

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

    if (nama.isEmpty || harga <= 0 || (!_isEdit && _selectedImage == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Tolong isi nama dan nominal target menabung dengan benar!'
                : 'Tolong isi semua data dan pilih foto barang impian!',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_isEdit && harga + 0.0001 < widget.targetToEdit!.savedAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nominal target tidak boleh di bawah dana terkumpul (${Formatters.rupiah(widget.targetToEdit!.savedAmount)}). Tarik sebagian dana terlebih dahulu.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_selectedDeadline != null) {
      final oldDeadline = widget.targetToEdit?.deadline;
      final isUnchangedLegacyDeadline = oldDeadline != null &&
          DateHelper.dateOnly(_selectedDeadline!) ==
              DateHelper.dateOnly(oldDeadline);
      if (!isUnchangedLegacyDeadline &&
          DateHelper.daysBetween(DateTime.now(), _selectedDeadline!) < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tenggat tidak boleh sebelum hari ini.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final provider = context.read<TargetProvider>();
      if (_isEdit) {
        final existing = widget.targetToEdit!;
        final bool clearDeadline =
            existing.deadline != null && _selectedDeadline == null;
        await provider.updateTarget(
          targetId: existing.id,
          nama: nama,
          targetAmount: harga,
          newImageFile: _selectedImage,
          deadline: _selectedDeadline,
          clearDeadline: clearDeadline,
        );
      } else {
        await provider.createTarget(
          nama: nama,
          targetAmount: harga,
          imageFile: _selectedImage!,
          deadline: _selectedDeadline,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? '✅ Target menabung berhasil diperbarui!'
                : '✅ Target menabung berhasil disimpan!',
          ),
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

  Widget _buildImagePreview() {
    if (_selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(
          _selectedImage!,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      );
    }
    if (_isEdit && widget.targetToEdit!.imageUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: TargetImage(
              imageUrl: widget.targetToEdit!.imageUrl,
              height: 160,
            ),
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_camera_outlined, color: Colors.white, size: 15),
                  SizedBox(width: 6),
                  Text(
                    'Ketuk untuk ganti foto',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_a_photo_outlined,
          size: 40,
          color: primaryGreen.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 8),
        Text(
          'Ketuk untuk unggah foto (Wajib)',
          style: TextStyle(
            color: primaryGreen.withValues(alpha: 0.7),
            fontSize: 14,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: CustomAppBar(
        title: _isEdit ? 'Edit Target' : 'Target Menabung',
        onBack: _isSaving ? () {} : () => context.pop(),
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
                  Text(
                    _isEdit ? 'Foto Barang Impian' : 'Foto Barang Impian *',
                    style: const TextStyle(
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
                        child: _buildImagePreview(),
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
                  const SizedBox(height: 8),
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
                  if (_isEdit && widget.targetToEdit!.savedAmount > 0) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, left: 4),
                      child: Text(
                        'Dana sudah terkumpul: ${Formatters.rupiah(widget.targetToEdit!.savedAmount)}',
                        style: TextStyle(
                          color: primaryGreen.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ] else
                    const SizedBox(height: 8),
                  DatePickerField(
                    label: 'Tenggat Waktu (Opsional)',
                    hint: 'Pilih tanggal tenggat (bebas dikosongkan)',
                    value: _selectedDeadline,
                    firstDate: DateTime.now(),
                    clearable: true,
                    onChanged: (picked) =>
                        setState(() => _selectedDeadline = picked),
                  ),
                  const SizedBox(height: 32),
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
                                    'Menyimpan...',
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
