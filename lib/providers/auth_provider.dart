import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';

export '../repositories/auth_repository.dart' show ReauthCanceledException;

/// Dilempar saat email & password benar, tetapi email belum diverifikasi.
class EmailNotVerifiedException implements Exception {
  const EmailNotVerifiedException();

  @override
  String toString() => 'Email belum diverifikasi';
}

class AuthProvider extends ChangeNotifier {
  static final ValueNotifier<bool> _bootstrapNotifier =
      ValueNotifier<bool>(false);

  static ValueListenable<bool> get bootstrapListenable => _bootstrapNotifier;

  final FirebaseAuth _auth;
  final AuthRepository _repository;

  User? _user;
  bool _bootstrapInProgress = false;

  User? get user => _user;
  bool get isBootstrapping => _bootstrapInProgress;
  bool get isAuthenticated => _user != null && !_bootstrapInProgress;

  String? get activeUid => _bootstrapInProgress ? null : _user?.uid;

  /// Apakah akun email user sudah terverifikasi.
  bool get isEmailVerified => _user?.emailVerified ?? false;

  bool get isGoogleSignInUser =>
      _user?.providerData.any(
        (info) => info.providerId == GoogleAuthProvider.PROVIDER_ID,
      ) ??
      false;

  late final StreamSubscription<User?> _authSub;

  AuthProvider({
    FirebaseAuth? auth,
    AuthRepository? repository,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _repository = repository ?? AuthRepository() {
    _user = _auth.currentUser;
    if (_user != null && !LocalStorageService.instance.hasSeenGetStarted) {
      unawaited(LocalStorageService.instance.setHasSeenGetStarted(true));
    }
    _authSub = _auth.authStateChanges().listen((User? newUser) {
      final bool sessionEnded = newUser == null;
      final bool accountSwitched =
          _user != null && newUser != null && _user!.uid != newUser.uid;

      _user = newUser;
      if (newUser != null && !LocalStorageService.instance.hasSeenGetStarted) {
        unawaited(LocalStorageService.instance.setHasSeenGetStarted(true));
      }

      if (sessionEnded || accountSwitched) {
        _clearUserData();
      }
      notifyListeners();
    });
  }

  void _setBootstrapping(bool value) {
    _bootstrapInProgress = value;
    _bootstrapNotifier.value = value;
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  void _clearUserData() {
    unawaited(NotificationService.instance.cancelAll());
  }

  /// True selama proses login berjalan, supaya router tidak melompat ke
  /// halaman verifikasi sebelum layar login sempat menampilkan pesan error.
  static bool suppressVerificationRedirect = false;

  Future<void> login(String email, String password) async {
    suppressVerificationRedirect = true;
    try {
      final credential = await _repository.loginWithEmail(email, password);
      final user = credential.user;
      if (user == null) return;

      if (!user.emailVerified) {
        // Akun ada tetapi belum diverifikasi: kirim ulang link, akhiri sesi,
        // lalu laporkan ke layar login sebagai "email belum terdaftar".
        try {
          await user.sendEmailVerification();
        } catch (_) {}

        await _repository.logout();
        throw const EmailNotVerifiedException();
      }
    } finally {
      suppressVerificationRedirect = false;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String age,
    DateTime? birthDate,
    required String gender,
  }) async {
    _setBootstrapping(true);
    try {
      await _repository.registerWithEmail(
        email: email,
        password: password,
        name: name.trim(),
        age: age.trim(),
        birthDate: birthDate,
        gender: gender.trim(),
      );
    } finally {
      _setBootstrapping(false);
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle() async {
    _setBootstrapping(true);
    try {
      final credential = await _repository.signInWithGoogle();
      return credential != null;
    } finally {
      _setBootstrapping(false);
      notifyListeners();
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _repository.sendPasswordResetEmail(email);
  }

  /// Kirim ulang email verifikasi.
  Future<void> resendVerificationEmail() async {
    await _repository.sendEmailVerification();
  }

  /// Reload user dari server lalu notify, untuk mengecek status verifikasi.
  /// Mengembalikan true jika email sudah terverifikasi.
  Future<bool> refreshVerificationStatus() async {
    final updated = await _repository.reloadUser();
    if (updated != null) {
      _user = updated;
    }

    notifyListeners();
    return _user?.emailVerified ?? false;
  }

  Future<void> deleteAccount({String? password}) async {
    await _repository.deleteAccount(password: password);
    await NotificationService.instance.cancelAll();
  }

  Future<void> logout() async {
    await NotificationService.instance.cancelAll();
    await _repository.logout();
  }
}
