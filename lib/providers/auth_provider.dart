import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthRepository _repository = AuthRepository();

  User? _user;
  User? get user => _user;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _auth.authStateChanges().listen((User? newUser) {
      _user = newUser;

      if (newUser == null) {
        _clearUserData();
      }
      notifyListeners();
    });
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
    await _repository.registerWithEmail(
      email: email,
      password: password,
      name: name,
      age: age,
      gender: gender,
    );

    await logout();
  }

  Future<void> signInWithGoogle() async {
    await _repository.signInWithGoogle();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _repository.sendPasswordResetEmail(email);
  }

  Future<void> logout() async {
    await _repository.logout();
  }
}
