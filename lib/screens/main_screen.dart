import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'dompet_screen.dart';
import 'riwayat_screen.dart';

const Color _primaryGreen = Color(0xFF627931);
const Color _scaffoldBg = Color(0xFFEDEFE2);

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const DompetScreen(),
    const RiwayatScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      extendBody: true,
      body: _screens[_selectedIndex],
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FFE8),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: _primaryGreen, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                  icon: Icons.home_filled, label: 'Beranda', index: 0),
              _buildNavItem(
                  icon: Icons.account_balance_wallet,
                  label: 'Dompet',
                  index: 1),
              _buildNavItem(icon: Icons.history, label: 'Riwayat', index: 2),
              _buildNavItem(icon: Icons.person, label: 'Profil', index: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      {required IconData icon, required String label, required int index}) {
    final bool isActive = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? _primaryGreen.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border:
              isActive ? Border.all(color: _primaryGreen, width: 1.5) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _primaryGreen, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: _primaryGreen,
                fontSize: 11,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
