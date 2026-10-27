import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

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

  Future<void> updateAvatar(String path) async {
    final current = _user;
    if (current == null) return;
    _user = await _service.updateUser(current.copyWith(avatarPath: path));
    notifyListeners();
  }
}
