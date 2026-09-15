import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuth {
  static const String _storageKey = 'mock_users';
  static const String _sessionKey = 'active_user_email';
  static List<Map<String, String>> _users = [];
  static bool isLoggedIn = false;
  static String activeEmail = '';
  static String activeUserName = 'Pengguna';
  static String activeAge = '';
  static String activeGender = '';
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final String? usersJson = prefs.getString(_storageKey);
    if (usersJson != null) {
      final List<dynamic> decoded = jsonDecode(usersJson);
      _users = decoded.map((e) => Map<String, String>.from(e)).toList();
    }
    final String? savedActiveEmail = prefs.getString(_sessionKey);
    if (savedActiveEmail != null && savedActiveEmail.isNotEmpty) {
      _setActiveUser(savedActiveEmail);
    }
  }

  static void _setActiveUser(String email) {
    final user =
        _users.firstWhere((u) => u['email'] == email, orElse: () => {});
    if (user.isNotEmpty) {
      activeEmail = user['email'] ?? '';
      activeUserName = user['name'] ?? 'Pengguna';
      activeAge = user['age'] ?? '';
      activeGender = user['gender'] ?? '';
      isLoggedIn = true;
    }
  }

  static Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_users);
    await prefs.setString(_storageKey, encoded);
  }

  static Future<bool> register({
    required String email,
    required String password,
    required String name,
    String age = '',
    String gender = '',
  }) async {
    final exists = _users.any((user) => user['email'] == email);
    if (exists) return false;

    _users.add({
      'email': email,
      'password': password,
      'name': name,
      'age': age,
      'gender': gender,
    });

    await _saveData();
    return true;
  }

  static Future<String> login(String email, String password) async {
    final userIndex = _users.indexWhere((user) => user['email'] == email);

    if (userIndex == -1) return 'email_not_found';
    if (_users[userIndex]['password'] != password) return 'wrong_password';

    _setActiveUser(email);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, email);

    return 'success';
  }

  static Future<void> logout() async {
    activeEmail = '';
    activeUserName = 'Pengguna';
    activeAge = '';
    activeGender = '';
    isLoggedIn = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  static Future<void> updateProfile({
    required String fullName,
    required String age,
    required String gender,
  }) async {
    final userIndex = _users.indexWhere((user) => user['email'] == activeEmail);
    if (userIndex != -1) {
      _users[userIndex]['name'] = fullName;
      _users[userIndex]['age'] = age;
      _users[userIndex]['gender'] = gender;

      await _saveData();
      _setActiveUser(activeEmail);
    }
  }
}
