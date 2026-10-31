import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/common/custom_card.dart';

class ProfileScreen extends StatefulWidget {
  static File? profileImage;

  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isLoading = false;

  String? _profileImageUrl;

  late TextEditingController _fullNameController;
  late TextEditingController _ageController;
  late TextEditingController _emailController;

  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: 'Memuat...');
    _emailController = TextEditingController(text: 'Memuat...');
    _ageController = TextEditingController(text: '');
    _selectedGender = null;

    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;

      if (!mounted || updatedUser == null) return;

      _emailController.text = updatedUser.email ?? '';

      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(updatedUser.uid)
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _fullNameController.text =
                data['name'] ?? updatedUser.displayName ?? 'Pengguna';
            _ageController.text = data['age'] ?? '';
            _profileImageUrl = data['profileImageUrl'] ?? updatedUser.photoURL;

            String fetchedGender = (data['gender'] ?? '').toString().trim();
            if (fetchedGender == 'Laki-Laki' || fetchedGender == 'Perempuan') {
              _selectedGender = fetchedGender;
            } else {
              _selectedGender = null;
            }
          });
        } else {
          setState(() {
            String initialName = updatedUser.displayName ?? '';
            if (initialName.trim().isEmpty && updatedUser.email != null) {
              initialName = updatedUser.email!.split('@')[0];
            }
            _fullNameController.text =
                initialName.isEmpty ? 'Pengguna' : initialName;
            _profileImageUrl = updatedUser.photoURL;
          });
        }
      } catch (e) {
        debugPrint("Gagal memuat data Firestore: $e");
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String? updatedImageUrl = _profileImageUrl;

      try {
        if (ProfileScreen.profileImage != null) {
          const cloudName = 'vsgjbngi';
          const uploadPreset = 'Teenancial';

          final url = Uri.parse(
              'https://api.cloudinary.com/v1_1/$cloudName/image/upload');

          final request = http.MultipartRequest('POST', url)
            ..fields['upload_preset'] = uploadPreset
            ..files.add(await http.MultipartFile.fromPath(
                'file', ProfileScreen.profileImage!.path));

          final response = await request.send();

          if (response.statusCode == 200) {
            final responseData = await response.stream.bytesToString();
            final jsonMap = jsonDecode(responseData);
            updatedImageUrl = jsonMap['secure_url'];
          } else {
            debugPrint("Gagal upload ke Cloudinary: ${response.statusCode}");
          }
        }

        await user.updateDisplayName(_fullNameController.text.trim());
        if (updatedImageUrl != null && updatedImageUrl.isNotEmpty) {
          await user.updatePhotoURL(updatedImageUrl);
        }

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': _fullNameController.text.trim(),
          'age': _ageController.text.trim(),
          'gender': _selectedGender ?? '',
          if (updatedImageUrl != null) 'profileImageUrl': updatedImageUrl,
        }, SetOptions(merge: true));

        await user.reload();

        setState(() {
          _profileImageUrl = updatedImageUrl;
          ProfileScreen.profileImage = null;
        });
      } catch (e) {
        debugPrint("Error saat menyimpan profil: $e");
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profil berhasil diperbarui!'),
        backgroundColor: primaryGreen,
      ),
    );

    setState(() {
      _isLoading = false;
      _isEditing = false;
    });
  }

  Future<void> _changeProfilePicture() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (!mounted) return;
      if (image != null) {
        setState(() {
          ProfileScreen.profileImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint("Gagal mengambil gambar: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terjadi kesalahan saat membuka galeri.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoading = true);

    ProfileScreen.profileImage = null;
    await context.read<AuthProvider>().logout();

    if (!mounted) return;
    context.go('/get_started');
  }

  void _handleBackButton() {
    ProfileScreen.profileImage = null;

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  ImageProvider? _getAvatarImage() {
    if (ProfileScreen.profileImage != null) {
      return FileImage(ProfileScreen.profileImage!);
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return NetworkImage(_profileImageUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
                      onPressed: _handleBackButton,
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    'Profil',
                    style: TextStyle(
                      color: primaryGreen,
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
                            color: primaryGreen,
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
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: inputBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: primaryGreen, width: 2),
                            image: _getAvatarImage() != null
                                ? DecorationImage(
                                    image: _getAvatarImage()!,
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _getAvatarImage() == null
                              ? const Icon(Icons.person,
                                  color: primaryGreen, size: 60)
                              : null,
                        ),
                        GestureDetector(
                          onTap: _isEditing
                              ? (ProfileScreen.profileImage != null ||
                                      _profileImageUrl != null
                                  ? () => setState(() {
                                        ProfileScreen.profileImage = null;
                                        _profileImageUrl = null;
                                      })
                                  : _changeProfilePicture)
                              : _startEditing,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _isEditing
                                  ? (ProfileScreen.profileImage != null ||
                                          _profileImageUrl != null
                                      ? Colors.redAccent
                                      : const Color(0xFFDAB62C))
                                  : primaryGreen,
                              shape: BoxShape.circle,
                              border: Border.all(color: scaffoldBg, width: 3),
                            ),
                            child: Icon(
                              _isEditing
                                  ? (ProfileScreen.profileImage != null ||
                                          _profileImageUrl != null
                                      ? Icons.delete_outline
                                      : Icons.camera_alt)
                                  : Icons.edit,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
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
                  _EditableDropdownField(
                    label: 'Jenis Kelamin',
                    value: _selectedGender,
                    items: const ['Laki-Laki', 'Perempuan'],
                    isEditing: _isEditing,
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                  ),
                  _EditableProfileField(
                    label: 'Email',
                    controller: _emailController,
                    isEditing: false,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _isLoading ? null : _handleLogout,
                    child: CustomCard(
                      borderRadius: 100,
                      backgroundColor: primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: inputBg, strokeWidth: 2.5),
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
              color: primaryGreen,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          CustomCard(
            padding: EdgeInsets.zero,
            backgroundColor: isEditing ? Colors.white : inputBg,
            child: TextFormField(
              controller: controller,
              enabled: isEditing,
              keyboardType: keyboardType,
              style: TextStyle(
                color: isEditing
                    ? primaryGreen
                    : primaryGreen.withValues(alpha: 0.7),
                fontSize: 14,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableDropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final bool isEditing;
  final ValueChanged<String?> onChanged;

  const _EditableDropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.isEditing,
    required this.onChanged,
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
              color: primaryGreen,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          CustomCard(
            padding: EdgeInsets.zero,
            backgroundColor: isEditing ? Colors.white : inputBg,
            child: isEditing
                ? DropdownButtonFormField<String>(
                    value:
                        (value != null && items.contains(value)) ? value : null,
                    items: items.map((String item) {
                      return DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      );
                    }).toList(),
                    onChanged: onChanged,
                    style: const TextStyle(
                      color: primaryGreen,
                      fontSize: 14,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon:
                        const Icon(Icons.arrow_drop_down, color: primaryGreen),
                    dropdownColor: Colors.white,
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Text(
                      (value != null && value!.isNotEmpty) ? value! : '-',
                      style: TextStyle(
                        color: primaryGreen.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
