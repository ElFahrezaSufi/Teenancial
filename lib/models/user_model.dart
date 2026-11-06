import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String age;
  final DateTime? birthDate;
  final String gender;
  final String? profileImageUrl;
  final List<String> completedModules;
  final List<String> completedQuizzes;

  const UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.age = '',
    this.birthDate,
    this.gender = '',
    this.profileImageUrl,
    this.completedModules = const [],
    this.completedQuizzes = const [],
  });

  /// Menghitung umur (dalam tahun) dari [birthDate] terhadap [now].
  static int calculateAge(DateTime birthDate, {DateTime? now}) {
    final today = now ?? DateTime.now();
    int years = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      years--;
    }
    return years < 0 ? 0 : years;
  }

  Map<String, dynamic> toMap({bool includeCreatedAt = false}) {
    final effectiveAge =
        birthDate != null ? calculateAge(birthDate!).toString() : age;
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'age': effectiveAge,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'gender': gender,
      'profileImageUrl': profileImageUrl,
      'completedModules': completedModules,
      'completedQuizzes': completedQuizzes,
      if (includeCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory UserModel.fromMap(
    Map<String, dynamic> map, {
    String? uidFallback,
  }) {
    final rawModules = map['completedModules'];
    final rawQuizzes = map['completedQuizzes'];
    final rawBirthDate = map['birthDate'];

    DateTime? parsedBirthDate;
    if (rawBirthDate is Timestamp) {
      parsedBirthDate = rawBirthDate.toDate();
    } else if (rawBirthDate is String && rawBirthDate.isNotEmpty) {
      parsedBirthDate = DateTime.tryParse(rawBirthDate);
    }

    final resolvedAge = parsedBirthDate != null
        ? calculateAge(parsedBirthDate).toString()
        : (map['age'] ?? '').toString();

    return UserModel(
      uid: (map['uid'] as String?) ?? uidFallback ?? '',
      email: (map['email'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Pengguna',
      age: resolvedAge,
      birthDate: parsedBirthDate,
      gender: (map['gender'] ?? '').toString().trim(),
      profileImageUrl: map['profileImageUrl'] as String?,
      completedModules: rawModules is Iterable
          ? rawModules.map((e) => e.toString()).toList()
          : const [],
      completedQuizzes: rawQuizzes is Iterable
          ? rawQuizzes.map((e) => e.toString()).toList()
          : const [],
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? age,
    DateTime? birthDate,
    bool clearBirthDate = false,
    String? gender,
    String? profileImageUrl,
    bool clearProfileImage = false,
    List<String>? completedModules,
    List<String>? completedQuizzes,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      age: age ?? this.age,
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      gender: gender ?? this.gender,
      profileImageUrl: clearProfileImage
          ? null
          : (profileImageUrl ?? this.profileImageUrl),
      completedModules: completedModules ?? this.completedModules,
      completedQuizzes: completedQuizzes ?? this.completedQuizzes,
    );
  }
}
