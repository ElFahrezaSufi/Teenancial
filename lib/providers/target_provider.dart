import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/target_model.dart';
import '../repositories/target_repository.dart';

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

  void updateUser(String? newUid) {
    if (_uid == newUid) return;
    _uid = newUid;
    _items = [];
    _errorMessage = null;

    if (newUid == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    loadTargets();
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
      _errorMessage = e.toString().replaceAll('Exception: ', '');
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
