import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Gagal menulis ke penyimpanan lokal.
class StorageException implements Exception {
  final String message;
  StorageException(this.message);

  @override
  String toString() => message;
}

/// Pembungkus tipis SharedPreferences: membaca/menulis string dan daftar JSON.
///
/// Daftar disimpan sebagai `{"v": <schemaVersion>, "items": [...]}` agar format
/// bisa dimigrasikan di masa depan. Data yang rusak tidak membuat aplikasi
/// crash: pembacaan mengembalikan daftar kosong dan mencatat log.
class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> create() async {
    return StorageService(await SharedPreferences.getInstance());
  }

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) async {
    final ok = await _prefs.setString(key, value);
    if (!ok) throw StorageException('Gagal menyimpan data ($key)');
  }

  Future<void> remove(String key) async {
    final ok = await _prefs.remove(key);
    if (!ok) throw StorageException('Gagal menghapus data ($key)');
  }

  bool containsKey(String key) => _prefs.containsKey(key);

  /// Membaca daftar objek JSON. Mengembalikan `[]` jika kosong atau rusak.
  List<Map<String, dynamic>> readList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      final List<dynamic> items;
      if (decoded is Map<String, dynamic>) {
        items = (decoded['items'] as List<dynamic>?) ?? [];
      } else if (decoded is List<dynamic>) {
        items = decoded; // format lama tanpa envelope
      } else {
        return [];
      }
      return items
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: true);
    } catch (e) {
      debugPrint('StorageService: data "$key" rusak, diabaikan ($e)');
      return [];
    }
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> items) {
    final encoded = jsonEncode({
      'v': AppConfig.storageSchemaVersion,
      'items': items,
    });
    return setString(key, encoded);
  }

  /// Membaca satu objek JSON. Mengembalikan `null` jika kosong atau rusak.
  Map<String, dynamic>? readMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (e) {
      debugPrint('StorageService: data "$key" rusak, diabaikan ($e)');
      return null;
    }
  }

  Future<void> writeMap(String key, Map<String, dynamic> value) {
    return setString(key, jsonEncode(value));
  }
}
