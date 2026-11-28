import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  /// Field profil usang yang sudah dihapus dari aplikasi dan dibersihkan
  /// otomatis dari dokumen Firestore akun lama via `FieldValue.delete()`.
  static const List<String> deprecatedFields = ['age', 'birthDate', 'gender'];

  static bool hasDeprecatedFields(Map<String, dynamic> map) =>
      deprecatedFields.any(map.containsKey);

  final String uid;
  final String email;
  final String name;
  final String? profileImageUrl;
  final List<String> completedModules;
  final List<String> completedQuizzes;
  final int xp;
  final Map<String, String> feenEquipped;
  final bool initialBalanceOnboardingDone;

  const UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.profileImageUrl,
    this.completedModules = const [],
    this.completedQuizzes = const [],
    this.xp = 0,
    this.feenEquipped = const {},
    this.initialBalanceOnboardingDone = true,
  });

  Map<String, dynamic> toMap({bool includeCreatedAt = false}) {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'profileImageUrl': profileImageUrl,
      'completedModules': completedModules,
      'completedQuizzes': completedQuizzes,
      'xp': xp,
      'feenEquipped': feenEquipped,
      'initialBalanceOnboardingDone': initialBalanceOnboardingDone,
      if (includeCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory UserModel.fromMap(
    Map<String, dynamic> map, {
    String? uidFallback,
  }) {
    final rawModules = map['completedModules'];
    final rawQuizzes = map['completedQuizzes'];
    final rawXp = map['xp'];
    final rawEquipped = map['feenEquipped'];

    return UserModel(
      uid: (map['uid'] as String?) ?? uidFallback ?? '',
      email: (map['email'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Pengguna',
      profileImageUrl: map['profileImageUrl'] as String?,
      completedModules: rawModules is Iterable
          ? rawModules
              .map((e) => e.toString().trim())
              .where(
                (id) => id.isNotEmpty && !RegExp(r'^\d+_\d+$').hasMatch(id),
              )
              .toSet()
              .toList()
          : const [],
      completedQuizzes: rawQuizzes is Iterable
          ? rawQuizzes
              .map((e) => e.toString().trim())
              .where(
                (id) => id.isNotEmpty && !RegExp(r'^\d+_\d+$').hasMatch(id),
              )
              .toSet()
              .toList()
          : const [],
      xp: rawXp is num ? rawXp.toInt() : 0,
      feenEquipped: rawEquipped is Map
          ? {
              for (final e in rawEquipped.entries)
                if (e.value != null) e.key.toString(): e.value.toString(),
            }
          : const {},
      // Default `true` untuk dokumen user lama yang belum memiliki field ini
      // agar pengguna lama tidak pernah mendapat popup onboarding saldo awal.
      initialBalanceOnboardingDone:
          map['initialBalanceOnboardingDone'] is bool
              ? map['initialBalanceOnboardingDone'] as bool
              : true,
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? profileImageUrl,
    bool clearProfileImage = false,
    List<String>? completedModules,
    List<String>? completedQuizzes,
    int? xp,
    Map<String, String>? feenEquipped,
    bool? initialBalanceOnboardingDone,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      profileImageUrl:
          clearProfileImage ? null : (profileImageUrl ?? this.profileImageUrl),
      completedModules: completedModules ?? this.completedModules,
      completedQuizzes: completedQuizzes ?? this.completedQuizzes,
      xp: xp ?? this.xp,
      feenEquipped: feenEquipped ?? this.feenEquipped,
      initialBalanceOnboardingDone:
          initialBalanceOnboardingDone ?? this.initialBalanceOnboardingDone,
    );
  }
}
