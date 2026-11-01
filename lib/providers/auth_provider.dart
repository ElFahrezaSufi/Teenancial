import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/image_storage_service.dart';

/// State autentikasi: siapa yang sedang login. Dipakai UI dan router (guard).
class AuthProvider extends ChangeNotifier {
  final AuthService _service;

  UserModel? _user;
  bool _isInitialized = false;

  AuthProvider(this._service);

  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _user != null;
  UserModel? get currentUser => _user;
  String? get userId => _user?.id;

  /// File foto profil, atau 
ull jika belum ada / file sudah hilang.
  File? get avatarFile {
    final path = _user?.avatarPath;
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  /// Memuat akun tersimpan dan memulihkan sesi (jika ada).
  Future<void> init() async {
    await _service.init();
    _user = _service.sessionUser;
    if (_user == null) {
      // Bersihkan sesi yang menunjuk ke akun yang sudah tidak ada.
      await _service.setSession(null);
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<LoginResult> login(String email, String password) async {
    final outcome = _service.verify(email.trim(), password);
    if (outcome.result != LoginResult.success) return outcome.result;

    await _service.setSession(outcome.user!.id);
    _user = outcome.user;
    notifyListeners();
    return LoginResult.success;
  }

  /// `false` jika email sudah terdaftar. Tidak otomatis login.
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    String age = '',
    String gender = '',
  }) async {
    final created = await _service.register(
      email: email,
      password: password,
      name: name,
      age: age,
      gender: gender,
    );
    return created != null;
  }

  Future<void> logout() async {
    await _service.setSession(null);
    _user = null;
    notifyListeners();
  }

  Future<void> updateProfile({
    required String fullName,
    required String age,
    required String gender,
  }) async {
    final current = _user;
    if (current == null) return;
    _user = await _service.updateUser(
      current.copyWith(name: fullName, age: age, gender: gender),
    );
    notifyListeners();
  }

  /// Menyalin [picked] ke penyimpanan aplikasi lalu menyimpannya sebagai foto profil.
  Future<void> setAvatar(File picked) async {
    final current = _user;
    if (current == null) return;
    final savedPath = await ImageStorageService.saveImage(
      picked,
      folder: 'avatars',
      prefix: current.id,
    );
    _user = await _service.updateUser(current.copyWith(avatarPath: savedPath));
    notifyListeners();
    await ImageStorageService.deleteImage(current.avatarPath);
  }

  Future<void> removeAvatar() async {
    final current = _user;
    if (current == null || current.avatarPath == null) return;
    _user = await _service.updateUser(current.copyWith(clearAvatar: true));
    notifyListeners();
    await ImageStorageService.deleteImage(current.avatarPath);
  }
}
