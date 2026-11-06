import 'package:flutter/foundation.dart';
import '../data/belajar_catalog.dart';
import '../models/belajar_model.dart';
import '../repositories/belajar_repository.dart';

class BelajarProvider extends ChangeNotifier {
  final BelajarRepository _repository;

  BelajarProvider({BelajarRepository? repository})
      : _repository = repository ?? BelajarRepository() {
    _recomputeLocks();
  }

  String? _uid;
  List<LevelData> _levels = BelajarCatalog.buildLevels();
  Set<String> _completedModules = {};
  Set<String> _completedQuizzes = {};
  Set<String> _expandedModules = {};
  bool _isLoading = false;

  List<LevelData> get levels => List<LevelData>.unmodifiable(_levels);
  bool get isLoading => _isLoading;

  ({ModuleData module, LevelData level, double levelProgress})?
      get currentModule {
    for (final level in _levels) {
      final completed = level.modules
          .where((m) => m.status == ModuleStatus.completed)
          .length;
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

  void updateUser(String? newUid) {
    if (_uid == newUid) return;
    _uid = newUid;
    _completedModules = {};
    _completedQuizzes = {};
    _expandedModules = {};
    _recomputeLocks();

    if (newUid == null) {
      _isLoading = false;
      Future.microtask(notifyListeners);
      return;
    }

    _isLoading = true;
    Future.microtask(() {
      if (_uid == newUid) {
        loadProgress();
      }
    });
  }

  Future<void> loadProgress({bool silent = false}) async {
    final targetUid = _uid;
    if (targetUid == null) return;

    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final progress = await _repository.getProgress(targetUid);
      if (_uid != targetUid) return;
      _completedModules = Set<String>.from(progress.completedModules);
      _completedQuizzes = Set<String>.from(progress.completedQuizzes);
      _recomputeLocks();
    } catch (e) {
      debugPrint('Gagal memuat progres Ruang Belajar: $e');
    } finally {
      if (_uid == targetUid) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _recomputeLocks() {
    final baseLevels = BelajarCatalog.buildLevels();
    final updatedLevels = <LevelData>[];

    for (int li = 0; li < baseLevels.length; li++) {
      final level = baseLevels[li];
      final updatedModules = <ModuleData>[];

      for (int mi = 0; mi < level.modules.length; mi++) {
        final mod = level.modules[mi];
        final key = BelajarProgressModel.keyOf(li, mi);
        final isModDone = _completedModules.contains(key);
        final isQuizDone = _completedQuizzes.contains(key);

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
            final prevKey = BelajarProgressModel.keyOf(li, mi - 1);
            moduleUnlocked = _completedModules.contains(prevKey) &&
                _completedQuizzes.contains(prevKey);
          } else {
            final prevLevel = baseLevels[li - 1];
            moduleUnlocked = true;
            for (int pmi = 0; pmi < prevLevel.modules.length; pmi++) {
              final prevKey = BelajarProgressModel.keyOf(li - 1, pmi);
              if (!_completedModules.contains(prevKey) ||
                  !_completedQuizzes.contains(prevKey)) {
                moduleUnlocked = false;
                break;
              }
            }
          }

          moduleStatus =
              moduleUnlocked ? ModuleStatus.available : ModuleStatus.locked;
          quizStatus = ModuleStatus.locked;
        }

        final isExpanded = moduleStatus != ModuleStatus.locked &&
            _expandedModules.contains(key);

        updatedModules.add(
          mod.copyWith(
            status: moduleStatus,
            isExpanded: isExpanded,
            quiz: mod.quiz.copyWith(status: quizStatus),
          ),
        );
      }

      updatedLevels.add(
        level.copyWith(
          modules: List<ModuleData>.unmodifiable(updatedModules),
        ),
      );
    }

    _levels = List<LevelData>.unmodifiable(updatedLevels);
  }

  void toggleExpand(int levelIndex, int moduleIndex) {
    if (levelIndex < 0 || levelIndex >= _levels.length) return;
    final modules = _levels[levelIndex].modules;
    if (moduleIndex < 0 || moduleIndex >= modules.length) return;

    final mod = modules[moduleIndex];
    if (mod.status == ModuleStatus.locked) return;

    final key = BelajarProgressModel.keyOf(levelIndex, moduleIndex);
    if (_expandedModules.contains(key)) {
      _expandedModules.remove(key);
    } else {
      _expandedModules.add(key);
    }
    _recomputeLocks();
    notifyListeners();
  }

  Future<void> completeModule(int levelIndex, int moduleIndex) async {
    final mod = _levels[levelIndex].modules[moduleIndex];
    if (mod.status != ModuleStatus.available) return;

    final key = BelajarProgressModel.keyOf(levelIndex, moduleIndex);
    _completedModules.add(key);
    _recomputeLocks();
    notifyListeners();

    await _persistProgress();
  }

  Future<void> completeQuiz(int levelIndex, int moduleIndex) async {
    final mod = _levels[levelIndex].modules[moduleIndex];
    if (mod.quiz.status != ModuleStatus.available) return;

    final key = BelajarProgressModel.keyOf(levelIndex, moduleIndex);
    _completedModules.add(key);
    _completedQuizzes.add(key);
    _recomputeLocks();
    notifyListeners();

    await _persistProgress();
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
      debugPrint('Gagal menyimpan progres Ruang Belajar: $e');
    }
  }
}
