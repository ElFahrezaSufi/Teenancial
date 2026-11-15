import 'package:flutter/foundation.dart';
import '../data/category_catalog.dart';
import '../models/transaction_model.dart';
import '../repositories/category_repository.dart';
import '../utils/error_mapper.dart';

class CategoryProvider extends ChangeNotifier {
  final CategoryRepository _repository;

  CategoryProvider({CategoryRepository? repository})
      : _repository = repository ?? CategoryRepository();

  String? _uid;
  List<CategoryModel> _customCategories = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CategoryModel> get customCategories =>
      List<CategoryModel>.unmodifiable(_customCategories);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Mengembalikan daftar kategori (bawaan + kustom) untuk `type` tertentu,
  /// dengan kategori bawaan "Lainnya" selalu di urutan paling bawah.
  List<CategoryModel> categoriesFor(TransactionType type) =>
      CategoryCatalog.mergeWithCustom(type, _customCategories);

  /// Mengembalikan hanya kategori kustom buatan pengguna untuk `type` tertentu.
  List<CategoryModel> customCategoriesFor(TransactionType type) =>
      _customCategories.where((c) => c.type == type).toList(growable: false);

  /// Mencari kategori berdasarkan `id` dari daftar kustom maupun katalog bawaan.
  CategoryModel resolve(String id, {TransactionType? fallbackType}) =>
      CategoryCatalog.resolveWithCustom(
        id,
        _customCategories,
        fallbackType: fallbackType,
      );

  void updateUser(String? newUid) {
    if (_uid == newUid) return;
    _uid = newUid;
    _customCategories = [];
    _errorMessage = null;

    if (newUid == null) {
      _isLoading = false;
      Future.microtask(notifyListeners);
      return;
    }

    _isLoading = true;
    Future.microtask(() {
      if (_uid == newUid) {
        loadCategories();
      }
    });
  }

  Future<void> loadCategories({bool silent = false}) async {
    final targetUid = _uid;
    if (targetUid == null) {
      _customCategories = [];
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
      final fetched = await _repository.getCategories(targetUid);
      if (_uid != targetUid) return;
      _customCategories = fetched;
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

  Future<CategoryModel> addCategory({
    required String name,
    required TransactionType type,
    required String iconKey,
    required int colorValue,
  }) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    final created = await _repository.addCategory(
      uid: targetUid,
      name: name,
      type: type,
      iconKey: iconKey,
      colorValue: colorValue,
    );
    await loadCategories(silent: true);
    return created;
  }

  Future<CategoryModel> updateCategory({
    required String categoryId,
    required String name,
    required TransactionType type,
    required String iconKey,
    required int colorValue,
  }) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    final updated = await _repository.updateCategory(
      uid: targetUid,
      categoryId: categoryId,
      name: name,
      type: type,
      iconKey: iconKey,
      colorValue: colorValue,
    );
    await loadCategories(silent: true);
    return updated;
  }

  Future<int> countUsages(String categoryId) async {
    final targetUid = _uid;
    if (targetUid == null) return 0;
    return _repository.countUsages(targetUid, categoryId);
  }

  Future<int> deleteCategory({
    required String categoryId,
    required TransactionType type,
  }) async {
    final targetUid = _uid;
    if (targetUid == null) {
      throw Exception('Sesi pengguna tidak ditemukan');
    }
    final reassigned = await _repository.deleteCategory(
      uid: targetUid,
      categoryId: categoryId,
      type: type,
    );
    await loadCategories(silent: true);
    return reassigned;
  }
}
