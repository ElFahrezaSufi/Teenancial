import 'package:cloud_firestore/cloud_firestore.dart';

/// Gaya bahasa balasan chatbot Tanya Feen yang dapat dipilih pengguna.
enum FeenTone {
  casual(
    'casual',
    'Santai & Akrab',
    'Bahasa teman sebaya yang hangat dan santai',
  ),
  concise(
    'concise',
    'Ringkas & Langsung ke Inti',
    'Poin singkat, cepat dibaca, tanpa basa-basi',
  ),
  educational(
    'educational',
    'Rapi & Edukatif',
    'Terstruktur seperti mentor keuangan yang jelas',
  );

  final String id;
  final String label;
  final String description;

  const FeenTone(this.id, this.label, this.description);

  static FeenTone fromId(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    for (final tone in FeenTone.values) {
      if (tone.id == normalized) return tone;
    }
    return FeenTone.casual;
  }
}

class UserModel {
  /// Field profil usang yang sudah dihapus dari aplikasi dan dibersihkan
  /// otomatis dari dokumen Firestore akun lama via `FieldValue.delete()`.
  static const List<String> deprecatedFields = ['age', 'birthDate', 'gender'];

  /// Pilihan baku status pendidikan/pekerjaan opsional untuk personalisasi Feen.
  static const List<String> occupationOptions = [
    'Pelajar SMP / SMA',
    'Mahasiswa',
    'Pekerja / Magang',
    'Freelance / Usaha Sendiri',
  ];

  static bool hasDeprecatedFields(Map<String, dynamic> map) =>
      deprecatedFields.any(map.containsKey);

  static String? _normalizeOccupation(dynamic raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  final String uid;
  final String email;
  final String name;
  final String? profileImageUrl;
  final String? occupationStatus;
  final FeenTone feenTone;
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
    this.occupationStatus,
    this.feenTone = FeenTone.casual,
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
      if (occupationStatus != null && occupationStatus!.trim().isNotEmpty)
        'occupationStatus': occupationStatus!.trim(),
      'feenTone': feenTone.id,
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
      occupationStatus: _normalizeOccupation(map['occupationStatus']),
      feenTone: FeenTone.fromId(map['feenTone'] as String?),
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
    String? occupationStatus,
    bool clearOccupationStatus = false,
    FeenTone? feenTone,
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
      occupationStatus: clearOccupationStatus
          ? null
          : (occupationStatus ?? this.occupationStatus),
      feenTone: feenTone ?? this.feenTone,
      completedModules: completedModules ?? this.completedModules,
      completedQuizzes: completedQuizzes ?? this.completedQuizzes,
      xp: xp ?? this.xp,
      feenEquipped: feenEquipped ?? this.feenEquipped,
      initialBalanceOnboardingDone:
          initialBalanceOnboardingDone ?? this.initialBalanceOnboardingDone,
    );
  }
}
