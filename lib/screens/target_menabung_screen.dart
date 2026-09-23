import 'package:flutter/material.dart';

const Color _primaryGreen = Color(0xFF627931);
const Color _scaffoldBg = Color(0xFFEDEFE2);
const Color _appBarBg = Color(0xFFF8FFE8);
const Color _cardBg = Color(0xFFF7FFE7);
const Color _progressBarBg = Color(0xFFCADCA4);

class TargetItem {
  final String nama;
  final String nominalTerkumpul;
  final String nominalTarget;
  final String imageUrl;
  final double progress;
  bool isPinned;

  TargetItem({
    required this.nama,
    required this.nominalTerkumpul,
    required this.nominalTarget,
    required this.imageUrl,
    required this.progress,
    this.isPinned = false,
  });
}

class TargetMenabungScreen extends StatefulWidget {
  const TargetMenabungScreen({super.key});

  @override
  State<TargetMenabungScreen> createState() => _TargetMenabungScreenState();
}

class _TargetMenabungScreenState extends State<TargetMenabungScreen> {
  List<TargetItem> daftarTarget = [];

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
                  if (daftarTarget.isEmpty)
                    _buildEmptyState()
                  else
                    ...daftarTarget.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: _buildTargetCard(item),
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: daftarTarget.isNotEmpty
          ? FloatingActionButton(
              onPressed: () {
                // TODO: Navigasi ke BuatTargetScreen
              },
              backgroundColor: _primaryGreen,
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: _appBarBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryGreen.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 60,
            color: _primaryGreen.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada target impian nih!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _primaryGreen,
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
              color: _primaryGreen.withOpacity(0.7),
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Arahkan ke screen buat_target_screen.dart di sini
            },
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: const Text(
              'Buat Target Baru',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetCard(TargetItem item) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primaryGreen, width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _primaryGreen, width: 2),
                image: DecorationImage(
                  image: NetworkImage(item.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          item.isPinned = !item.isPinned;
                        });
                      },
                      child: Icon(
                        Icons.push_pin,
                        size: 20,
                        color: item.isPinned
                            ? const Color(0xFFFBBF24)
                            : _primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.nama,
                      style: const TextStyle(
                        color: _primaryGreen,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Text(
                    '${item.nominalTerkumpul}/ ${item.nominalTarget}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: _primaryGreen,
                      fontSize: 12,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: _progressBarBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: item.progress,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: _primaryGreen,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
