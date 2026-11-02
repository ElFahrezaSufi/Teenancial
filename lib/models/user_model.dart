import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String age;
  final String gender;
  final String? profileImageUrl;
  final bool walletSeeded;
  final List<String> completedModules;
  final List<String> completedQuizzes;

  const UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.age = '',
    this.gender = '',
    this.profileImageUrl,
    this.walletSeeded = false,
    this.completedModules = const [],
    this.completedQuizzes = const [],
  });

  Map<String, dynamic> toMap({bool includeCreatedAt = false}) {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'age': age,
      'gender': gender,
      'profileImageUrl': profileImageUrl,
      'walletSeeded': walletSeeded,
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

    return UserModel(
      uid: (map['uid'] as String?) ?? uidFallback ?? '',
      email: (map['email'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Pengguna',
      age: (map['age'] ?? '').toString(),
      gender: (map['gender'] ?? '').toString().trim(),
      profileImageUrl: map['profileImageUrl'] as String?,
      walletSeeded: map['walletSeeded'] == true,
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
    String? gender,
    String? profileImageUrl,
    bool clearProfileImage = false,
    bool? walletSeeded,
    List<String>? completedModules,
    List<String>? completedQuizzes,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      profileImageUrl: clearProfileImage
          ? null
          : (profileImageUrl ?? this.profileImageUrl),
      walletSeeded: walletSeeded ?? this.walletSeeded,
      completedModules: completedModules ?? this.completedModules,
      completedQuizzes: completedQuizzes ?? this.completedQuizzes,
    );
  }
}
