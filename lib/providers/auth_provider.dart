import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';

export '../repositories/auth_repository.dart'
    show AccountAlreadyVerifiedException, ReauthCanceledException;

class AuthProvider extends ChangeNotifier {
  static final ValueNotifier<bool> _bootstrapNotifier =
      ValueNotifier<bool>(false);
  static final ValueNotifier<int> _verificationNotifier = ValueNotifier<int>(0);

  static ValueListenable<bool> get bootstrapListenable => _bootstrapNotifier;
  static ValueListenable<int> get verificationListenable =>
      _verificationNotifier;

  final FirebaseAuth _auth;
  final AuthRepository _repository;

  User? _user;
  bool _bootstrapInProgress = false;

  User? get user => _user;
  bool get isBootstrapping => _bootstrapInProgress;
  bool get isAuthenticated =>
      _user != null && !_bootstrapInProgress && !needsEmailVerification;

  /// UID aktif untuk seluruh provider data. Bernilai `null` selama bootstrap
  /// atau selama akun Email/Password belum memverifikasi email agar provider
  /// data dan notifikasi tidak berjalan di latar belakang sebelum aktif.
  String? get activeUid =>
      (_bootstrapInProgress || needsEmailVerification) ? null : _user?.uid;

  /// Apakah akun email user sudah terverifikasi.
  bool get isEmailVerified => _user?.emailVerified ?? false;

  /// Apakah user memiliki provider Email & Password.
  bool get isEmailPasswordUser {
    final user = _user;
    if (user == null) return false;
    return user.providerData.any(
      (info) => info.providerId == EmailAuthProvider.PROVIDER_ID,
    );
  }

  /// True bila kombinasi provider & status verifikasi menandakan akun masih
  /// wajib menyelesaikan verifikasi email sebelum masuk aplikasi.
  @visibleForTesting
  static bool requiresEmailVerification({
    required Iterable<String> providerIds,
    required bool emailVerified,
  }) {
    final hasPasswordProvider = providerIds.any(
      (id) => id == EmailAuthProvider.PROVIDER_ID,
    );
    return hasPasswordProvider && !emailVerified;
  }

  /// True bila user login dengan Email/Password tetapi belum memverifikasi email.
  bool get needsEmailVerification {
    final user = _user;
    if (user == null) return false;
    return requiresEmailVerification(
      providerIds: user.providerData.map((info) => info.providerId),
      emailVerified: user.emailVerified,
    );
  }

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

  /// Login dengan email & password. Mengembalikan `true` jika akun sudah
  /// terverifikasi (atau non-email), dan `false` jika email masih belum
  /// diverifikasi agar pengguna diarahkan ke layar verifikasi.
  Future<bool> login(String email, String password) async {
    _setBootstrapping(true);
    try {
      final credential = await _repository.loginWithEmail(email, password);
      final user = credential.user;
      if (user == null) return false;

      try {
        await user.reload();
      } catch (_) {}

      final refreshed = _auth.currentUser ?? user;
      _user = refreshed;
      final isEmailPass = refreshed.providerData.any(
        (info) => info.providerId == EmailAuthProvider.PROVIDER_ID,
      );
      return !isEmailPass || refreshed.emailVerified;
    } finally {
      _setBootstrapping(false);
      notifyListeners();
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    String age = '',
    DateTime? birthDate,
    String gender = '',
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

  /// Mengubah password akun (butuh password lama).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// Kirim ulang email verifikasi.
  Future<void> resendVerificationEmail() async {
    await _repository.sendEmailVerification();
  }

  /// Reload user dari server lalu notify, untuk mengecek status verifikasi.
  /// Mengembalikan true jika email sudah terverifikasi.
  Future<bool> refreshVerificationStatus() async {
    final bool wasVerified = _user?.emailVerified ?? false;
    final updated = await _repository.reloadUser();
    if (updated != null) {
      _user = updated;
    }

    final bool isNowVerified = _user?.emailVerified ?? false;
    notifyListeners();
    if (!wasVerified && isNowVerified) {
      _verificationNotifier.value++;
    }
    return isNowVerified;
  }

  /// Membatalkan pendaftaran akun yang belum terverifikasi dan membersihkan
  /// akun Auth + dokumen bootstrap Firestore-nya.
  Future<void> cancelUnverifiedRegistration({String? password}) async {
    _setBootstrapping(true);
    try {
      await _repository.cancelUnverifiedRegistration(password: password);
      _user = _auth.currentUser;
      await NotificationService.instance.cancelAll();
    } finally {
      _setBootstrapping(false);
      notifyListeners();
    }
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
