import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/mission_model.dart';
import '../models/target_model.dart';
import '../repositories/target_repository.dart';
import '../utils/currency_formatter.dart';
import '../utils/error_mapper.dart';
import 'mission_provider.dart';

class TargetProvider extends ChangeNotifier {
  final TargetRepository _repository;

  TargetProvider({TargetRepository? repository})
      : _repository = repository ?? TargetRepository();

  String? _uid;
  MissionProvider? _missionProvider;
  List<TargetItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastSavedAt;

  List<TargetItem> get items => List<TargetItem>.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isRecentlySaved =>
      _lastSavedAt != null &&
      DateTime.now().difference(_lastSavedAt!).inMinutes < 5;
  bool get hasActiveSavingProgress {
    final item = pinnedItem;
    if (item == null) return false;
    return item.savedAmount > 0 && item.savedAmount < item.targetAmount;
  }

  TargetItem? get pinnedItem {
    for (final item in _items) {
      if (item.isPinned) return item;
    }
    return _items.isNotEmpty ? _items.first : null;
  }

  double get totalAllocated =>
      _items.fold(0.0, (sum, item) => sum + item.savedAmount);
  double availableToAllocate(double totalWalletBalance) {
    final remaining = totalWalletBalance - totalAllocated;
    return remaining > 0 ? remaining : 0.0;
  }

  void bindDependencies(String? newUid, MissionProvider missionProvider) {
    _missionProvider = missionProvider;
    updateUser(newUid);
  }

  void updateUser(String? newUid) {
    if (_uid == newUid) return;
    _uid = newUid;
    _items = [];
    _errorMessage = null;
    _lastSavedAt = null;

    if (newUid == null) {
      _isLoading = false;
      Future.microtask(notifyListeners);
      return;
    }

    _isLoading = true;
    Future.microtask(() {
      if (_uid == newUid) {
        loadTargets();
      }
    });
  }

  Future<void> loadTargets({bool silent = false}) async {
    final targetUid = _uid;
    if (targetUid == null) {
      _items = [];
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
      var fetched = await _repository.getTargets(targetUid);
      if (_uid != targetUid) return;
      if (fetched.isNotEmpty && !fetched.any((item) => item.isPinned)) {
        final firstId = fetched.first.id;
        await _repository.togglePinTarget(
          uid: targetUid,
          targetId: firstId,
          shouldPin: true,
        );
        if (_uid != targetUid) return;
        fetched = [
          fetched.first.copyWith(isPinned: true),
          ...fetched.skip(1),
        ];
      }
      _items = fetched;
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

  Future<TargetItem> createTarget({
    required String nama,
    required double targetAmount,
    required File imageFile,
    DateTime? deadline,
  }) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    final bool shouldAutoPin =
        _items.isEmpty || !_items.any((item) => item.isPinned);
    final created = await _repository.createTarget(
      uid: targetUid,
      nama: nama,
      targetAmount: targetAmount,
      imageFile: imageFile,
      isPinned: shouldAutoPin,
      deadline: deadline,
    );
    if (_missionProvider != null) {
      unawaited(
        _missionProvider!.recordTrigger(MissionTrigger.createTarget),
      );
    }
    await loadTargets(silent: true);
    return created;
  }

  Future<void> updateTarget({
    required String targetId,
    required String nama,
    required double targetAmount,
    File? newImageFile,
    DateTime? deadline,
    bool clearDeadline = false,
  }) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    final trimmedName = nama.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Nama target tidak boleh kosong.');
    }
    if (targetAmount <= 0) {
      throw Exception('Nominal target harus lebih dari Rp 0.');
    }

    final index = _items.indexWhere((t) => t.id == targetId);
    if (index == -1) {
      throw Exception('Target menabung tidak ditemukan');
    }
    final existing = _items[index];
    if (targetAmount + 0.0001 < existing.savedAmount) {
      throw Exception(
        'Nominal target tidak boleh di bawah dana terkumpul (${Formatters.rupiah(existing.savedAmount)}). Tarik sebagian dana terlebih dahulu.',
      );
    }

    await _repository.updateTarget(
      uid: targetUid,
      targetId: targetId,
      nama: trimmedName,
      targetAmount: targetAmount,
      newImageFile: newImageFile,
      deadline: deadline,
      clearDeadline: clearDeadline,
    );
    await loadTargets(silent: true);
  }

  Future<void> allocateTargetFunds({
    required String targetId,
    required double amountDelta,
    required double totalWalletBalance,
  }) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    if (amountDelta == 0) return;

    final index = _items.indexWhere((t) => t.id == targetId);
    if (index == -1) {
      throw Exception('Target menabung tidak ditemukan');
    }
    final target = _items[index];

    if (amountDelta > 0) {
      final available = availableToAllocate(totalWalletBalance);
      if (amountDelta > available + 0.0001) {
        throw Exception(
          'Nominal melebihi saldo bebas yang tersedia untuk dialokasikan.',
        );
      }
      final remainingNeeded = (target.targetAmount - target.savedAmount)
          .clamp(0.0, double.infinity);
      if (amountDelta > remainingNeeded + 0.0001) {
        throw Exception('Nominal melebihi sisa target yang dibutuhkan.');
      }
    } else {
      if (amountDelta.abs() > target.savedAmount + 0.0001) {
        throw Exception(
          'Nominal penarikan melebihi dana yang tersimpan pada target ini.',
        );
      }
    }

    final double newSavedAmount =
        (target.savedAmount + amountDelta).clamp(0.0, target.targetAmount);

    await _repository.updateSavedAmount(
      uid: targetUid,
      targetId: targetId,
      savedAmount: newSavedAmount,
    );
    if (amountDelta > 0) {
      _lastSavedAt = DateTime.now();
      if (_missionProvider != null) {
        unawaited(
          _missionProvider!.recordTrigger(MissionTrigger.saveTarget),
        );
      }
    }
    await loadTargets(silent: true);
  }

  Future<void> togglePin(TargetItem item) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    if (item.isPinned) return;
    await _repository.togglePinTarget(
      uid: targetUid,
      targetId: item.id,
      shouldPin: true,
    );
    await loadTargets(silent: true);
  }

  Future<void> deleteTarget(String targetId) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    await _repository.deleteTarget(targetUid, targetId);
    await loadTargets(silent: true);
  }
}
