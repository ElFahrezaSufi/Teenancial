import 'package:flutter/material.dart';
import '../data/mock_auth.dart';
import '../repositories/dompet_repository.dart';
import '../data/target_model.dart';
import '../theme/app_colors.dart';

import 'profile_screen.dart';
import 'pemasukan_screen.dart';
import 'pengeluaran_screen.dart';
import 'pinjaman_screen.dart';
import 'transfer_screen.dart';
import 'target_menabung_screen.dart';
import 'buat_target_screen.dart';
import 'ruang_belajar_screen.dart';
import 'tanya_feen_screen.dart';

import '../widgets/home/action_menu.dart';
import '../widgets/home/section_header.dart';
import '../widgets/home/belajar_card.dart';
import '../widgets/home/profile_header.dart';
import '../widgets/home/total_saldo_card.dart';
import '../widgets/home/target_menabung_home.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String displayName = 'Pengguna';

  int currentXP = 0;
  int maxXP = 1000;
  int level = 1;

  double _feenX = 0;
  double _feenY = 0;
  bool _isFeenInitialized = false;
  bool _isDraggingFeen = false;

  static const double _feenButtonWidth = 84.0;
  static const double _feenBottomMargin = 220.0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isFeenInitialized) {
      final size = MediaQuery.of(context).size;
      _feenX = size.width - _feenButtonWidth;
      _feenY = size.height - _feenBottomMargin;
      _isFeenInitialized = true;
    }
  }

  void _loadUserData() {
    setState(() {
      displayName = MockAuth.activeUserName.isNotEmpty
          ? MockAuth.activeUserName
          : 'Pengguna';
    });
  }

  void _tambahTabunganMock() {
    setState(() {
      currentXP += 50;
      if (currentXP >= maxXP) {
        level++;
        currentXP = currentXP - maxXP;
        maxXP = (maxXP * 1.5).toInt();
      }
    });
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _loadUserData();
    });
  }

  Future<void> _tambahTargetData() async {
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
        TargetData.instance.items.add(
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
    final double topPadding = MediaQuery.of(context).padding.top;
    final double xpProgress =
        maxXP > 0 ? (currentXP / maxXP).clamp(0.0, 1.0) : 0.0;
    final double totalSaldoReal = DompetRepository.instance.totalSaldo;
    final double perkiraanMingguanReal =
        totalSaldoReal + (totalSaldoReal * 0.02);

    final TargetItem? currentTarget = TargetData.instance.pinnedItem;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: primaryGreen,
              backgroundColor: scaffoldBg,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                child: Stack(
                  children: [
                    Image.asset(
                      'assets/images/stenga_lingkaran.png',
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: topPadding + 20),

                          // Header: Profil & Level
                          ProfileHeader(
                            displayName: displayName,
                            level: level,
                            onProfileTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const ProfileScreen()),
                              );
                              setState(() {
                                _loadUserData();
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // Total Saldo Card
                          TotalSaldoCard(
                            totalSaldoReal: totalSaldoReal,
                            perkiraanMingguanReal: perkiraanMingguanReal,
                            xpProgress: xpProgress,
                            currentXP: currentXP,
                            maxXP: maxXP,
                            level: level,
                            formatRupiah: _formatRupiah,
                            onTap: _tambahTabunganMock,
                          ),
                          const SizedBox(height: 32),

                          // Menu Action
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ActionMenu(
                                assetPath: 'assets/images/pemasukan.svg',
                                label: 'Pemasukan',
                                onTap: () async {
                                  await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const PemasukanScreen()));
                                  if (mounted) setState(() {});
                                },
                              ),
                              ActionMenu(
                                assetPath: 'assets/images/pengeluaran.svg',
                                label: 'Pengeluaran',
                                onTap: () async {
                                  await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const PengeluaranScreen()));
                                  if (mounted) setState(() {});
                                },
                              ),
                              ActionMenu(
                                assetPath: 'assets/images/pinjaman.svg',
                                label: 'Pinjaman',
                                onTap: () async {
                                  await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const PinjamanScreen()));
                                  if (mounted) setState(() {});
                                },
                              ),
                              ActionMenu(
                                assetPath: 'assets/images/transfer.png',
                                label: 'Transfer',
                                iconPadding: const EdgeInsets.only(left: 4.0),
                                onTap: () async {
                                  await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const TransferScreen()));
                                  if (mounted) setState(() {});
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Target Menabung
                          SectionHeader(
                            title: 'Target Menabung',
                            actionText: 'Lihat Semua',
                            onActionTap: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const TargetMenabungScreen()));
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 12),

                          TargetMenabungHome(
                            currentTarget: currentTarget,
                            totalSaldoReal: totalSaldoReal,
                            formatRupiah: _formatRupiah,
                            onTambahTarget: _tambahTargetData,
                          ),
                          const SizedBox(height: 24),

                          // Ruang Belajar
                          SectionHeader(
                            title: 'Ruang Belajar',
                            actionText: 'Lihat Semua',
                            onActionTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const RuangBelajarScreen())),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const RuangBelajarScreen())),
                            child: BelajarCard(),
                          ),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Floating button Tanya Feen
          AnimatedPositioned(
            duration: _isDraggingFeen
                ? Duration.zero
                : const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            left: _feenX,
            top: _feenY,
            child: GestureDetector(
              onPanStart: (details) {
                setState(() => _isDraggingFeen = true);
              },
              onPanUpdate: (details) {
                setState(() {
                  _feenX += details.delta.dx;
                  _feenY += details.delta.dy;
                  _feenX =
                      _feenX.clamp(0.0, MediaQuery.of(context).size.width - 80);
                  _feenY = _feenY.clamp(0.0,
                      MediaQuery.of(context).size.height - _feenBottomMargin);
                });
              },
              onPanEnd: (details) {
                setState(() {
                  _isDraggingFeen = false;
                  final screenWidth = MediaQuery.of(context).size.width;
                  final centerScreen = screenWidth / 2;

                  if (_feenX + 30 < centerScreen) {
                    _feenX = 24.0;
                  } else {
                    _feenX = screenWidth - _feenButtonWidth;
                  }
                });
              },
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const TanyaFeenScreen()));
              },
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                        color: feenButtonBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryGreen, width: 2)),
                    child: const Center(
                        child: Text('?',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800))),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryGreen, width: 1)),
                    child: const Text(
                      'Tanya Feen',
                      style: TextStyle(
                          color: primaryGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
