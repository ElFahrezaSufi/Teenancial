import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../data/mock_auth.dart';
import 'profile_screen.dart';
import 'pemasukan_screen.dart';
import 'pengeluaran_screen.dart';
import 'pinjaman_screen.dart';
import 'transfer_screen.dart';
import 'target_menabung_screen.dart';
import 'buat_target_screen.dart';
import 'ruang_belajar_screen.dart';
import 'tanya_feen_screen.dart';

const Color _primaryGreen = Color(0xFF627931);
const Color _lightGreen = Color(0xFFCADCA4);
const Color _cardBg = Color(0xFFF7FFE7);
const Color _orangeText = Color(0xFFE18151);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String displayName = 'Pengguna';
  double totalSaldo = 0.0;
  double perkiraanMingguan = 0.0;
  int currentXP = 0;
  int maxXP = 1000;
  int level = 1;

  bool hasTargetMenabung = false;
  double _feenX = 0;
  double _feenY = 0;
  bool _isFeenInitialized = false;
  bool _isDraggingFeen = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
      totalSaldo += 50000;
      perkiraanMingguan = totalSaldo + (totalSaldo * 0.02);
      currentXP += 50;

      if (currentXP >= maxXP) {
        level++;
        currentXP = currentXP - maxXP;
        maxXP = (maxXP * 1.5).toInt();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final double xpProgress =
        maxXP > 0 ? (currentXP / maxXP).clamp(0.0, 1.0) : 0.0;

    if (!_isFeenInitialized) {
      _feenX = MediaQuery.of(context).size.width - 84;
      _feenY = MediaQuery.of(context).size.height - 200;
      _isFeenInitialized = true;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
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
                                  Text(
                                    'Halo $displayName !',
                                    style: const TextStyle(
                                        color: _primaryGreen,
                                        fontSize: 18,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    'level $level',
                                    style: const TextStyle(
                                        color: _primaryGreen,
                                        fontSize: 16,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 24),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const ProfileScreen()),
                                  );
                                },
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FFE8),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: _primaryGreen, width: 2),
                                  ),
                                  child: const Icon(Icons.person,
                                      color: _primaryGreen, size: 30),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        //card: Total Saldo
                        GestureDetector(
                          onTap: _tambahTabunganMock,
                          child: Container(
                            decoration: BoxDecoration(
                                color: _cardBg,
                                borderRadius: BorderRadius.circular(24),
                                border:
                                    Border.all(color: _primaryGreen, width: 4)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Total Saldo',
                                          style: TextStyle(
                                              color: _primaryGreen,
                                              fontSize: 16,
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text(
                                          'Rp ${totalSaldo.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                              color: _primaryGreen,
                                              fontSize: 28,
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 16),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: LinearProgressIndicator(
                                            value: xpProgress,
                                            backgroundColor: _lightGreen,
                                            color: _primaryGreen,
                                            minHeight: 8),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                          '$currentXP/$maxXP xp menuju level ${level + 1}',
                                          style: const TextStyle(
                                              color: _primaryGreen,
                                              fontSize: 12,
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: const BoxDecoration(
                                      color: _primaryGreen,
                                      borderRadius: BorderRadius.only(
                                          bottomLeft: Radius.circular(18),
                                          bottomRight: Radius.circular(18))),
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
                                            color: const Color(0xFFE7F8C1),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('Perkiraan Minggu Depan',
                                              style: TextStyle(
                                                  color: Color(0xFFE7F8C1),
                                                  fontSize: 13,
                                                  fontFamily: 'Inter',
                                                  fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                      Text(
                                          'Rp ${perkiraanMingguan.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                              color: Color(0xFFE7F8C1),
                                              fontSize: 13,
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

                        //menu action
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _ActionMenu(
                              assetPath: 'assets/images/pemasukan.svg',
                              label: 'Pemasukan',
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const PemasukanScreen())),
                            ),
                            _ActionMenu(
                              assetPath: 'assets/images/pengeluaran.svg',
                              label: 'Pengeluaran',
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const PengeluaranScreen())),
                            ),
                            _ActionMenu(
                              assetPath: 'assets/images/pinjaman.svg',
                              label: 'Pinjaman',
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const PinjamanScreen())),
                            ),
                            _ActionMenu(
                              assetPath: 'assets/images/transfer.png',
                              label: 'Transfer',
                              iconPadding: const EdgeInsets.only(left: 4.0),
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const TransferScreen())),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        //target menabung
                        _SectionHeader(
                          title: 'Target Menabung',
                          actionText: 'Lihat Semua',
                          onActionTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const TargetMenabungScreen())),
                        ),
                        const SizedBox(height: 12),
                        hasTargetMenabung
                            ? Container(
                                decoration: BoxDecoration(
                                  color: _cardBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: _primaryGreen, width: 4),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                      ),
                                      child: Image.network(
                                        "https://placehold.co/324x167.png",
                                        height: 167,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.only(
                                          left: 16,
                                          right: 16,
                                          top: 16,
                                          bottom: 12),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Ipad',
                                            style: TextStyle(
                                                color: _primaryGreen,
                                                fontSize: 16,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w700),
                                          ),
                                          Text(
                                            'Rp xxx.xxx,xx/ 6.000.000,00',
                                            style: TextStyle(
                                                color: _primaryGreen,
                                                fontSize: 12,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 16, right: 16, bottom: 20),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(100),
                                        child: const LinearProgressIndicator(
                                          value: 0.15,
                                          backgroundColor: _lightGreen,
                                          color: _primaryGreen,
                                          minHeight: 6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 32, horizontal: 20),
                                decoration: BoxDecoration(
                                  color: _cardBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: _primaryGreen, width: 4),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 60,
                                      color: _primaryGreen.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text('Belum ada target impian nih!',
                                        style: TextStyle(
                                            color: _primaryGreen,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'Inter')),
                                    const SizedBox(height: 4),
                                    const Text(
                                        'Yuk mulai tabung uangmu untuk beli barang impianmu.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                            fontFamily: 'Inter')),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const BuatTargetScreen()),
                                        );
                                      },
                                      icon: const Icon(Icons.add,
                                          size: 18, color: Colors.white),
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
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 12),
                                        elevation: 0,
                                      ),
                                    )
                                  ],
                                ),
                              ),
                        const SizedBox(height: 32),

                        //ruang belajar
                        _SectionHeader(
                          title: 'Ruang Belajar',
                          actionText: 'Lihat Semua',
                          onActionTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RuangBelajarScreen())),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: _cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: _primaryGreen, width: 4)),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                    color: _lightGreen,
                                    borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.menu_book,
                                    color: _primaryGreen),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Judul modul',
                                            style: TextStyle(
                                                color: _primaryGreen,
                                                fontSize: 16,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w800)),
                                        Text('tingkat : dasar',
                                            style: TextStyle(
                                                color: _primaryGreen,
                                                fontSize: 12,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: const LinearProgressIndicator(
                                          value: 0.0,
                                          backgroundColor: _lightGreen,
                                          color: _primaryGreen,
                                          minHeight: 6),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          //floating button tanya feen
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
                  _feenY = _feenY.clamp(
                      0.0, MediaQuery.of(context).size.height - 180);
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
                    _feenX = screenWidth - 84.0;
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
                        color: const Color(0xFFADBC8D),
                        shape: BoxShape.circle,
                        border: Border.all(color: _primaryGreen, width: 2)),
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
                        color: const Color(0xFFF8FFE8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _primaryGreen, width: 1)),
                    child: const Text(
                      'Tanya Feen',
                      style: TextStyle(
                          color: _primaryGreen,
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

class _ActionMenu extends StatelessWidget {
  final String assetPath;
  final String label;
  final VoidCallback onTap;
  final EdgeInsetsGeometry iconPadding;

  const _ActionMenu({
    required this.assetPath,
    required this.label,
    required this.onTap,
    this.iconPadding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPng = assetPath.toLowerCase().endsWith('.png');

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: _primaryGreen,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Padding(
                padding: iconPadding,
                child: isPng
                    ? Image.asset(
                        assetPath,
                        width: 36,
                        height: 36,
                        color: const Color(0xFFE7F9C1),
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image,
                                color: Color(0xFFE7F9C1)),
                      )
                    : SvgPicture.asset(
                        assetPath,
                        width: 36,
                        height: 36,
                        colorFilter: const ColorFilter.mode(
                            Color(0xFFE7F9C1), BlendMode.srcIn),
                        placeholderBuilder: (context) => const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Color(0xFFE7F9C1), strokeWidth: 2),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
                color: _primaryGreen,
                fontSize: 12,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionText;
  final VoidCallback onActionTap;

  const _SectionHeader(
      {required this.title,
      required this.actionText,
      required this.onActionTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                color: _primaryGreen,
                fontSize: 18,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800)),
        GestureDetector(
          onTap: onActionTap,
          child: Text(actionText,
              style: const TextStyle(
                  color: _orangeText,
                  fontSize: 14,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
