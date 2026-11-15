import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/feen/feen_avatar.dart';

class TanyaFeenScreen extends StatefulWidget {
  const TanyaFeenScreen({super.key});

  @override
  State<TanyaFeenScreen> createState() => _TanyaFeenScreenState();
}

class _TanyaFeenScreenState extends State<TanyaFeenScreen> {
  final TextEditingController _chatController = TextEditingController();

  static const List<String> _suggestions = [
    'Cara mulai menabung',
    'Apa itu dana darurat?',
    'Tips atur uang jajan',
  ];

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  Widget _buildFeenMessage(UserProvider user, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FeenAvatar(level: user.level, equipped: user.feenEquipped, size: 48),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border.all(color: primaryGreen, width: 1.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: primaryGreen,
                fontSize: 14,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in _suggestions)
          GestureDetector(
            onTap: () {
              _chatController.text = label;
              _chatController.selection =
                  TextSelection.collapsed(offset: label.length);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: primaryGreen, width: 1),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: primaryGreen,
                  fontSize: 12,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showFeenMenu() {
    final user = context.read<UserProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.only(top: 2),
          decoration: const BoxDecoration(
            color: primaryGreen,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 1, left: 1, right: 1),
            child: Container(
              decoration: const BoxDecoration(
                color: appBarBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Row(
                        children: [
                          FeenAvatar(
                            level: user.level,
                            equipped: user.feenEquipped,
                            size: 48,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Mau lihat apa?',
                              style: TextStyle(
                                color: primaryGreen,
                                fontSize: 18,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: primaryGreen, height: 1, thickness: 1),
                    _buildMenuItem(
                      icon: Icons.history,
                      title: 'Riwayat',
                      subtitle: 'semua transaksi kamu',
                      onTap: () => Navigator.pop(context),
                    ),
                    const Divider(color: primaryGreen, height: 1, thickness: 1),
                    _buildMenuItem(
                      icon: Icons.account_balance_wallet,
                      title: 'Dompet',
                      subtitle: 'Saldo tunai dan digital',
                      onTap: () => Navigator.pop(context),
                    ),
                    const Divider(color: primaryGreen, height: 1, thickness: 1),
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
          border: Border.all(color: primaryGreen, width: 1),
        ),
        child: Icon(icon, color: primaryGreen),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: primaryGreen,
          fontSize: 16,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: primaryGreen.withValues(alpha: 0.8),
          fontSize: 13,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing:
          const Icon(Icons.arrow_forward_ios, color: primaryGreen, size: 16),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: scaffoldBg,
      //header
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
                      onPressed: () => context.pop(),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 56.0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FeenAvatar(
                            level: user.level,
                            equipped: user.feenEquipped,
                            size: 40,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Tanya Feen',
                            maxLines: 1,
                            style: TextStyle(
                              color: primaryGreen,
                              fontSize: 20,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: IconButton(
                      tooltip: 'Lemari Feen',
                      icon: const Icon(Icons.checkroom_rounded,
                          color: primaryGreen, size: 26),
                      onPressed: () => context.push(AppRoutes.feenWardrobe),
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
            color: scaffoldBg,
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
                  children: [
                    _buildFeenMessage(
                      user,
                      'Hai ${user.displayName}! Aku Feen, teman keuanganmu. '
                      'Mau tanya apa soal uangmu hari ini?',
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 56),
                      child: _buildSuggestionChips(),
                    ),
                  ],
                ),
              ),

              // Kotak Input Bawah
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: appBarBg,
                  border: Border(
                    top: BorderSide(color: primaryGreen, width: 1.5),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FFE7),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: primaryGreen, width: 1),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.grid_view_rounded,
                              color: primaryGreen),
                          onPressed: _showFeenMenu,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            style: const TextStyle(
                              color: primaryGreen,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Tanya Feen',
                              hintStyle: TextStyle(
                                color: primaryGreen.withValues(alpha: 0.5),
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: CircleAvatar(
                            backgroundColor: primaryGreen,
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
