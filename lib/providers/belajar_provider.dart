import 'package:flutter/foundation.dart';
import '../models/belajar_model.dart';
import '../repositories/belajar_repository.dart';

class BelajarProvider extends ChangeNotifier {
  final BelajarRepository _repository;

  BelajarProvider({BelajarRepository? repository})
      : _repository = repository ?? BelajarRepository();

  String? _uid;
  List<LevelData> _baseLevels = const [];
  List<LevelData> _levels = const [];
  Set<String> _completedModules = {};
  Set<String> _completedQuizzes = {};
  Set<String> _expandedModules = {};
  bool _isLoading = false;
  String? _errorMessage;

  List<LevelData> get levels => List<LevelData>.unmodifiable(_levels);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ─── Current module untuk home screen ────────────────────────────────────────

  ({ModuleData module, LevelData level, double levelProgress})?
      get currentModule {
    for (final level in _levels) {
      final completed =
          level.modules.where((m) => m.status == ModuleStatus.completed).length;
      final progress =
          level.modules.isEmpty ? 0.0 : completed / level.modules.length;

      for (final mod in level.modules) {
        if (mod.status == ModuleStatus.available) {
          return (module: mod, level: level, levelProgress: progress);
        }
        if (mod.status == ModuleStatus.completed &&
            mod.quiz.status == ModuleStatus.available) {
          return (module: mod, level: level, levelProgress: progress);
        }
      }
    }
    return null;
  }

  // ─── updateUser ──────────────────────────────────────────────────────────────

  void updateUser(String? newUid) {
    if (_uid == newUid) return;
    _uid = newUid;
    _completedModules = {};
    _completedQuizzes = {};
    _expandedModules = {};
    _errorMessage = null;

    if (newUid == null) {
      _baseLevels = const [];
      _levels = const [];
      _isLoading = false;
      Future.microtask(notifyListeners);
      return;
    }

    _recomputeLocks();
    _isLoading = true;
    Future.microtask(() {
      if (_uid == newUid) loadAll();
    });
  }

  // ─── loadAll: fetch levels + modules dari Firestore ───────────────────────────

  Future<void> loadAll({bool silent = false}) async {
    final targetUid = _uid;
    if (targetUid == null) return;

    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        _repository.getLevels(),
        _repository.getAllModules(),
      ]);

      if (_uid != targetUid) return;

      final levels = results[0] as List<LevelData>;
      final modules = results[1] as List<ModuleData>;

      // Kelompokkan modules ke level berdasarkan levelId
      final modulesByLevel = <String, List<ModuleData>>{};
      for (final mod in modules) {
        modulesByLevel.putIfAbsent(mod.levelId, () => []).add(mod);
      }

      _baseLevels = levels
          .map((l) => l.copyWith(
                modules: List<ModuleData>.unmodifiable(
                  (modulesByLevel[l.id] ?? [])
                    ..sort((a, b) => a.order.compareTo(b.order)),
                ),
              ))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));

      await _fetchProgress(targetUid);
      if (_uid != targetUid) return;

      _errorMessage = null;
    } catch (e) {
      if (_uid != targetUid) return;
      debugPrint('Gagal memuat Ruang Belajar: $e');
      _errorMessage = 'Gagal memuat materi. Periksa koneksi internetmu.';
    } finally {
      if (_uid == targetUid) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // ─── loadProgress: hanya refresh progres user ─────────────────────────────────

  Future<void> loadProgress({bool silent = false}) async {
    final targetUid = _uid;
    if (targetUid == null) return;

    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      await _fetchProgress(targetUid);
    } catch (e) {
      debugPrint('Gagal memuat progres: $e');
    } finally {
      if (_uid == targetUid) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _fetchProgress(String targetUid) async {
    final progress = await _repository.getProgress(targetUid);
    if (_uid != targetUid) return;
    _completedModules = Set<String>.from(progress.completedModules);
    _completedQuizzes = Set<String>.from(progress.completedQuizzes);
    _recomputeLocks();
  }

  // ─── Aksi user ────────────────────────────────────────────────────────────────

  void toggleExpand(int levelIndex, int moduleIndex) {
    final mod = _moduleAt(levelIndex, moduleIndex);
    if (mod == null || mod.status == ModuleStatus.locked) return;

    if (_expandedModules.contains(mod.id)) {
      _expandedModules.remove(mod.id);
    } else {
      _expandedModules.add(mod.id);
    }
    _recomputeLocks();
    notifyListeners();
  }

  Future<void> completeModule(int levelIndex, int moduleIndex) async {
    final mod = _moduleAt(levelIndex, moduleIndex);
    if (mod == null || mod.status != ModuleStatus.available) return;

    _completedModules.add(mod.id);
    _recomputeLocks();
    notifyListeners();
    await _persistProgress();
  }

  Future<bool> completeQuiz(
    int levelIndex,
    int moduleIndex, {
    int? scorePercent,
  }) async {
    final mod = _moduleAt(levelIndex, moduleIndex);
    if (mod == null || mod.quiz.status == ModuleStatus.locked) return false;
    if (scorePercent != null && scorePercent < mod.quiz.passingScore) {
      return false;
    }

    _completedModules.add(mod.id);
    _completedQuizzes.add(mod.id);
    _recomputeLocks();
    notifyListeners();
    await _persistProgress();
    return true;
  }

  // ─── Helper ──────────────────────────────────────────────────────────────────

  ModuleData? _moduleAt(int levelIndex, int moduleIndex) {
    if (levelIndex < 0 || levelIndex >= _levels.length) return null;
    final modules = _levels[levelIndex].modules;
    if (moduleIndex < 0 || moduleIndex >= modules.length) return null;
    return modules[moduleIndex];
  }

  Future<void> _persistProgress() async {
    final targetUid = _uid;
    if (targetUid == null) return;
    try {
      await _repository.saveProgress(
        targetUid,
        BelajarProgressModel(
          completedModules: _completedModules,
          completedQuizzes: _completedQuizzes,
        ),
      );
    } catch (e) {
      debugPrint('Gagal menyimpan progres: $e');
    }
  }

  void _recomputeLocks() {
    final updatedLevels = <LevelData>[];

    for (int li = 0; li < _baseLevels.length; li++) {
      final level = _baseLevels[li];
      final updatedModules = <ModuleData>[];

      for (int mi = 0; mi < level.modules.length; mi++) {
        final mod = level.modules[mi];
        final isModDone = _completedModules.contains(mod.id);
        final isQuizDone = _completedQuizzes.contains(mod.id);

        late final ModuleStatus moduleStatus;
        late final ModuleStatus quizStatus;

        if (isModDone) {
          moduleStatus = ModuleStatus.completed;
          quizStatus =
              isQuizDone ? ModuleStatus.completed : ModuleStatus.available;
        } else {
          bool moduleUnlocked;
          if (li == 0 && mi == 0) {
            moduleUnlocked = true;
          } else if (mi > 0) {
            final prev = level.modules[mi - 1];
            moduleUnlocked = _completedModules.contains(prev.id) &&
                _completedQuizzes.contains(prev.id);
          } else {
            final prevLevel = _baseLevels[li - 1];
            moduleUnlocked = prevLevel.modules.every(
              (m) =>
                  _completedModules.contains(m.id) &&
                  _completedQuizzes.contains(m.id),
            );
          }
          moduleStatus =
              moduleUnlocked ? ModuleStatus.available : ModuleStatus.locked;
          quizStatus = ModuleStatus.locked;
        }

        final isExpanded = moduleStatus != ModuleStatus.locked &&
            _expandedModules.contains(mod.id);

        updatedModules.add(mod.copyWith(
          status: moduleStatus,
          isExpanded: isExpanded,
          quiz: mod.quiz.copyWith(status: quizStatus),
        ));
      }

      updatedLevels.add(level.copyWith(
        modules: List<ModuleData>.unmodifiable(updatedModules),
      ));
    }

    _levels = List<LevelData>.unmodifiable(updatedLevels);
  }
}
