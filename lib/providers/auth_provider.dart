import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  static final ValueNotifier<bool> _bootstrapNotifier =
      ValueNotifier<bool>(false);

  /// Read-only listenable untuk memberi tahu router saat proses bootstrap
  /// akun baru (registrasi email / Google Sign-In) sedang berjalan atau selesai.
  static ValueListenable<bool> get bootstrapListenable => _bootstrapNotifier;

  final FirebaseAuth _auth;
  final AuthRepository _repository;

  User? _user;
  bool _bootstrapInProgress = false;

  User? get user => _user;
  bool get isBootstrapping => _bootstrapInProgress;
  bool get isAuthenticated => _user != null && !_bootstrapInProgress;

  /// UID aktif untuk seluruh feature provider. Bernilai null saat belum login,
  /// atau saat proses bootstrap akun baru (registrasi email / Google Sign-In)
  /// belum selesai menulis profil & dompet awal di Firestore.
  String? get activeUid => _bootstrapInProgress ? null : _user?.uid;

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

  Future<void> login(String email, String password) async {
    await _repository.loginWithEmail(email, password);
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

  Future<void> logout() async {
    await NotificationService.instance.cancelAll();
    await _repository.logout();
  }
}
