import 'package:flutter/material.dart';
import '../data/dompet_model.dart';
import '../theme/app_colors.dart';
import '../widgets/common/custom_card.dart';
import 'tambah_dompet_screen.dart';

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
      MaterialPageRoute(builder: (_) => const TambahDompetScreen()),
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
          child: const SafeArea(
            child: Center(
              child: Text(
                'Dompet',
                style: TextStyle(
                  color: primaryGreen,
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
          Opacity(
            opacity: 0.4,
            child: Image.asset(
              'assets/images/bg_curve.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...groupedJenis.map((jenis) {
                    final list = _data.byJenis(jenis);
                    if (list.isEmpty) return const SizedBox.shrink();
                    return _DompetGroup(
                      jenis: jenis,
                      items: list,
                    );
                  }),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _openTambahDompet,
                    child: CustomCard(
                      borderRadius: 100,
                      backgroundColor: primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: const Center(
                        child: Text(
                          '+ Tambah dompet digital',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
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
            color: primaryGreen,
            fontSize: 14,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CustomCard(
              backgroundColor: cardBg,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.nama,
                    style: const TextStyle(
                      color: primaryGreen,
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
                      color: primaryGreen,
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
