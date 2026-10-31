import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/auth_repository.dart';

final ValueNotifier<bool> registrationInProgress = ValueNotifier<bool>(false);

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthRepository _repository = AuthRepository();

  User? _user;
  User? get user => _user;
  bool get isAuthenticated => _user != null;

  late final StreamSubscription<User?> _authSub;

  AuthProvider() {
    _user = _auth.currentUser;
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

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  void _clearUserData() {
    // Logika reset saldo/profil diletakkan di sini nanti
    debugPrint(
        "Sesi berakhir: Membersihkan sisa data lokal agar tidak bocor...");
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
    final credential = await _repository.signInWithGoogle();
    return credential != null;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _repository.sendPasswordResetEmail(email);
  }

  Future<void> logout() async {
    await _repository.logout();
  }
}
