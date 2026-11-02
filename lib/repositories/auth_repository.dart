import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../data/legacy_wallet_catalog.dart';
import '../services/firestore_service.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService;

  AuthRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService.instance;

  Future<UserCredential> loginWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required String age,
    required String gender,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      try {
        await user.updateDisplayName(name.trim());

        final initialWallet = LegacyWalletCatalog.buildNewUserInitialWallet();
        final batch = _firestoreService.batch();

        batch.set(_firestoreService.userDoc(user.uid), {
          'uid': user.uid,
          'email': user.email,
          'name': name.trim(),
          'age': age.trim(),
          'gender': gender.trim(),
          'walletSeeded': true,
          'completedModules': <String>[],
          'completedQuizzes': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
        });

        batch.set(
          _firestoreService.walletsCol(user.uid).doc(initialWallet.id),
          initialWallet.toMap(),
        );

        await batch.commit();
      } catch (_) {
        try {
          await user.delete();
        } catch (_) {}
        rethrow;
      }
    }
    return credential;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  static Future<void>? _googleInit;

  Future<void> _ensureGoogleInitialized() {
    return _googleInit ??= () async {
      try {
        await GoogleSignIn.instance.initialize();
      } catch (_) {
        _googleInit = null;
        rethrow;
      }
    }();
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final UserCredential userCredential;

      if (kIsWeb) {
        userCredential = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        await _ensureGoogleInitialized();
        final GoogleSignInAccount googleUser =
            await GoogleSignIn.instance.authenticate();

        final googleAuth = googleUser.authentication;
        if (googleAuth.idToken == null) {
          throw Exception(
            'Token autentikasi Google (idToken) tidak ditemukan.',
          );
        }

        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      final user = userCredential.user;
      if (user != null) {
        final userDocRef = _firestoreService.userDoc(user.uid);
        final bool isNewUser =
            userCredential.additionalUserInfo?.isNewUser == true;

        if (isNewUser) {
          final initialWallet = LegacyWalletCatalog.buildNewUserInitialWallet();
          final batch = _firestoreService.batch();

          batch.set(userDocRef, {
            'uid': user.uid,
            'email': user.email,
            'name': user.displayName ?? 'Pengguna Baru',
            'age': '',
            'gender': '',
            if (user.photoURL != null && user.photoURL!.isNotEmpty)
              'profileImageUrl': user.photoURL,
            'walletSeeded': true,
            'completedModules': <String>[],
            'completedQuizzes': <String>[],
            'createdAt': FieldValue.serverTimestamp(),
          });

          batch.set(
            _firestoreService.walletsCol(user.uid).doc(initialWallet.id),
            initialWallet.toMap(),
          );

          await batch.commit();
        } else if (!(await userDocRef.get()).exists) {
          // Akun lama yang belum memiliki dokumen users/{uid}:
          // Biarkan walletSeeded = false agar DompetRepository men-seed 6 dompet existing.
          await userDocRef.set({
            'uid': user.uid,
            'email': user.email,
            'name': user.displayName ?? 'Pengguna',
            'age': '',
            'gender': '',
            if (user.photoURL != null && user.photoURL!.isNotEmpty)
              'profileImageUrl': user.photoURL,
            'walletSeeded': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return userCredential;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint(
          'Login Google dibatalkan / ditolak Credential Manager: '
          '${e.description ?? e.code.name}',
        );
        return null;
      }
      debugPrint('Error Login Google (${e.code.name}): ${e.description}');
      throw Exception('Gagal masuk dengan Google: ${e.description ?? e}');
    } on FirebaseAuthException catch (e) {
      if (kIsWeb &&
          (e.code == 'popup-closed-by-user' ||
              e.code == 'cancelled-popup-request')) {
        debugPrint('Popup Login Google ditutup oleh pengguna.');
        return null;
      }
      debugPrint('Error Firebase Login Google (${e.code}): ${e.message}');
      throw Exception('Gagal masuk dengan Google: ${e.message ?? e.code}');
    } catch (e) {
      debugPrint('Error Login Google: $e');
      throw Exception('Gagal masuk dengan Google: $e');
    }
  }

  Future<void> logout() async {
    final bool isGoogleUser = _auth.currentUser?.providerData.any(
          (info) => info.providerId == GoogleAuthProvider.PROVIDER_ID,
        ) ??
        false;

    if (!kIsWeb && (isGoogleUser || _googleInit != null)) {
      try {
        await _ensureGoogleInitialized();
        await GoogleSignIn.instance.signOut();
      } catch (e) {
        debugPrint('Gagal membersihkan sesi Google Sign-In: $e');
      }
    }

    await _auth.signOut();
  }
}
