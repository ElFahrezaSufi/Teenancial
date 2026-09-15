import 'package:flutter/material.dart';
import '../data/mock_auth.dart';
import 'get_started.dart';
import 'main_screen.dart';

const Color _primaryGreen = Color(0xFF627931);
const Color _scaffoldBg = Color(0xFFEDEFE2);
const Color _fieldBg = Color(0xFFF8FFE8);
const Color _appBarBg = Color(0xFFF8FFE8);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isLoading = false;

  late TextEditingController _fullNameController;
  late TextEditingController _ageController;
  late TextEditingController _genderController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: MockAuth.activeUserName);
    _ageController = TextEditingController(text: MockAuth.activeAge);
    _genderController = TextEditingController(text: MockAuth.activeGender);
    _emailController = TextEditingController(text: MockAuth.activeEmail);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  void _saveProfile() async {
    await MockAuth.updateProfile(
      fullName: _fullNameController.text.trim(),
      age: _ageController.text.trim(),
      gender: _genderController.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profil berhasil diperbarui!'),
        backgroundColor: _primaryGreen,
      ),
    );

    setState(() {
      _isEditing = false;
    });
  }

  void _changeProfilePicture() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fitur Buka Kamera / Galeri akan segera ditambahkan!'),
        backgroundColor: Color(0xFFD9B62C),
      ),
    );
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoading = true);
    await MockAuth.logout();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const GetStarted()),
      (Route<dynamic> route) => false,
    );
  }

  void _handleBackButton() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,

      // HEADER
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
                      onPressed: _handleBackButton,
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    'Profil',
                    style: TextStyle(
                      color: _primaryGreen,
                      fontSize: 25,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_isEditing)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 24.0),
                      child: GestureDetector(
                        onTap: _saveProfile,
                        child: const Text(
                          'Simpan',
                          style: TextStyle(
                            color: _primaryGreen,
                            fontSize: 15,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),

      //body
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
                  const SizedBox(height: 16),

                  //pp dan smacamnya
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: _fieldBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: _primaryGreen, width: 2),
                          ),
                          child: const Icon(Icons.person,
                              color: _primaryGreen, size: 60),
                        ),
                        GestureDetector(
                          onTap: _isEditing
                              ? _changeProfilePicture
                              : _startEditing,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _isEditing
                                  ? const Color(0xFFD9B62C)
                                  : _primaryGreen,
                              shape: BoxShape.circle,
                              border: Border.all(color: _scaffoldBg, width: 3),
                            ),
                            child: Icon(
                              _isEditing ? Icons.camera_alt : Icons.edit,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Form Fields
                  _EditableProfileField(
                    label: 'Nama Lengkap',
                    controller: _fullNameController,
                    isEditing: _isEditing,
                  ),
                  _EditableProfileField(
                    label: 'Umur',
                    controller: _ageController,
                    isEditing: _isEditing,
                    keyboardType: TextInputType.number,
                  ),
                  _EditableProfileField(
                    label: 'Jenis Kelamin',
                    controller: _genderController,
                    isEditing: _isEditing,
                  ),
                  _EditableProfileField(
                    label: 'Email',
                    controller: _emailController,
                    isEditing: false,
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: _fieldBg, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Keluar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isEditing;
  final TextInputType? keyboardType;

  const _EditableProfileField({
    required this.label,
    required this.controller,
    required this.isEditing,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _primaryGreen,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            enabled: isEditing,
            keyboardType: keyboardType,
            style: TextStyle(
              color: isEditing
                  ? _primaryGreen
                  : _primaryGreen.withValues(alpha: 0.7),
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: isEditing ? Colors.white : _fieldBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _primaryGreen, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                    color: _primaryGreen.withValues(alpha: 0.5), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFFD9B62C), width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
