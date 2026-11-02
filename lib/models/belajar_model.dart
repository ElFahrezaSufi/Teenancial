enum ModuleStatus { locked, available, completed }

class QuizData {
  final String label;
  ModuleStatus status;

  QuizData({
    required this.label,
    this.status = ModuleStatus.locked,
  });
}

class ModuleData {
  final String title;
  final String description;
  final QuizData quiz;
  ModuleStatus status;
  bool isExpanded;

  ModuleData({
    required this.title,
    required this.description,
    required this.quiz,
    this.status = ModuleStatus.locked,
    this.isExpanded = false,
  });
}

class LevelData {
  final String tingkat;
  final String subtitle;
  final List<ModuleData> modules;

  LevelData({
    required this.tingkat,
    required this.subtitle,
    required this.modules,
  });
}

class BelajarProgressModel {
  final Set<String> completedModules;
  final Set<String> completedQuizzes;

  const BelajarProgressModel({
    this.completedModules = const {},
    this.completedQuizzes = const {},
  });

  static String keyOf(int levelIndex, int moduleIndex) =>
      '${levelIndex}_$moduleIndex';

  Map<String, dynamic> toMap() {
    return {
      'completedModules': completedModules.toList()..sort(),
      'completedQuizzes': completedQuizzes.toList()..sort(),
    };
  }

  factory BelajarProgressModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const BelajarProgressModel();
    final rawModules = map['completedModules'];
    final rawQuizzes = map['completedQuizzes'];

    return BelajarProgressModel(
      completedModules: rawModules is Iterable
          ? rawModules.map((e) => e.toString()).toSet()
          : const {},
      completedQuizzes: rawQuizzes is Iterable
          ? rawQuizzes.map((e) => e.toString()).toSet()
          : const {},
    );
  }
}
