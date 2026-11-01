class UserModel {
  final String id;
  final String email;
  final String name;
  final String age;
  final String gender;
  final String passwordHash; // SHA-256(salt + password), hex
  final String salt;
  final String? avatarPath; // Path foto profil (di folder aplikasi)

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.age = '',
    this.gender = '',
    required this.passwordHash,
    required this.salt,
    this.avatarPath,
  });

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? age,
    String? gender,
    String? passwordHash,
    String? salt,
    String? avatarPath,
    bool clearAvatar = false,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'age': age,
        'gender': gender,
        'passwordHash': passwordHash,
        'salt': salt,
        'avatarPath': avatarPath,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: (json['name'] as String?) ?? 'Pengguna',
      age: (json['age'] as String?) ?? '',
      gender: (json['gender'] as String?) ?? '',
      passwordHash: json['passwordHash'] as String,
      salt: json['salt'] as String,
      avatarPath: json['avatarPath'] as String?,
    );
  }
}
