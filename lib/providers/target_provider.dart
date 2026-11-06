import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/target_model.dart';
import '../repositories/target_repository.dart';
import '../utils/error_mapper.dart';

class TargetProvider extends ChangeNotifier {
  final TargetRepository _repository;

  TargetProvider({TargetRepository? repository})
      : _repository = repository ?? TargetRepository();

  String? _uid;
  List<TargetItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<TargetItem> get items => List<TargetItem>.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  TargetItem? get pinnedItem {
    for (final item in _items) {
      if (item.isPinned) return item;
    }
    return null;
  }

  /// Total dana yang sudah dialokasikan ke seluruh target menabung.
  double get totalAllocated =>
      _items.fold(0.0, (sum, item) => sum + item.savedAmount);

  /// Sisa saldo dompet yang belum dialokasikan ke target mana pun.
  double availableToAllocate(double totalWalletBalance) {
    final remaining = totalWalletBalance - totalAllocated;
    return remaining > 0 ? remaining : 0.0;
  }

  void updateUser(String? newUid) {
    if (_uid == newUid) return;
    _uid = newUid;
    _items = [];
    _errorMessage = null;

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
      final fetched = await _repository.getTargets(targetUid);
      if (_uid != targetUid) return;
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
  }) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    final created = await _repository.createTarget(
      uid: targetUid,
      nama: nama,
      targetAmount: targetAmount,
      imageFile: imageFile,
    );
    await loadTargets(silent: true);
    return created;
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
      final remainingNeeded =
          (target.targetAmount - target.savedAmount).clamp(0.0, double.infinity);
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
    await loadTargets(silent: true);
  }

  Future<void> togglePin(TargetItem item) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    final bool shouldPin = !item.isPinned;
    await _repository.togglePinTarget(
      uid: targetUid,
      targetId: item.id,
      shouldPin: shouldPin,
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
