import 'package:flutter/widgets.dart';
import '../models/recurring_model.dart';
import '../repositories/recurring_repository.dart';
import '../services/notification_service.dart';
import '../utils/error_mapper.dart';
import 'dompet_provider.dart';
import 'transaction_provider.dart';

class RecurringProvider extends ChangeNotifier with WidgetsBindingObserver {
  final RecurringRepository _repository;

  RecurringProvider({RecurringRepository? repository})
      : _repository = repository ?? RecurringRepository() {
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
  }

  String? _uid;
  DompetProvider? _dompetProvider;
  TransactionProvider? _transactionProvider;

  List<RecurringModel> _items = [];
  bool _isLoading = false;
  bool _isProcessingCatchUp = false;
  String? _errorMessage;
  RecurringCatchUpResult? _lastCatchUpResult;

  List<RecurringModel> get items => List<RecurringModel>.unmodifiable(_items);
  List<RecurringModel> get activeItems =>
      _items.where((i) => i.isActive).toList(growable: false);
  List<RecurringModel> get inactiveItems =>
      _items.where((i) => !i.isActive).toList(growable: false);

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  RecurringCatchUpResult? get lastCatchUpResult => _lastCatchUpResult;

  void clearLastCatchUpResult() {
    _lastCatchUpResult = null;
  }

  void bindDependencies(
    String? newUid,
    DompetProvider dompetProvider,
    TransactionProvider transactionProvider,
  ) {
    _dompetProvider = dompetProvider;
    _transactionProvider = transactionProvider;

    if (_uid == newUid) return;
    _uid = newUid;
    _items = [];
    _errorMessage = null;
    _lastCatchUpResult = null;

    if (newUid == null) {
      _isLoading = false;
      Future.microtask(notifyListeners);
      return;
    }

    _isLoading = true;
    Future.microtask(() {
      if (_uid == newUid) {
        runCatchUpAndLoad();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _uid != null &&
        !_isProcessingCatchUp) {
      runCatchUpAndLoad(silent: true);
    }
  }

  @override
  void dispose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    super.dispose();
  }

  Future<void> runCatchUpAndLoad({bool silent = false}) async {
    final targetUid = _uid;
    if (targetUid == null) {
      _items = [];
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    if (_isProcessingCatchUp) return;
    _isProcessingCatchUp = true;

    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final catchUpResult = await _repository.processDue(targetUid);
      if (_uid != targetUid) return;

      final fetched = await _repository.getRecurringTemplates(targetUid);
      if (_uid != targetUid) return;

      _items = fetched;
      _errorMessage = null;

      await NotificationService.instance.syncRecurringReminders(_items);

      if (catchUpResult.hasChanges) {
        _lastCatchUpResult = catchUpResult;
        await Future.wait([
          if (_dompetProvider != null)
            _dompetProvider!.loadDompets(silent: true),
          if (_transactionProvider != null)
            _transactionProvider!.loadTransactions(silent: true),
        ]);
        await NotificationService.instance.showRecurringCatchUpNotification(
          catchUpResult,
        );
      }
    } catch (e) {
      if (_uid != targetUid) return;
      _errorMessage = ErrorMapper.message(e);
    } finally {
      _isProcessingCatchUp = false;
      if (_uid == targetUid) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadRecurring({bool silent = false}) =>
      runCatchUpAndLoad(silent: silent);

  Future<RecurringModel> addRecurring(RecurringModel item) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    final created = await _repository.addRecurring(targetUid, item);
    await runCatchUpAndLoad(silent: true);
    return created;
  }

  Future<RecurringModel> updateRecurring(RecurringModel item) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    final updated = await _repository.updateRecurring(targetUid, item);
    await runCatchUpAndLoad(silent: true);
    return updated;
  }

  Future<void> toggleActive(String id, bool isActive) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    await _repository.toggleActive(targetUid, id, isActive);
    await runCatchUpAndLoad(silent: true);
  }

  Future<void> deleteRecurring(String id) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    await _repository.deleteRecurring(targetUid, id);
    await NotificationService.instance.cancelRecurringReminder(id);
    await runCatchUpAndLoad(silent: true);
  }
}
