import 'dart:io';
import 'package:flutter/material.dart';
import '../data/mock_auth.dart';
import '../data/dompet_model.dart';
import '../data/target_model.dart';
import '../widgets/common/custom_card.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

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
      try {
        final cashItem = DompetData.instance.items
            .firstWhere((e) => e.jenis == JenisDompet.cash);
        cashItem.jumlah += 50000;
      } catch (e) {
        // Jika tidak ada item cash, amannya dilewati
      }

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
    final double totalSaldoReal = DompetData.instance.totalSaldo;
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Halo $displayName !',
                                        style: AppTextStyles.headerName),
                                    Text('level $level',
                                        style: AppTextStyles.headerLevel),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 24),
                                child: GestureDetector(
                                  onTap: () async {
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
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: inputBg,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: primaryGreen, width: 2),
                                      image: ProfileScreen.profileImage != null
                                          ? DecorationImage(
                                              image: FileImage(
                                                  ProfileScreen.profileImage!),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: ProfileScreen.profileImage == null
                                        ? const Icon(Icons.person,
                                            color: primaryGreen, size: 30)
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Total Saldo Card (Membaca Saldo Asli)
                          GestureDetector(
                            onTap: _tambahTabunganMock,
                            child: CustomCard(
                              backgroundColor: cardBg,
                              borderRadius: 24,
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Saldo',
                                      style: AppTextStyles.sectionTitle),
                                  const SizedBox(height: 4),
                                  Text(_formatRupiah(totalSaldoReal),
                                      style: AppTextStyles.balanceText),
                                  const SizedBox(height: 16),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                        value: xpProgress,
                                        backgroundColor: lightGreen,
                                        color: primaryGreen,
                                        minHeight: 8),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                      '$currentXP/$maxXP xp menuju level ${level + 1}',
                                      style: AppTextStyles.captionGreen),
                                  const SizedBox(height: 16),

                                  // Perkiraan Minggu Depan
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color:
                                          primaryGreen.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Image.asset(
                                              'assets/images/perkiraan.png',
                                              width: 16,
                                              height: 16,
                                              color: iconLightGreen,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text('Perkiraan Minggu Depan',
                                                style: TextStyle(
                                                    color: iconLightGreen,
                                                    fontSize: 12,
                                                    fontFamily: 'Inter',
                                                    fontWeight:
                                                        FontWeight.w500)),
                                          ],
                                        ),
                                        Text(
                                            _formatRupiah(
                                                perkiraanMingguanReal),
                                            style: const TextStyle(
                                                color: iconLightGreen,
                                                fontSize: 12,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Menu Action
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ActionMenu(
                                assetPath: 'assets/images/pemasukan.svg',
                                label: 'Pemasukan',
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const PemasukanScreen())),
                              ),
                              ActionMenu(
                                assetPath: 'assets/images/pengeluaran.svg',
                                label: 'Pengeluaran',
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const PengeluaranScreen())),
                              ),
                              ActionMenu(
                                assetPath: 'assets/images/pinjaman.svg',
                                label: 'Pinjaman',
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const PinjamanScreen())),
                              ),
                              ActionMenu(
                                assetPath: 'assets/images/transfer.png',
                                label: 'Transfer',
                                iconPadding: const EdgeInsets.only(left: 4.0),
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const TransferScreen())),
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

                          currentTarget != null
                              ? Column(
                                  children: [
                                    CustomCard(
                                      backgroundColor: cardBg,
                                      borderRadius: 20,
                                      padding: EdgeInsets.zero,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                const BorderRadius.only(
                                              topLeft: Radius.circular(18),
                                              topRight: Radius.circular(18),
                                            ),
                                            child: Image.file(
                                              File(currentTarget.imageUrl),
                                              height: 167,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error,
                                                      stackTrace) =>
                                                  Container(
                                                      height: 167,
                                                      color: Colors.grey[300],
                                                      child: const Icon(
                                                          Icons.broken_image,
                                                          color: Colors.grey)),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 16,
                                                right: 16,
                                                top: 16,
                                                bottom: 12),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(currentTarget.nama,
                                                    style: AppTextStyles
                                                        .sectionTitle),
                                                Text(
                                                  '${_formatRupiah(totalSaldoReal)}/ ${_formatRupiah(currentTarget.targetAmount)}',
                                                  style: const TextStyle(
                                                      color: primaryGreen,
                                                      fontSize: 12,
                                                      fontFamily: 'Inter',
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 16,
                                                right: 16,
                                                bottom: 20),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                              child: LinearProgressIndicator(
                                                value: currentTarget
                                                            .targetAmount >
                                                        0
                                                    ? (totalSaldoReal /
                                                            currentTarget
                                                                .targetAmount)
                                                        .clamp(0.0, 1.0)
                                                    : 0.0,
                                                backgroundColor: lightGreen,
                                                color: primaryGreen,
                                                minHeight: 6,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    GestureDetector(
                                      onTap: _tambahTargetData,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8.0),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.add,
                                                size: 16,
                                                color: Color(0xFFDAB62C)),
                                            const SizedBox(width: 4),
                                            const Text(
                                              'Buat Target Baru',
                                              style: TextStyle(
                                                color: Color(0xFFDAB62C),
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : CustomCard(
                                  backgroundColor: cardBg,
                                  borderRadius: 20,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 32, horizontal: 20),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.receipt_long_outlined,
                                        size: 60,
                                        color:
                                            primaryGreen.withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text('Belum ada target impian nih!',
                                          style: AppTextStyles.sectionTitle),
                                      const SizedBox(height: 4),
                                      const Text(
                                          'Yuk mulai tabung uangmu untuk beli barang impianmu.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                              fontFamily: 'Inter')),
                                      const SizedBox(height: 16),
                                      GestureDetector(
                                        onTap: _tambahTargetData,
                                        child: CustomCard(
                                          borderRadius: 100,
                                          backgroundColor: primaryGreen,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 14),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.add,
                                                  size: 18,
                                                  color: Colors.white),
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
                                      )
                                    ],
                                  ),
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
