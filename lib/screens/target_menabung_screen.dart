import 'dart:io';
import 'package:flutter/material.dart';
import '../data/target_model.dart';
import '../data/dompet_model.dart';
import '../theme/app_colors.dart';
import '../widgets/common/custom_card.dart';
import 'buat_target_screen.dart';

class TargetMenabungScreen extends StatefulWidget {
  const TargetMenabungScreen({super.key});

  @override
  State<TargetMenabungScreen> createState() => _TargetMenabungScreenState();
}

class _TargetMenabungScreenState extends State<TargetMenabungScreen> {
  final _data = TargetData.instance;

  Future<void> _navigasiDanTambahData(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BuatTargetScreen(),
      ),
    );

    if (result != null) {
      setState(() {
        double harga = double.tryParse(
                result['harga'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ??
            0.0;

        _data.items.add(
          TargetItem(
            nama: result['nama'],
            targetAmount: harga,
            imageUrl: result['imagePath'],
            isPinned: false,
          ),
        );
      });
    }
  }

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
                      icon: const Icon(Icons.arrow_back_ios,
                          color: primaryGreen, size: 20),
                      onPressed: () => Navigator.pop(context),
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
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_data.items.isEmpty)
                    _buildEmptyState()
                  else
                    ..._data.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: _buildTargetCard(item),
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _data.items.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 140.0),
              child: FloatingActionButton(
                onPressed: () => _navigasiDanTambahData(context),
                backgroundColor: primaryGreen,
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100)),
                child: const Icon(Icons.add, color: Colors.white, size: 30),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return CustomCard(
      backgroundColor: appBarBg,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 60,
            color: primaryGreen.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada target impian nih!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primaryGreen,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yuk mulai tabung uangmu untuk beli barang impianmu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primaryGreen.withValues(alpha: 0.7),
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _navigasiDanTambahData(context),
            child: CustomCard(
              borderRadius: 100,
              backgroundColor: primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Buat Target Baru',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
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

  Widget _buildTargetCard(TargetItem item) {
    final double saldoSekarang = DompetData.instance.totalSaldo;
    final double progress = item.targetAmount > 0
        ? (saldoSekarang / item.targetAmount).clamp(0.0, 1.0)
        : 0.0;

    final String terkumpulStr = _formatRupiah(saldoSekarang);
    final String targetStr = _formatRupiah(item.targetAmount);

    return CustomCard(
      backgroundColor: cardBg,
      borderRadius: 20,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
                child: Image.file(
                  File(item.imageUrl),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                      height: 160,
                      color: Colors.grey[300],
                      child:
                          const Icon(Icons.broken_image, color: Colors.grey)),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2))
                      ]),
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert,
                        color: primaryGreen, size: 20),
                    color: appBarBg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final bool? confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Hapus Target', style: TextStyle(color: primaryGreen)),
                            content: const Text('Apakah Anda yakin ingin menghapus target ini?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          setState(() {
                            _data.items.remove(item);
                          });
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Hapus Target',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (item.isPinned) {
                        item.isPinned = false;
                      } else {
                        _data.pinItem(item);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.isPinned
                          ? const Color(0xFFDAB62C).withValues(alpha: 0.2)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 24,
                      color:
                          item.isPinned ? const Color(0xFFDAB62C) : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nama,
                        style: const TextStyle(
                          color: primaryGreen,
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$terkumpulStr / $targetStr',
                        style: TextStyle(
                          color: primaryGreen.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: lightGreen,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
