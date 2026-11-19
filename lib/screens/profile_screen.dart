import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/mission_provider.dart';
import '../providers/user_provider.dart';
import '../routes/app_router.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../utils/error_mapper.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/feen/feen_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isDeletingAccount = false;
  bool _dailyReminder = LocalStorageService.instance.dailyReminderEnabled;

  File? _pendingImageFile;
  bool _removeExistingImage = false;
  String? _syncedUid;

  late final TextEditingController _fullNameController;
  late final TextEditingController _ageController;
  late final TextEditingController _emailController;

  String? _selectedGender;
  DateTime? _selectedBirthDate;

  @override
  void initState() {
    super.initState();
    _dailyReminder = LocalStorageService.instance.dailyReminderEnabled;
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
        _selectedBirthDate = null;
      }
      return;
    }

    _syncedUid = profile.uid;
    final nextName = profile.name.isNotEmpty ? profile.name : 'Pengguna';
    _setControllerTextIfChanged(_fullNameController, nextName);
    _setControllerTextIfChanged(_emailController, profile.email);
    _setControllerTextIfChanged(_ageController, profile.age);
    _selectedBirthDate = profile.birthDate;

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
        _selectedBirthDate = profile.birthDate;
      } else if (_fullNameController.text == 'Memuat...') {
        _setControllerTextIfChanged(_fullNameController, '');
      }
      _isEditing = true;
      _pendingImageFile = null;
      _removeExistingImage = false;
    });
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final defaultDate = DateTime(now.year - 17, now.month, now.day);
    final firstDate = DateTime(now.year - 100, 1, 1);
    final lastDate = DateTime(now.year - 10, now.month, now.day);

    final initialDate = _selectedBirthDate != null &&
            !_selectedBirthDate!.isBefore(firstDate) &&
            !_selectedBirthDate!.isAfter(lastDate)
        ? _selectedBirthDate!
        : defaultDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Pilih Tanggal Lahir',
    );
    if (picked == null || !mounted) return;

    final calculatedAge = UserModel.calculateAge(picked);
    setState(() {
      _selectedBirthDate = picked;
      _setControllerTextIfChanged(_ageController, calculatedAge.toString());
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
            content:
                Text('Umur harus berupa angka antara 10 hingga 100 tahun.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final effectiveBirthDate = (_selectedBirthDate != null &&
              UserModel.calculateAge(_selectedBirthDate!).toString() ==
                  trimmedAge)
          ? _selectedBirthDate
          : null;

      await context.read<UserProvider>().saveProfile(
            name: trimmedName,
            age: trimmedAge,
            birthDate: effectiveBirthDate,
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
            'Gagal memperbarui profil: ${ErrorMapper.message(e)}',
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
    if (_isSaving || _isDeletingAccount) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appBarBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Keluar Akun',
          style: TextStyle(
            color: primaryGreen,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Apakah kamu yakin ingin keluar dari akun ini?',
          style: TextStyle(
            color: primaryGreen.withValues(alpha: 0.85),
            fontFamily: 'Inter',
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Batal',
              style: TextStyle(
                color: primaryGreen.withValues(alpha: 0.7),
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Keluar',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

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

  Future<String?> _promptPasswordForReauth() async {
    String typedPassword = '';
    bool obscure = true;
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: appBarBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Verifikasi Password',
            style: TextStyle(
              color: primaryGreen,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Demi keamanan, masukkan password akunmu untuk mengonfirmasi penghapusan permanen.',
                style: TextStyle(
                  color: primaryGreen.withValues(alpha: 0.85),
                  fontFamily: 'Inter',
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                obscureText: obscure,
                autofocus: true,
                onChanged: (val) {
                  typedPassword = val;
                  if (errorText != null && val.trim().isNotEmpty) {
                    setDialogState(() => errorText = null);
                  }
                },
                style: const TextStyle(
                  color: primaryGreen,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Masukkan password akunmu',
                  errorText: errorText,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: primaryGreen),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      color: primaryGreen,
                      size: 18,
                    ),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: primaryGreen.withValues(alpha: 0.7),
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              onPressed: () {
                if (typedPassword.trim().isEmpty) {
                  setDialogState(
                    () => errorText = 'Password wajib diisi',
                  );
                  return;
                }
                Navigator.of(ctx).pop(typedPassword.trim());
              },
              child: const Text(
                'Hapus Permanen',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  Future<void> _handleDeleteAccount() async {
    if (_isSaving || _isDeletingAccount) return;

    final authProvider = context.read<AuthProvider>();
    final isGoogleUser = authProvider.isGoogleSignInUser;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appBarBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Hapus Akun Permanen?',
          style: TextStyle(
            color: Colors.redAccent,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: Text(
          isGoogleUser
              ? 'Semua data profil, dompet, transaksi, target menabung, dan progres Feen akan dihapus secara permanen dan tidak bisa dikembalikan.\n\nKamu akan diminta memverifikasi ulang melalui akun Google-mu untuk mengonfirmasi.'
              : 'Semua data profil, dompet, transaksi, target menabung, dan progres Feen akan dihapus secara permanen dan tidak bisa dikembalikan.',
          style: TextStyle(
            color: primaryGreen.withValues(alpha: 0.85),
            fontFamily: 'Inter',
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Batal',
              style: TextStyle(
                color: primaryGreen.withValues(alpha: 0.7),
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              isGoogleUser ? 'Ya, Hapus' : 'Lanjutkan',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    String? password;
    if (!isGoogleUser) {
      password = await _promptPasswordForReauth();
      if (password == null || password.isEmpty || !mounted) {
        return;
      }
    }

    setState(() => _isDeletingAccount = true);

    try {
      await LocalStorageService.instance.setHasSeenGetStarted(true);
      if (!mounted) return;
      await authProvider.deleteAccount(password: password);

      if (mounted) {
        context.go(AppRoutes.login);
      }
      rootScaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Akun beserta seluruh data kamu telah berhasil dihapus secara permanen.',
            ),
            backgroundColor: primaryGreen,
            duration: Duration(seconds: 4),
          ),
        );
    } on ReauthCanceledException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Verifikasi akun Google dibatalkan. Akun tidak dihapus.',
            ),
            backgroundColor: primaryGreen,
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus akun: ${ErrorMapper.message(e)}',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
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

  void _showAboutDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appBarBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Tentang Aplikasi',
          style: TextStyle(
            color: primaryGreen,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Aplikasi pencatat keuangan harian, target menabung, dan edukasi literasi finansial bersama maskot Feen.\n\nVersi 1.0.0',
          style: TextStyle(
            color: primaryGreen.withValues(alpha: 0.85),
            fontFamily: 'Inter',
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  ImageProvider? _getAvatarImage(String? remoteUrl) {
    if (_pendingImageFile != null) {
      return FileImage(_pendingImageFile!);
    }
    if (!_removeExistingImage && remoteUrl != null && remoteUrl.isNotEmpty) {
      return CachedNetworkImageProvider(remoteUrl);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final missionProvider = context.watch<MissionProvider>();
    _syncControllersFromProfile(userProvider.profile);

    final remoteImageUrl = userProvider.profileImageUrl;
    final avatarImage = _getAvatarImage(remoteImageUrl);
    final bool hasDisplayedPhoto = _pendingImageFile != null ||
        (!_removeExistingImage &&
            remoteImageUrl != null &&
            remoteImageUrl.isNotEmpty);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: CustomAppBar(
        title: _isEditing ? 'Edit Profil' : 'Akun',
        backIcon: _isEditing ? Icons.close : Icons.arrow_back_ios,
        onBack: _handleBackButton,
        trailing: _isEditing
            ? Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: GestureDetector(
                  onTap: _isSaving ? null : _saveProfile,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: primaryGreen,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Simpan',
                          style: TextStyle(
                            color: primaryGreen,
                            fontSize: 15,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              )
            : null,
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: _isEditing
                  ? _buildEditProfileForm(avatarImage, hasDisplayedPhoto)
                  : _buildAccountHub(
                      userProvider,
                      missionProvider,
                      avatarImage,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountHub(
    UserProvider userProvider,
    MissionProvider missionProvider,
    ImageProvider? avatarImage,
  ) {
    final profile = userProvider.profile;
    final displayName = (profile != null && profile.name.isNotEmpty)
        ? profile.name
        : 'Pengguna';
    final displayEmail =
        (profile != null && profile.email.isNotEmpty) ? profile.email : '-';
    final claimableCount = missionProvider.claimableCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Kotak Profil Utama
        CustomCard(
          backgroundColor: cardBg,
          borderRadius: 20,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
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
                            size: 38,
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: primaryGreen,
                            fontSize: 17,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayEmail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: primaryGreen.withValues(alpha: 0.75),
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: primaryGreen, width: 1),
                          ),
                          child: Text(
                            'Level ${userProvider.level}  |  ${userProvider.xpIntoLevel}/${userProvider.xpNeededForNext} XP',
                            style: const TextStyle(
                              color: primaryGreen,
                              fontSize: 11,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _startEditing,
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text(
                    'Edit Profil',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryGreen,
                    backgroundColor: inputBg,
                    side: const BorderSide(color: primaryGreen, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Kotak Maskot & Misi
        const _SectionLabel(title: 'Maskot & Gamifikasi'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => context.push(AppRoutes.feenWardrobe),
          child: CustomCard(
            borderRadius: 20,
            backgroundColor: inputBg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                FeenAvatar(
                  level: userProvider.level,
                  equipped: userProvider.feenEquipped,
                  size: 48,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lemari Feen',
                        style: TextStyle(
                          color: primaryGreen,
                          fontSize: 15,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ganti aksesoris & tampilan maskotmu',
                        style: TextStyle(
                          color: primaryGreen,
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: primaryGreen,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => context.push(AppRoutes.misi),
          child: CustomCard(
            borderRadius: 20,
            backgroundColor: inputBg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cardBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryGreen, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFFDAB62C),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Misi & XP',
                        style: TextStyle(
                          color: primaryGreen,
                          fontSize: 15,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Klaim hadiah XP harian, mingguan & bulanan',
                        style: TextStyle(
                          color: primaryGreen,
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (claimableCount > 0) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDAB62C),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: primaryGreen, width: 1),
                    ),
                    child: Text(
                      '$claimableCount',
                      style: const TextStyle(
                        color: primaryGreen,
                        fontSize: 11,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Icon(
                  Icons.arrow_forward_ios,
                  color: primaryGreen,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 3. Kotak Informasi & Pengaturan Akun
        const _SectionLabel(title: 'Informasi & Pengaturan'),
        const SizedBox(height: 8),
        CustomCard(
          backgroundColor: cardBg,
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              _AccountMenuTile(
                icon: Icons.notifications_none_rounded,
                title: 'Pengingat Harian',
                subtitle: 'Notifikasi catat transaksi & pinjaman',
                trailing: Switch(
                  value: _dailyReminder,
                  activeTrackColor: primaryGreen,
                  onChanged: (val) {
                    setState(() => _dailyReminder = val);
                    NotificationService.instance.setRemindersEnabled(val);
                  },
                ),
              ),
              Divider(
                height: 1,
                indent: 60,
                endIndent: 16,
                color: primaryGreen.withValues(alpha: 0.15),
              ),
              if (context.select<AuthProvider, bool>(
                (auth) => auth.isEmailPasswordUser,
              )) ...[
                _AccountMenuTile(
                  icon: Icons.lock_reset_rounded,
                  title: 'Ganti Password',
                  subtitle: 'Ubah password akunmu',
                  onTap: () => context.push(AppRoutes.gantiPassword),
                ),
                Divider(
                  height: 1,
                  indent: 60,
                  endIndent: 16,
                  color: primaryGreen.withValues(alpha: 0.15),
                ),
              ],
              _AccountMenuTile(
                icon: Icons.info_outline_rounded,
                title: 'Tentang Aplikasi',
                subtitle: 'Versi aplikasi & informasi pengembang',
                onTap: _showAboutDialog,
              ),
              Divider(
                height: 1,
                indent: 60,
                endIndent: 16,
                color: primaryGreen.withValues(alpha: 0.15),
              ),
              _AccountMenuTile(
                icon: Icons.delete_forever_outlined,
                title: 'Hapus Akun',
                subtitle: 'Hapus permanen akun anda',
                isDestructive: true,
                trailing: _isDeletingAccount
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.redAccent,
                          strokeWidth: 2,
                        ),
                      )
                    : null,
                onTap: _isDeletingAccount ? null : _handleDeleteAccount,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 4. Tombol Keluar
        GestureDetector(
          onTap: (_isSaving || _isDeletingAccount) ? null : _handleLogout,
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
      ],
    );
  }

  Widget _buildEditProfileForm(
    ImageProvider? avatarImage,
    bool hasDisplayedPhoto,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
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
                onTap: hasDisplayedPhoto
                    ? () => setState(() {
                          _pendingImageFile = null;
                          _removeExistingImage = true;
                        })
                    : _changeProfilePicture,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: hasDisplayedPhoto
                        ? Colors.redAccent
                        : const Color(0xFFDAB62C),
                    shape: BoxShape.circle,
                    border: Border.all(color: scaffoldBg, width: 3),
                  ),
                  child: Icon(
                    hasDisplayedPhoto ? Icons.delete_outline : Icons.camera_alt,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _EditableProfileField(
          label: 'Nama Lengkap',
          controller: _fullNameController,
          isEditing: true,
        ),
        _EditableProfileField(
          label: 'Umur',
          controller: _ageController,
          isEditing: true,
          keyboardType: TextInputType.number,
          suffixIcon: IconButton(
            tooltip: 'Pilih Tanggal Lahir',
            icon: const Icon(
              Icons.calendar_month_outlined,
              color: primaryGreen,
              size: 20,
            ),
            onPressed: _pickBirthDate,
          ),
        ),
        _EditableDropdownField(
          label: 'Jenis Kelamin',
          value: _selectedGender,
          items: const ['Laki-Laki', 'Perempuan'],
          isEditing: true,
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
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: primaryGreen,
          fontSize: 13,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AccountMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDestructive;

  const _AccountMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isDestructive ? Colors.redAccent : primaryGreen;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDestructive
                    ? Colors.redAccent.withValues(alpha: 0.1)
                    : inputBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 14,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: accentColor.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.arrow_forward_ios,
                  color: accentColor.withValues(alpha: 0.6),
                  size: 14,
                ),
          ],
        ),
      ),
    );
  }
}

class _EditableProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isEditing;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  const _EditableProfileField({
    required this.label,
    required this.controller,
    required this.isEditing,
    this.keyboardType,
    this.suffixIcon,
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
              decoration: InputDecoration(
                border: InputBorder.none,
                suffixIcon: suffixIcon,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
