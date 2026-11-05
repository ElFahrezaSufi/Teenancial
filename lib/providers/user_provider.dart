import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../utils/error_mapper.dart';

class UserProvider extends ChangeNotifier {
  final UserRepository _repository;

  UserProvider({UserRepository? repository})
      : _repository = repository ?? UserRepository();

  String? _uid;
  UserModel? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get displayName {
    final name = _profile?.name.trim() ?? '';
    return name.isNotEmpty ? name : 'Pengguna';
  }

  String? get profileImageUrl {
    final url = _profile?.profileImageUrl?.trim() ?? '';
    return url.isNotEmpty ? url : null;
  }

  void updateUser(String? newUid) {
    if (_uid == newUid) return;
    _uid = newUid;
    _profile = null;
    _errorMessage = null;

    if (newUid == null) {
      _isLoading = false;
      Future.microtask(notifyListeners);
      return;
    }

    _isLoading = true;
    Future.microtask(() {
      if (_uid == newUid) {
        loadProfile();
      }
    });
  }

  Future<void> loadProfile({bool silent = false}) async {
    final targetUid = _uid;
    if (targetUid == null) {
      _profile = null;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final fetched = await _repository.getUserProfile(targetUid);
      if (_uid != targetUid) return;
      _profile = fetched;
      _errorMessage = null;
    } catch (e) {
      if (_uid != targetUid) return;
      _errorMessage = ErrorMapper.message(e);
    } finally {
      if (_uid == targetUid) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> saveProfile({
    required String name,
    required String age,
    DateTime? birthDate,
    required String gender,
    File? newImageFile,
    bool removeImage = false,
  }) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _repository.updateUserProfile(
        uid: targetUid,
        name: name,
        age: age,
        birthDate: birthDate,
        gender: gender,
        newImageFile: newImageFile,
        currentImageUrl: _profile?.profileImageUrl,
        removeImage: removeImage,
      );
      if (_uid != targetUid) return;
      _profile = updated;
    } catch (e) {
      if (_uid == targetUid) {
        _errorMessage = ErrorMapper.message(e);
      }
      rethrow;
    } finally {
      if (_uid == targetUid) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}
