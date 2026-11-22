import 'dart:io';
import 'package:flutter/foundation.dart';
import '../data/feen_catalog.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../services/connectivity_service.dart';
import '../services/local_storage_service.dart';
import '../utils/error_mapper.dart';
import '../utils/xp_helper.dart';

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

  int get xp => _profile?.xp ?? 0;
  int get level => XpHelper.levelFromXp(xp);
  int get xpIntoLevel => XpHelper.xpIntoLevel(xp);
  int get xpNeededForNext => XpHelper.xpNeededForNext(level);
  Map<String, String> get feenEquipped => _profile?.feenEquipped ?? const {};
  Future<XpGainResult?> addXp(int amount) async {
    final uid = _uid;
    final current = _profile;
    if (uid == null || current == null || amount <= 0) return null;

    final oldLevel = XpHelper.levelFromXp(current.xp);
    final newLevel = XpHelper.levelFromXp(current.xp + amount);

    _profile = current.copyWith(xp: current.xp + amount);
    notifyListeners();

    try {
      await _repository.incrementXp(uid, amount);
      return XpGainResult(oldLevel: oldLevel, newLevel: newLevel);
    } catch (e) {
      final latest = _profile;
      if (_uid == uid && latest != null) {
        final rolledBack = latest.xp - amount;
        _profile = latest.copyWith(xp: rolledBack < 0 ? 0 : rolledBack);
        _errorMessage = ErrorMapper.message(e);
        notifyListeners();
      }
      return null;
    }
  }

  Future<void> equipFeen(FeenSlot slot, String? accessoryId) async {
    final uid = _uid;
    final current = _profile;
    if (uid == null || current == null) return;

    if (accessoryId != null) {
      final accessory = feenById(accessoryId);
      if (accessory == null || accessory.slot != slot) return;
      if (level < accessory.unlockLevel) return;
    }

    final next = Map<String, String>.from(current.feenEquipped);
    if (accessoryId == null) {
      next.remove(slot.name);
    } else {
      next[slot.name] = accessoryId;
    }
    await _saveEquipped(uid, current, next);
  }

  Future<void> unequipAllFeen() async {
    final uid = _uid;
    final current = _profile;
    if (uid == null || current == null || current.feenEquipped.isEmpty) return;
    await _saveEquipped(uid, current, const {});
  }

  Future<void> _saveEquipped(
    String uid,
    UserModel previous,
    Map<String, String> next,
  ) async {
    _profile = previous.copyWith(feenEquipped: next);
    notifyListeners();
    try {
      await _repository.saveFeenEquipped(uid, next);
    } catch (e) {
      if (_uid == uid && _profile != null) {
        _profile = _profile!.copyWith(feenEquipped: previous.feenEquipped);
        _errorMessage = ErrorMapper.message(e);
        notifyListeners();
      }
      rethrow;
    }
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

  /// Menandai bahwa onboarding saldo awal untuk pengguna aktif sudah selesai
  /// (baik melalui "Simpan Saldo Awal" maupun "Mulai dari Rp 0 / Lewati").
  /// Bila [allowOfflineLocalFallback] bernilai `true` dan perangkat offline,
  /// status tetap disimpan lokal per-UID dan ditandai untuk disinkronkan ulang
  /// saat perangkat kembali online.
  Future<void> markInitialBalanceOnboardingDone({
    bool allowOfflineLocalFallback = false,
  }) async {
    final targetUid = _uid;
    if (targetUid == null) return;

    await LocalStorageService.instance
        .setInitialBalanceOnboardingDoneLocal(targetUid, true);
    if (_profile != null && !_profile!.initialBalanceOnboardingDone) {
      _profile = _profile!.copyWith(initialBalanceOnboardingDone: true);
      notifyListeners();
    }

    try {
      await _repository.markInitialBalanceOnboardingDone(targetUid);
      await LocalStorageService.instance
          .setInitialBalanceOnboardingPendingSync(targetUid, false);
    } on OfflineException {
      if (allowOfflineLocalFallback) {
        await LocalStorageService.instance
            .setInitialBalanceOnboardingPendingSync(targetUid, true);
        return;
      }
      rethrow;
    }
  }

  /// Menyinkronkan flag selesai onboarding yang tertunda karena pengguna
  /// memilih "Lewati" saat perangkat sedang offline.
  Future<void> syncPendingOnboardingFlagIfNeeded() async {
    final targetUid = _uid;
    if (targetUid == null) return;
    if (ConnectivityService.instance.isOffline) return;
    if (!LocalStorageService.instance
        .isInitialBalanceOnboardingPendingSync(targetUid)) {
      return;
    }
    try {
      await _repository.markInitialBalanceOnboardingDone(targetUid);
      await LocalStorageService.instance
          .setInitialBalanceOnboardingPendingSync(targetUid, false);
    } catch (_) {}
  }
}
