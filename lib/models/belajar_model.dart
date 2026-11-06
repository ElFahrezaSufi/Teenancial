enum ModuleStatus { locked, available, completed }

class QuizData {
  final String label;
  final ModuleStatus status;

  const QuizData({
    required this.label,
    this.status = ModuleStatus.locked,
  });

  QuizData copyWith({
    String? label,
    ModuleStatus? status,
  }) {
    return QuizData(
      label: label ?? this.label,
      status: status ?? this.status,
    );
  }
}

class ModuleData {
  final String title;
  final String description;
  final QuizData quiz;
  final ModuleStatus status;
  final bool isExpanded;

  const ModuleData({
    required this.title,
    required this.description,
    required this.quiz,
    this.status = ModuleStatus.locked,
    this.isExpanded = false,
  });

  ModuleData copyWith({
    String? title,
    String? description,
    QuizData? quiz,
    ModuleStatus? status,
    bool? isExpanded,
  }) {
    return ModuleData(
      title: title ?? this.title,
      description: description ?? this.description,
      quiz: quiz ?? this.quiz,
      status: status ?? this.status,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}

class LevelData {
  final String tingkat;
  final String subtitle;
  final List<ModuleData> modules;

  const LevelData({
    required this.tingkat,
    required this.subtitle,
    required this.modules,
  });

  LevelData copyWith({
    String? tingkat,
    String? subtitle,
    List<ModuleData>? modules,
  }) {
    return LevelData(
      tingkat: tingkat ?? this.tingkat,
      subtitle: subtitle ?? this.subtitle,
      modules: modules ?? this.modules,
    );
  }
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
