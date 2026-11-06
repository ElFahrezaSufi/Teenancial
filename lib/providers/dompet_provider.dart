import 'package:flutter/foundation.dart';
import '../models/dompet_model.dart';
import '../repositories/dompet_repository.dart';
import '../utils/error_mapper.dart';

class DompetProvider extends ChangeNotifier {
  final DompetRepository _repository;

  DompetProvider({DompetRepository? repository})
      : _repository = repository ?? DompetRepository();

  String? _uid;
  List<DompetItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<DompetItem> get items => List<DompetItem>.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double get totalSaldo =>
      _items.fold(0.0, (sum, item) => sum + item.jumlah);

  DompetItem? getById(String? id) {
    if (id == null) return null;
    for (final item in _items) {
      if (item.id == id) return item;
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
      Future.microtask(notifyListeners);
      return;
    }

    _isLoading = true;
    Future.microtask(() {
      if (_uid == newUid) {
        loadDompets();
      }
    });
  }

  Future<void> loadDompets({bool silent = false}) async {
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
      final fetched = await _repository.getDompets(targetUid);
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

  Future<void> addDompet(DompetItem item) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    await _repository.addDompet(targetUid, item);
    await loadDompets(silent: true);
  }

  Future<void> updateDompet(DompetItem item) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    await _repository.updateDompet(targetUid, item);
    await loadDompets(silent: true);
  }

  Future<void> deleteDompet(String dompetId) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    await _repository.deleteDompet(targetUid, dompetId);
    await loadDompets(silent: true);
  }
}
