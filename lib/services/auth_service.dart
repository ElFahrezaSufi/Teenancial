import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../config/storage_keys.dart';
import '../models/user_model.dart';
import 'storage_service.dart';

enum LoginResult { success, emailNotFound, wrongPassword }

/// Menyimpan akun pengguna (lokal) dan sesi login.
/// Password tidak pernah disimpan polos: disimpan sebagai SHA-256(salt + password).
class AuthService {
  final StorageService _storage;
  List<UserModel> _users = [];

  AuthService(this._storage);

  /// Nilai pada kunci `seeded(userId)` yang berarti "isi data contoh saat
  /// pertama kali dimuat". Dibaca oleh provider data.
  static const String seedPending = 'pending';

  List<UserModel> get users => List.unmodifiable(_users);

  // ---------------------------------------------------------------- hashing

  static String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String hashPassword(String password, String salt) {
    return sha256.convert(utf8.encode('$salt$password')).toString();
  }

  // ------------------------------------------------------------------- init

  Future<void> init() async {
    final stored = _storage.readList(StorageKeys.users);
    if (stored.isNotEmpty) {
      _users = _decodeUsers(stored);
      return;
    }

    if (_storage.containsKey(StorageKeys.legacyUsers)) {
      await _migrateLegacyUsers();
      return;
    }

    // Instalasi baru: buat akun contoh.
    final demo = _newUser(
      email: AppConfig.demoUserEmail,
      password: 'password123',
      name: 'Dummy User',
      age: '17',
      gender: 'Laki-laki',
    );
    _users = [demo];
    await _storage.setString(StorageKeys.seeded(demo.id), seedPending);
    await _persistUsers();
  }

  List<UserModel> _decodeUsers(List<Map<String, dynamic>> raw) {
    final result = <UserModel>[];
    for (final json in raw) {
      try {
        result.add(UserModel.fromJson(json));
      } catch (e) {
        debugPrint('AuthService: akun rusak dilewati ($e)');
      }
    }
    return result;
  }

  /// Memigrasikan format lama (`mock_users`: password polos, tanpa id) ke
  /// UserModel ber-UUID dengan password ter-hash. Sesi lama ikut dipindahkan.
  Future<void> _migrateLegacyUsers() async {
    final raw = _storage.getString(StorageKeys.legacyUsers);
    final migrated = <UserModel>[];
    try {
      final decoded = jsonDecode(raw ?? '[]') as List<dynamic>;
      for (final entry in decoded) {
        final map = Map<String, dynamic>.from(entry as Map);
        final email = (map['email'] as String?) ?? '';
        if (email.isEmpty) continue;
        migrated.add(_newUser(
          email: email,
          password: (map['password'] as String?) ?? '',
          name: (map['name'] as String?) ?? 'Pengguna',
          age: (map['age'] as String?) ?? '',
          gender: (map['gender'] as String?) ?? '',
        ));
      }
    } catch (e) {
      debugPrint('AuthService: migrasi akun lama gagal ($e)');
    }

    _users = migrated;
    for (final user in migrated) {
      if (_sameEmail(user.email, AppConfig.demoUserEmail)) {
        await _storage.setString(StorageKeys.seeded(user.id), seedPending);
      }
    }
    await _persistUsers();

    final legacyActive = _storage.getString(StorageKeys.legacyActiveEmail);
    if (legacyActive != null && legacyActive.isNotEmpty) {
      final user = findByEmail(legacyActive);
      if (user != null) {
        await _storage.setString(StorageKeys.activeUserId, user.id);
      }
    }

    await _storage.remove(StorageKeys.legacyUsers);
    if (_storage.containsKey(StorageKeys.legacyActiveEmail)) {
      await _storage.remove(StorageKeys.legacyActiveEmail);
    }
  }

  // ---------------------------------------------------------------- queries

  static bool _sameEmail(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  UserModel? findByEmail(String email) {
    for (final user in _users) {
      if (_sameEmail(user.email, email)) return user;
    }
    return null;
  }

  UserModel? findById(String? id) {
    if (id == null) return null;
    for (final user in _users) {
      if (user.id == id) return user;
    }
    return null;
  }

  /// Pengguna yang sesinya tersimpan, atau `null` jika tidak ada/sudah tidak valid.
  UserModel? get sessionUser =>
      findById(_storage.getString(StorageKeys.activeUserId));

  // --------------------------------------------------------------- commands

  UserModel _newUser({
    required String email,
    required String password,
    required String name,
    String age = '',
    String gender = '',
  }) {
    final salt = generateSalt();
    return UserModel(
      id: const Uuid().v4(),
      email: email.trim(),
      name: name,
      age: age,
      gender: gender,
      salt: salt,
      passwordHash: hashPassword(password, salt),
    );
  }

  /// Mengembalikan `null` jika email sudah terdaftar.
  Future<UserModel?> register({
    required String email,
    required String password,
    required String name,
    String age = '',
    String gender = '',
  }) async {
    if (findByEmail(email) != null) return null;

    final user = _newUser(
      email: email,
      password: password,
      name: name,
      age: age,
      gender: gender,
    );
    _users = [..._users, user];
    await _persistUsers();
    return user;
  }

  /// Memeriksa kredensial. [user] terisi hanya jika [result] == success.
  ({LoginResult result, UserModel? user}) verify(String email, String password) {
    final user = findByEmail(email);
    if (user == null) return (result: LoginResult.emailNotFound, user: null);
    if (hashPassword(password, user.salt) != user.passwordHash) {
      return (result: LoginResult.wrongPassword, user: null);
    }
    return (result: LoginResult.success, user: user);
  }

  Future<void> setSession(String? userId) async {
    if (userId == null) {
      if (_storage.containsKey(StorageKeys.activeUserId)) {
        await _storage.remove(StorageKeys.activeUserId);
      }
    } else {
      await _storage.setString(StorageKeys.activeUserId, userId);
    }
  }

  Future<UserModel> updateUser(UserModel updated) async {
    final index = _users.indexWhere((u) => u.id == updated.id);
    if (index == -1) throw StorageException('Akun tidak ditemukan');
    final next = [..._users];
    next[index] = updated;
    _users = next;
    await _persistUsers();
    return updated;
  }

  Future<void> _persistUsers() {
    return _storage.writeList(
      StorageKeys.users,
      _users.map((u) => u.toJson()).toList(),
    );
  }
}
