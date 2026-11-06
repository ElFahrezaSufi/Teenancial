import 'package:flutter/foundation.dart';
import '../data/category_catalog.dart';
import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';
import 'dompet_provider.dart';

class TransactionProvider extends ChangeNotifier {
  final TransactionRepository _repository;

  TransactionProvider({TransactionRepository? repository})
      : _repository = repository ?? TransactionRepository();

  String? _uid;
  DompetProvider? _dompetProvider;
  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<TransactionModel> get transactions =>
      List<TransactionModel>.unmodifiable(_transactions);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<TransactionModel> get debts =>
      _transactions.where((t) => t.type == TransactionType.debt).toList();

  List<TransactionModel> get receivables =>
      _transactions.where((t) => t.type == TransactionType.receivable).toList();

  List<CategoryModel> get categories => CategoryCatalog.categories;
  CategoryModel getCategoryById(String id) => CategoryCatalog.getById(id);
  List<CategoryModel> getCategoriesByType(TransactionType type) =>
      CategoryCatalog.getByType(type);

  void bindDependencies(String? newUid, DompetProvider dompetProvider) {
    _dompetProvider = dompetProvider;
    updateUser(newUid);
  }

  void updateUser(String? newUid) {
    if (_uid == newUid) return;
    _uid = newUid;
    _transactions = [];
    _errorMessage = null;

    if (newUid == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    loadTransactions();
  }

  Future<void> loadTransactions({bool silent = false}) async {
    final targetUid = _uid;
    if (targetUid == null) {
      _transactions = [];
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
      final fetched = await _repository.getTransactions(targetUid);
      if (_uid != targetUid) return;
      _transactions = fetched;
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

  Future<void> _refreshAfterMutation() async {
    await Future.wait([
      loadTransactions(silent: true),
      if (_dompetProvider != null) _dompetProvider!.loadDompets(silent: true),
    ]);
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    await _repository.addTransaction(targetUid, transaction);
    await _refreshAfterMutation();
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    await _repository.updateTransaction(targetUid, transaction);
    await _refreshAfterMutation();
  }

  Future<void> deleteTransaction(String transactionId) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    await _repository.deleteTransaction(targetUid, transactionId);
    await _refreshAfterMutation();
  }

  Future<void> markAsPaid(String transactionId, String dompetId) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    await _repository.markAsPaid(targetUid, transactionId, dompetId);
    await _refreshAfterMutation();
  }
}
