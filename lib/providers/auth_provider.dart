import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../repositories/auth_repository.dart';

final ValueNotifier<bool> registrationInProgress = ValueNotifier<bool>(false);

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthRepository _repository = AuthRepository();

  User? _user;
  bool _bootstrapInProgress = false;

  User? get user => _user;
  bool get isAuthenticated =>
      _user != null && !registrationInProgress.value && !_bootstrapInProgress;

  /// UID aktif untuk seluruh feature provider. Bernilai null saat belum login,
  /// saat proses registrasi email berlangsung, atau saat bootstrap akun Google
  /// belum selesai menulis dompet awal.
  String? get activeUid =>
      (registrationInProgress.value || _bootstrapInProgress)
          ? null
          : _user?.uid;

  late final StreamSubscription<User?> _authSub;

  AuthProvider() {
    _user = _auth.currentUser;
    registrationInProgress.addListener(_onRegistrationStateChanged);
    _authSub = _auth.authStateChanges().listen((User? newUser) {
      final bool sessionEnded = newUser == null;
      final bool accountSwitched =
          _user != null && newUser != null && _user!.uid != newUser.uid;

      _user = newUser;

      if (sessionEnded || accountSwitched) {
        _clearUserData();
      }
      notifyListeners();
    });
  }

  void _onRegistrationStateChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    registrationInProgress.removeListener(_onRegistrationStateChanged);
    _authSub.cancel();
    super.dispose();
  }

  void _clearUserData() {
    debugPrint(
      'Sesi berakhir: Membersihkan sisa data lokal di seluruh Provider...',
    );
  }

  Future<void> login(String email, String password) async {
    await _repository.loginWithEmail(email, password);
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String age,
    required String gender,
  }) async {
    registrationInProgress.value = true;
    try {
      await _repository.registerWithEmail(
        email: email,
        password: password,
        name: name,
        age: age,
        gender: gender,
      );
      await _repository.logout();
    } catch (_) {
      try {
        await _repository.logout();
      } catch (_) {}
      rethrow;
    } finally {
      registrationInProgress.value = false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _bootstrapInProgress = true;
    try {
      final credential = await _repository.signInWithGoogle();
      return credential != null;
    } finally {
      _bootstrapInProgress = false;
      notifyListeners();
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _repository.sendPasswordResetEmail(email);
  }

  Future<void> logout() async {
    await _repository.logout();
  }
}
