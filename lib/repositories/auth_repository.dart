import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/dompet_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

/// Dilempar ketika pengguna membatalkan proses re-autentikasi Google.
class ReauthCanceledException implements Exception {
  const ReauthCanceledException();
}

class AuthRepository {
  final FirebaseAuth? _firebaseAuth;
  final FirestoreService _firestoreService;

  AuthRepository({
    FirebaseAuth? auth,
    FirestoreService? firestoreService,
  })  : _firebaseAuth = auth,
        _firestoreService = firestoreService ?? FirestoreService.instance;

  FirebaseAuth get _auth => _firebaseAuth ?? FirebaseAuth.instance;
  Future<void> ensureUserBootstrapped(
    User user, {
    String? name,
    String? age,
    DateTime? birthDate,
    String? gender,
  }) async {
    final userDocRef = _firestoreService.userDoc(user.uid);
    final initialWallet = DompetItem.initialWallet();
    final walletDocRef =
        _firestoreService.walletsCol(user.uid).doc(initialWallet.id);

    await _firestoreService.runTransaction((fsTx) async {
      final userSnap = await fsTx.get(userDocRef);
      if (userSnap.exists) return;

      final walletSnap = await fsTx.get(walletDocRef);
      final resolvedName = (name != null && name.trim().isNotEmpty)
          ? name.trim()
          : (user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : 'Pengguna Baru');
      final resolvedAge = birthDate != null
          ? UserModel.calculateAge(birthDate).toString()
          : (age ?? '').trim();

      fsTx.set(userDocRef, {
        'uid': user.uid,
        'email': user.email,
        'name': resolvedName,
        'age': resolvedAge,
        if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate),
        'gender': (gender ?? '').trim(),
        if (user.photoURL != null && user.photoURL!.isNotEmpty)
          'profileImageUrl': user.photoURL,
        'completedModules': <String>[],
        'completedQuizzes': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!walletSnap.exists) {
        fsTx.set(walletDocRef, initialWallet.toMap());
      }
    });
  }

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
    DateTime? birthDate,
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
        await ensureUserBootstrapped(
          user,
          name: name,
          age: age,
          birthDate: birthDate,
          gender: gender,
        );
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
        await ensureUserBootstrapped(user);
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

  Future<void> _deleteCollectionDocs(Query colRef) async {
    while (true) {
      final snap = await colRef.limit(300).get();
      if (snap.docs.isEmpty) break;
      final batch = _firestoreService.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> deleteUserFirestoreData(String uid) async {
    final txSnap = await _firestoreService.transactionsCol(uid).get();
    for (final txDoc in txSnap.docs) {
      await _deleteCollectionDocs(txDoc.reference.collection('payments'));
    }
    await _deleteCollectionDocs(_firestoreService.transactionsCol(uid));
    await _deleteCollectionDocs(_firestoreService.walletsCol(uid));
    await _deleteCollectionDocs(_firestoreService.contactsCol(uid));
    await _deleteCollectionDocs(_firestoreService.targetsCol(uid));
    await _deleteCollectionDocs(_firestoreService.categoriesCol(uid));
    await _deleteCollectionDocs(_firestoreService.recurringCol(uid));
    await _deleteCollectionDocs(
      _firestoreService.userDoc(uid).collection('gamification'),
    );
    await _firestoreService.userDoc(uid).delete();
  }

  bool _isGoogleAccount(User user) {
    return user.providerData.any(
      (info) => info.providerId == GoogleAuthProvider.PROVIDER_ID,
    );
  }

  /// Memvalidasi kecocokan email akun Google yang dipilih saat reautentikasi
  /// terhadap email akun Firebase yang sedang login (case-insensitive).
  @visibleForTesting
  static bool isMatchingGoogleEmail(
    String? expectedEmail,
    String? pickedEmail,
  ) {
    final expected = expectedEmail?.trim().toLowerCase();
    final picked = pickedEmail?.trim().toLowerCase();
    if (expected == null ||
        expected.isEmpty ||
        picked == null ||
        picked.isEmpty) {
      return true;
    }
    return expected == picked;
  }

  Future<void> _clearGoogleCredentialSelection() async {
    if (kIsWeb) return;
    try {
      await _ensureGoogleInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  Future<void> _reauthenticateUser(User user, {String? password}) async {
    if (_isGoogleAccount(user)) {
      if (kIsWeb) {
        try {
          await user.reauthenticateWithPopup(GoogleAuthProvider());
        } on FirebaseAuthException catch (e) {
          if (e.code == 'popup-closed-by-user' ||
              e.code == 'cancelled-popup-request') {
            throw const ReauthCanceledException();
          }
          rethrow;
        }
        return;
      }

      await _ensureGoogleInitialized();
      final GoogleSignInAccount googleUser;
      try {
        googleUser = await GoogleSignIn.instance.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          throw const ReauthCanceledException();
        }
        rethrow;
      }

      if (!isMatchingGoogleEmail(user.email, googleUser.email)) {
        await _clearGoogleCredentialSelection();
        throw FirebaseAuthException(
          code: 'user-mismatch',
          message:
              'Akun Google yang dipilih tidak sesuai dengan akun yang sedang login.',
        );
      }

      final googleAuth = googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw Exception('Verifikasi Google gagal.');
      }
      final cred = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
      await user.reauthenticateWithCredential(cred);
      return;
    }

    if (password != null && password.isNotEmpty && user.email != null) {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
    }
  }

  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Sesi pengguna tidak ditemukan.');
    }

    final uid = user.uid;
    final bool isGoogleUser = _isGoogleAccount(user);

    if (isGoogleUser) {
      await _reauthenticateUser(user);
    } else {
      if (password == null || password.trim().isEmpty) {
        throw FirebaseAuthException(
          code: 'requires-recent-login',
          message: 'Password diperlukan untuk menghapus akun.',
        );
      }
      await _reauthenticateUser(user, password: password.trim());
    }

    await deleteUserFirestoreData(uid);
    await user.delete();

    if (!kIsWeb && (isGoogleUser || _googleInit != null)) {
      await _clearGoogleCredentialSelection();
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
