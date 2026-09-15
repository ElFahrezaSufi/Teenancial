import 'package:flutter/material.dart';

const Color _primaryGreen = Color(0xFF637932);
const Color _scaffoldBg = Color(0xFFEDEFE2);
const Color _appBarBg = Color(0xFFF8FFE8);

class TanyaFeenScreen extends StatefulWidget {
  const TanyaFeenScreen({super.key});

  @override
  State<TanyaFeenScreen> createState() => _TanyaFeenScreenState();
}

class _TanyaFeenScreenState extends State<TanyaFeenScreen> {
  final TextEditingController _chatController = TextEditingController();

  void _showFeenMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.only(top: 2),
          decoration: const BoxDecoration(
            color: _primaryGreen,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 1, left: 1, right: 1),
            child: Container(
              decoration: const BoxDecoration(
                color: _appBarBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    _buildMenuItem(
                      icon: Icons.history,
                      title: 'Riwayat',
                      subtitle: 'semua transaksi kamu',
                      onTap: () => Navigator.pop(context),
                    ),
                    const Divider(
                        color: _primaryGreen, height: 1, thickness: 1),
                    _buildMenuItem(
                      icon: Icons.account_balance_wallet,
                      title: 'Dompet',
                      subtitle: 'Saldo tunai dan digital',
                      onTap: () => Navigator.pop(context),
                    ),
                    const Divider(
                        color: _primaryGreen, height: 1, thickness: 1),
                    _buildMenuItem(
                      icon: Icons.track_changes,
                      title: 'Target menabung',
                      subtitle: 'goal dan progress menabung',
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF7FFE7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _primaryGreen, width: 1),
        ),
        child: Icon(icon, color: _primaryGreen),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: _primaryGreen,
          fontSize: 16,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: _primaryGreen.withValues(alpha: 0.8),
          fontSize: 13,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing:
          const Icon(Icons.arrow_forward_ios, color: _primaryGreen, size: 16),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      //header
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
                    'Tanya Feen',
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

      // body
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

          // Area Chat dan Form Input
          Column(
            children: [
              // Ruang Chat
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24.0),
                  children: [],
                ),
              ),

              // Kotak Input Bawah
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: _appBarBg,
                  border: Border(
                    top: BorderSide(color: _primaryGreen, width: 1.5),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FFE7),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: _primaryGreen, width: 1),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.grid_view_rounded,
                              color: _primaryGreen),
                          onPressed: _showFeenMenu,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            style: const TextStyle(
                              color: _primaryGreen,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Tanya Feen',
                              hintStyle: TextStyle(
                                color: _primaryGreen.withValues(alpha: 0.5),
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: CircleAvatar(
                            backgroundColor: _primaryGreen,
                            child: IconButton(
                              icon: const Icon(Icons.send,
                                  color: Colors.white, size: 18),
                              onPressed: () {
                                _chatController.clear();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
