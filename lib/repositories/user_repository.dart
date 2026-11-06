import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';

class UserRepository {
  final FirebaseAuth _auth;
  final FirestoreService _firestoreService;
  final CloudinaryService _cloudinaryService;

  UserRepository({
    FirebaseAuth? auth,
    FirestoreService? firestoreService,
    CloudinaryService? cloudinaryService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestoreService = firestoreService ?? FirestoreService.instance,
        _cloudinaryService = cloudinaryService ?? CloudinaryService.instance;

  Future<UserModel> getUserProfile(String uid) async {
    final currentUser = _auth.currentUser;
    String fallbackName = currentUser?.displayName?.trim() ?? '';
    if (fallbackName.isEmpty && currentUser?.email != null) {
      fallbackName = currentUser!.email!.split('@').first;
    }
    if (fallbackName.isEmpty) {
      fallbackName = 'Pengguna';
    }

    final doc = await _firestoreService.userDoc(uid).get();
    if (doc.exists && doc.data() != null) {
      final parsed = UserModel.fromMap(doc.data()!, uidFallback: uid);
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

    return UserModel(
      uid: uid,
      email: currentUser?.email ?? '',
      name: fallbackName,
      profileImageUrl: currentUser?.photoURL,
    );
  }

  Future<UserModel> updateUserProfile({
    required String uid,
    required String name,
    required String age,
    DateTime? birthDate,
    required String gender,
    File? newImageFile,
    String? currentImageUrl,
    bool removeImage = false,
  }) async {
    String? finalImageUrl = currentImageUrl;

    if (newImageFile != null) {
      finalImageUrl = await _cloudinaryService.uploadImage(newImageFile);
    } else if (removeImage) {
      finalImageUrl = null;
    }

    final trimmedName = name.trim().isEmpty ? 'Pengguna' : name.trim();
    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.uid == uid) {
      await currentUser.updateDisplayName(trimmedName);
      await currentUser.updatePhotoURL(finalImageUrl);
    }

    final resolvedAge = birthDate != null
        ? UserModel.calculateAge(birthDate).toString()
        : age.trim();

    await _firestoreService.userDoc(uid).set(
      {
        'uid': uid,
        if (currentUser?.email != null) 'email': currentUser!.email,
        'name': trimmedName,
        'age': resolvedAge,
        'birthDate': birthDate != null ? Timestamp.fromDate(birthDate) : null,
        'gender': gender.trim(),
        'profileImageUrl': finalImageUrl,
      },
      SetOptions(merge: true),
    );

    if (currentUser != null && currentUser.uid == uid) {
      await currentUser.reload();
    }

    return getUserProfile(uid);
  }
}
