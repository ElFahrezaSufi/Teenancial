enum ModuleStatus { locked, available, completed }

// ─── ModuleSection ────────────────────────────────────────────────────────────

class ModuleSection {
  final String heading;
  final String body;

  const ModuleSection({required this.heading, required this.body});

  factory ModuleSection.fromMap(Map<String, dynamic> map) {
    return ModuleSection(
      heading: (map['heading'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
    );
  }
}

// ─── QuizQuestion ─────────────────────────────────────────────────────────────

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'];
    final options = rawOptions is Iterable
        ? rawOptions.map((e) => e.toString()).toList()
        : <String>[];
    final rawIndex = map['correctIndex'];
    final index = rawIndex is num ? rawIndex.toInt() : 0;
    return QuizQuestion(
      question: (map['question'] as String?) ?? '',
      options: options,
      correctIndex: (index >= 0 && index < options.length) ? index : 0,
      explanation: (map['explanation'] as String?) ?? '',
    );
  }
}

// ─── QuizData ─────────────────────────────────────────────────────────────────

class QuizData {
  final String label;
  final ModuleStatus status;
  final List<QuizQuestion> questions;
  final int passingScore;

  const QuizData({
    required this.label,
    this.status = ModuleStatus.locked,
    this.questions = const [],
    this.passingScore = 70,
  });

  factory QuizData.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const QuizData(label: 'Kuis');
    final rawQuestions = map['questions'];
    final rawPassing = map['passingScore'];
    return QuizData(
      label: (map['label'] as String?) ?? 'Kuis',
      passingScore: rawPassing is num ? rawPassing.toInt() : 70,
      questions: rawQuestions is Iterable
          ? rawQuestions
              .whereType<Map>()
              .map((e) => QuizQuestion.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }

  QuizData copyWith({
    String? label,
    ModuleStatus? status,
    List<QuizQuestion>? questions,
    int? passingScore,
  }) {
    return QuizData(
      label: label ?? this.label,
      status: status ?? this.status,
      questions: questions ?? this.questions,
      passingScore: passingScore ?? this.passingScore,
    );
  }
}

// ─── ModuleData ───────────────────────────────────────────────────────────────

class ModuleData {
  final String id;
  final String levelId;
  final int order;
  final String title;
  final String description;
  final List<ModuleSection> sections;
  final List<String> references;
  final QuizData quiz;
  final ModuleStatus status;
  final bool isExpanded;

  const ModuleData({
    required this.id,
    this.levelId = '',
    this.order = 0,
    required this.title,
    required this.description,
    this.sections = const [],
    this.references = const [],
    required this.quiz,
    this.status = ModuleStatus.locked,
    this.isExpanded = false,
  });

  factory ModuleData.fromMap(Map<String, dynamic> map,
      {required String docId}) {
    final rawSections = map['sections'];
    final rawReferences = map['references'];
    final rawOrder = map['order'];
    return ModuleData(
      id: docId,
      levelId: (map['levelId'] as String?) ?? '',
      order: rawOrder is num ? rawOrder.toInt() : 0,
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      sections: rawSections is Iterable
          ? rawSections
              .whereType<Map>()
              .map((e) => ModuleSection.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      references: rawReferences is Iterable
          ? rawReferences.map((e) => e.toString()).toList()
          : const [],
      quiz: QuizData.fromMap(
        map['quiz'] is Map
            ? Map<String, dynamic>.from(map['quiz'] as Map)
            : null,
      ),
    );
  }

  ModuleData copyWith({
    String? id,
    String? levelId,
    int? order,
    String? title,
    String? description,
    List<ModuleSection>? sections,
    List<String>? references,
    QuizData? quiz,
    ModuleStatus? status,
    bool? isExpanded,
  }) {
    return ModuleData(
      id: id ?? this.id,
      levelId: levelId ?? this.levelId,
      order: order ?? this.order,
      title: title ?? this.title,
      description: description ?? this.description,
      sections: sections ?? this.sections,
      references: references ?? this.references,
      quiz: quiz ?? this.quiz,
      status: status ?? this.status,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}

// ─── LevelData ────────────────────────────────────────────────────────────────

class LevelData {
  final String id;
  final int order;
  final String tingkat;
  final String subtitle;
  final List<ModuleData> modules;

  const LevelData({
    required this.id,
    this.order = 0,
    required this.tingkat,
    required this.subtitle,
    this.modules = const [],
  });

  factory LevelData.fromMap(
    Map<String, dynamic> map, {
    required String docId,
    List<ModuleData> modules = const [],
  }) {
    final rawOrder = map['order'];
    return LevelData(
      id: docId,
      order: rawOrder is num ? rawOrder.toInt() : 0,
      tingkat: (map['tingkat'] as String?) ?? '',
      subtitle: (map['subtitle'] as String?) ?? '',
      modules: modules,
    );
  }

  LevelData copyWith({
    String? id,
    int? order,
    String? tingkat,
    String? subtitle,
    List<ModuleData>? modules,
  }) {
    return LevelData(
      id: id ?? this.id,
      order: order ?? this.order,
      tingkat: tingkat ?? this.tingkat,
      subtitle: subtitle ?? this.subtitle,
      modules: modules ?? this.modules,
    );
  }
}

// ─── BelajarProgressModel ─────────────────────────────────────────────────────

class BelajarProgressModel {
  final Set<String> completedModules;
  final Set<String> completedQuizzes;

  const BelajarProgressModel({
    this.completedModules = const {},
    this.completedQuizzes = const {},
  });

  static bool isLegacyKey(String key) => RegExp(r'^\d+_\d+$').hasMatch(key);

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
