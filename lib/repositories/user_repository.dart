import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/cloudinary_service.dart';
import '../services/connectivity_service.dart';
import '../services/firestore_service.dart';

class UserRepository {
  final FirebaseAuth? _firebaseAuth;
  final FirestoreService _firestoreService;
  final CloudinaryService _cloudinaryService;

  UserRepository({
    FirebaseAuth? auth,
    FirestoreService? firestoreService,
    CloudinaryService? cloudinaryService,
  })  : _firebaseAuth = auth,
        _firestoreService = firestoreService ?? FirestoreService.instance,
        _cloudinaryService = cloudinaryService ?? CloudinaryService.instance;

  FirebaseAuth get _auth => _firebaseAuth ?? FirebaseAuth.instance;

  Future<UserModel> getUserProfile(String uid) async {
    final currentUser = _auth.currentUser;
    String fallbackName = currentUser?.displayName?.trim() ?? '';
    if (fallbackName.isEmpty && currentUser?.email != null) {
      fallbackName = currentUser!.email!.split('@').first;
    }
    if (fallbackName.isEmpty) {
      fallbackName = 'Pengguna';
    }

    try {
      final doc = await _firestoreService.getDocumentSnapshot(
        _firestoreService.userDoc(uid),
      );
      if (doc.exists && doc.data() != null) {
        final rawData = doc.data()!;
        if (!doc.metadata.isFromCache &&
            UserModel.hasDeprecatedFields(rawData)) {
          unawaited(_cleanupDeprecatedFields(uid));
        }
        final parsed = UserModel.fromMap(rawData, uidFallback: uid);
        return parsed.copyWith(
          email: parsed.email.isNotEmpty
              ? parsed.email
              : (currentUser?.email ?? ''),
          name: parsed.name.isNotEmpty ? parsed.name : fallbackName,
          profileImageUrl: (parsed.profileImageUrl != null &&
                  parsed.profileImageUrl!.isNotEmpty)
              ? parsed.profileImageUrl
              : currentUser?.photoURL,
        );
      }
    } on OfflineException {
      // Jika dokumen profil belum pernah tersimpan di cache lokal saat offline,
      // kembalikan profil minimal dari sesi FirebaseAuth agar layar tetap tampil.
    }

    return UserModel(
      uid: uid,
      email: currentUser?.email ?? '',
      name: fallbackName,
      profileImageUrl: currentUser?.photoURL,
    );
  }

  Future<void> _cleanupDeprecatedFields(String uid) async {
    try {
      await _firestoreService.userDoc(uid).update({
        for (final field in UserModel.deprecatedFields)
          field: FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('Pembersihan field profil usang dilewati: $e');
    }
  }

  Future<UserModel> updateUserProfile({
    required String uid,
    required String name,
    File? newImageFile,
    String? currentImageUrl,
    bool removeImage = false,
    String? occupationStatus,
    bool updateOccupationStatus = false,
  }) async {
    _firestoreService.ensureOnline(actionLabel: 'memperbarui profil');
    String? finalImageUrl = currentImageUrl;

    if (newImageFile != null) {
      finalImageUrl = await _cloudinaryService.uploadImage(newImageFile);
    } else if (removeImage) {
      finalImageUrl = null;
    }

    final trimmedName = name.trim().isEmpty ? 'Pengguna' : name.trim();
    final trimmedOccupation = occupationStatus?.trim() ?? '';
    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.uid == uid) {
      await currentUser.updateDisplayName(trimmedName);
      await currentUser.updatePhotoURL(finalImageUrl);
    }

    await _firestoreService.userDoc(uid).set(
      {
        'uid': uid,
        if (currentUser?.email != null) 'email': currentUser!.email,
        'name': trimmedName,
        'profileImageUrl': finalImageUrl,
        if (updateOccupationStatus)
          'occupationStatus': trimmedOccupation.isNotEmpty
              ? trimmedOccupation
              : FieldValue.delete(),
        for (final field in UserModel.deprecatedFields)
          field: FieldValue.delete(),
      },
      SetOptions(merge: true),
    );

    if (currentUser != null && currentUser.uid == uid) {
      await currentUser.reload();
    }

    return getUserProfile(uid);
  }

  Future<void> updatePersonalization({
    required String uid,
    String? occupationStatus,
    required FeenTone feenTone,
  }) async {
    _firestoreService.ensureOnline(
      actionLabel: 'menyimpan preferensi personalisasi Feen',
    );
    final trimmedOccupation = occupationStatus?.trim() ?? '';
    await _firestoreService.userDoc(uid).set(
      {
        'occupationStatus': trimmedOccupation.isNotEmpty
            ? trimmedOccupation
            : FieldValue.delete(),
        'feenTone': feenTone.id,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveFeenEquipped(String uid, Map<String, String> equipped) {
    _firestoreService.ensureOnline(actionLabel: 'mengubah aksesoris Feen');
    return _firestoreService.userDoc(uid).set(
      {'feenEquipped': equipped},
      SetOptions(mergeFields: ['feenEquipped']),
    );
  }

  Future<void> incrementXp(String uid, int amount) {
    _firestoreService.ensureOnline(actionLabel: 'mengklaim hadiah XP');
    return _firestoreService.userDoc(uid).set(
      {'xp': FieldValue.increment(amount)},
      SetOptions(merge: true),
    );
  }

  Future<void> markInitialBalanceOnboardingDone(String uid) {
    _firestoreService.ensureOnline(
      actionLabel: 'menyimpan status pengaturan saldo awal',
    );
    return _firestoreService.userDoc(uid).set(
      {'initialBalanceOnboardingDone': true},
      SetOptions(mergeFields: ['initialBalanceOnboardingDone']),
    );
  }
}
