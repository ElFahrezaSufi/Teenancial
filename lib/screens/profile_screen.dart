import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../services/local_storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common/custom_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;

  File? _pendingImageFile;
  bool _removeExistingImage = false;
  String? _syncedUid;

  late final TextEditingController _fullNameController;
  late final TextEditingController _ageController;
  late final TextEditingController _emailController;

  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: 'Memuat...');
    _emailController = TextEditingController(text: 'Memuat...');
    _ageController = TextEditingController(text: '');
    _selectedGender = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userProvider = context.read<UserProvider>();
      if (userProvider.profile == null && !userProvider.isLoading) {
        userProvider.loadProfile();
      }
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _setControllerTextIfChanged(
    TextEditingController controller,
    String nextText,
  ) {
    if (controller.text != nextText) {
      controller.text = nextText;
    }
  }

  void _syncControllersFromProfile(UserModel? profile) {
    if (_isEditing) return;

    if (profile == null) {
      if (_syncedUid != null) {
        _syncedUid = null;
        _setControllerTextIfChanged(_fullNameController, 'Memuat...');
        _setControllerTextIfChanged(_emailController, 'Memuat...');
        _setControllerTextIfChanged(_ageController, '');
        _selectedGender = null;
      }
      return;
    }

    _syncedUid = profile.uid;
    final nextName = profile.name.isNotEmpty ? profile.name : 'Pengguna';
    _setControllerTextIfChanged(_fullNameController, nextName);
    _setControllerTextIfChanged(_emailController, profile.email);
    _setControllerTextIfChanged(_ageController, profile.age);

    final fetchedGender = profile.gender.trim();
    if (fetchedGender == 'Laki-Laki' || fetchedGender == 'Perempuan') {
      _selectedGender = fetchedGender;
    } else {
      _selectedGender = null;
    }
  }

  void _startEditing() {
    final userProvider = context.read<UserProvider>();
    final profile = userProvider.profile;
    if (userProvider.isLoading && profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data profil sedang dimuat, tunggu sebentar...'),
          backgroundColor: primaryGreen,
        ),
      );
      return;
    }

    setState(() {
      if (profile != null) {
        _setControllerTextIfChanged(_fullNameController, profile.name);
        _setControllerTextIfChanged(_emailController, profile.email);
        _setControllerTextIfChanged(_ageController, profile.age);
      } else if (_fullNameController.text == 'Memuat...') {
        _setControllerTextIfChanged(_fullNameController, '');
      }
      _isEditing = true;
      _pendingImageFile = null;
      _removeExistingImage = false;
    });
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    final trimmedName = _fullNameController.text.trim();
    final trimmedAge = _ageController.text.trim();

    if (trimmedName.isEmpty || trimmedName == 'Memuat...') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama lengkap tidak boleh kosong.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (trimmedAge.isNotEmpty) {
      final parsedAge = int.tryParse(trimmedAge);
      if (parsedAge == null || parsedAge < 10 || parsedAge > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Umur harus berupa angka antara 10 hingga 100 tahun.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      await context.read<UserProvider>().saveProfile(
            name: trimmedName,
            age: trimmedAge,
            gender: _selectedGender ?? '',
            newImageFile: _pendingImageFile,
            removeImage: _removeExistingImage && _pendingImageFile == null,
          );

      if (!mounted) return;

      setState(() {
        _pendingImageFile = null;
        _removeExistingImage = false;
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui!'),
          backgroundColor: primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memperbarui profil: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changeProfilePicture() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (!mounted) return;
      if (image != null) {
        setState(() {
          _pendingImageFile = File(image.path);
          _removeExistingImage = false;
        });
      }
    } catch (e) {
      debugPrint('Gagal mengambil gambar: $e');
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
    if (_isSaving) return;
    setState(() => _isSaving = true);
    _pendingImageFile = null;
    _removeExistingImage = false;

    try {
      await LocalStorageService.instance.setHasSeenGetStarted(true);
      if (!mounted) return;
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      context.go(AppRoutes.login);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal keluar akun: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _handleBackButton() {
    if (_isEditing) {
      final profile = context.read<UserProvider>().profile;
      setState(() {
        _pendingImageFile = null;
        _removeExistingImage = false;
        _isEditing = false;
        _syncControllersFromProfile(profile);
      });
      return;
    }

    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  ImageProvider? _getAvatarImage(String? remoteUrl) {
    if (_pendingImageFile != null) {
      return FileImage(_pendingImageFile!);
    }
    if (!_removeExistingImage && remoteUrl != null && remoteUrl.isNotEmpty) {
      return NetworkImage(remoteUrl);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    _syncControllersFromProfile(userProvider.profile);

    final remoteImageUrl = userProvider.profileImageUrl;
    final avatarImage = _getAvatarImage(remoteImageUrl);
    final bool hasDisplayedPhoto = _pendingImageFile != null ||
        (!_removeExistingImage &&
            remoteImageUrl != null &&
            remoteImageUrl.isNotEmpty);

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
                      icon: Icon(
                        _isEditing ? Icons.close : Icons.arrow_back_ios,
                        color: primaryGreen,
                        size: 20,
                      ),
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
                        onTap: _isSaving ? null : _saveProfile,
                        child: Text(
                          _isSaving ? 'Menyimpan...' : 'Simpan',
                          style: TextStyle(
                            color: _isSaving ? Colors.grey : primaryGreen,
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
                            image: avatarImage != null
                                ? DecorationImage(
                                    image: avatarImage,
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: avatarImage == null
                              ? const Icon(
                                  Icons.person,
                                  color: primaryGreen,
                                  size: 60,
                                )
                              : null,
                        ),
                        GestureDetector(
                          onTap: _isEditing
                              ? (hasDisplayedPhoto
                                  ? () => setState(() {
                                        _pendingImageFile = null;
                                        _removeExistingImage = true;
                                      })
                                  : _changeProfilePicture)
                              : _startEditing,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _isEditing
                                  ? (hasDisplayedPhoto
                                      ? Colors.redAccent
                                      : const Color(0xFFDAB62C))
                                  : primaryGreen,
                              shape: BoxShape.circle,
                              border: Border.all(color: scaffoldBg, width: 3),
                            ),
                            child: Icon(
                              _isEditing
                                  ? (hasDisplayedPhoto
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
                    onTap: _isSaving ? null : _handleLogout,
                    child: CustomCard(
                      borderRadius: 100,
                      backgroundColor: primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: inputBg,
                                  strokeWidth: 2.5,
                                ),
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
                    initialValue:
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
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: primaryGreen,
                    ),
                    dropdownColor: Colors.white,
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
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
