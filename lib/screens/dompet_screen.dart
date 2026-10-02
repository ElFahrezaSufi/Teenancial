import 'package:flutter/material.dart';
import '../data/sim_settings.dart';
import '../data/dompet_model.dart';
import '../repositories/dompet_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/common/skeleton.dart';
import 'tambah_dompet_screen.dart';

enum _LoadState { loading, success, error, empty }

class DompetScreen extends StatefulWidget {
  const DompetScreen({super.key});

  @override
  State<DompetScreen> createState() => _DompetScreenState();
}

class _DompetScreenState extends State<DompetScreen> {
  _LoadState _loadState = _LoadState.loading;
  String _errorMessage = '';
  List<DompetItem> _dompets = [];

  @override
  void initState() {
    super.initState();
    SimSettings.forceError.addListener(_onSimChanged);
    _loadData();
  }

  @override
  void dispose() {
    SimSettings.forceError.removeListener(_onSimChanged);
    super.dispose();
  }

  void _onSimChanged() {
    if (mounted) _loadData();
  }

  Future<void> _loadData({bool simulateError = false}) async {
    setState(() => _loadState = _LoadState.loading);
    try {
      final data = await DompetRepository.instance.getDompets(simulateError: simulateError);
      if (mounted) {
        setState(() {
          _dompets = data;
          _loadState = data.isEmpty ? _LoadState.empty : _LoadState.success;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _loadState = _LoadState.error;
        });
      }
    }
  }

  void _openTambahDompet([DompetItem? item]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TambahDompetScreen(itemToEdit: item)),
    );
    if (result == true) _loadData();
  }

  Widget _buildLoading() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Skeleton(width: 100, height: 16),
            const SizedBox(height: 10),
            const Skeleton(width: double.infinity, height: 70),
            const SizedBox(height: 10),
            const Skeleton(width: double.infinity, height: 70),
            const SizedBox(height: 24),
            const Skeleton(width: 100, height: 16),
            const SizedBox(height: 10),
            const Skeleton(width: double.infinity, height: 70),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Oops, terjadi kesalahan!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
              ),
              onPressed: () => _loadData(),
              child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 80, color: primaryGreen.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'Dompet masih kosong',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen),
            ),
            const SizedBox(height: 8),
            const Text(
              'Yuk tambahkan dompet pertamamu sekarang!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
              ),
              onPressed: () => _openTambahDompet(),
              child: const Text('Tambah Dompet', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
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
          if (_loadState == _LoadState.loading) _buildLoading(),
          if (_loadState == _LoadState.error) _buildError(),
          if (_loadState == _LoadState.empty) _buildEmpty(),
          if (_loadState == _LoadState.success)
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...groupedJenis.map((jenis) {
                      final list = _dompets.where((e) => e.jenis == jenis).toList();
                      if (list.isEmpty) return const SizedBox.shrink();
                      return _DompetGroup(
                        jenis: jenis,
                        items: list,
                        onItemTap: _openTambahDompet,
                      );
                    }),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => _openTambahDompet(),
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
  final Function(DompetItem) onItemTap;

  const _DompetGroup({required this.jenis, required this.items, required this.onItemTap});

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
            child: GestureDetector(
              onTap: () => onItemTap(item),
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
                    Row(
                      children: [
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
                        const SizedBox(width: 8),
                        const Icon(Icons.edit_outlined, size: 16, color: primaryGreen),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
