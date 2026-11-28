import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/feen_catalog.dart';

enum FeenMessageRole {
  user,
  model;

  static FeenMessageRole fromName(String? raw) {
    return raw == 'user' ? FeenMessageRole.user : FeenMessageRole.model;
  }
}

/// Tombol pintasan navigasi kontekstual yang ditampilkan di bawah balasan Feen.
class FeenShortcutAction {
  final String route;
  final String label;

  const FeenShortcutAction({
    required this.route,
    required this.label,
  });
}

/// Argumen opsional untuk membuka [TanyaFeenScreen] dengan pertanyaan awal
/// kontekstual (mis. dari Laporan Keuangan, Target Menabung, atau Materi).
class TanyaFeenArgs {
  final String? initialPrompt;
  final bool startNewSession;

  const TanyaFeenArgs({
    this.initialPrompt,
    this.startNewSession = false,
  });
}

DateTime _parseChatDateTime(dynamic raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
  if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
  return DateTime.now();
}

FeenPose _parseFeenPose(dynamic raw) {
  if (raw is String) {
    for (final pose in FeenPose.values) {
      if (pose.name == raw) return pose;
    }
  }
  return FeenPose.normal;
}

/// Satu pesan percakapan di dalam sesi Tanya Feen.
class FeenChatMessage {
  final String id;
  final FeenMessageRole role;
  final String text;
  final DateTime createdAt;
  final FeenPose pose;
  final List<String> suggestedRoutes;
  final bool isPending;

  FeenChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.pose = FeenPose.normal,
    List<String> suggestedRoutes = const [],
    this.isPending = false,
  }) : suggestedRoutes = List<String>.unmodifiable(suggestedRoutes);

  bool get isUser => role == FeenMessageRole.user;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role.name,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      if (!isUser) 'pose': pose.name,
      if (!isUser && suggestedRoutes.isNotEmpty)
        'suggestedRoutes': suggestedRoutes,
    };
  }

  factory FeenChatMessage.fromMap(
    Map<String, dynamic> map, {
    String? docId,
  }) {
    final rawRoutes = map['suggestedRoutes'];
    final routes = rawRoutes is Iterable
        ? rawRoutes
            .map((e) => e.toString().trim())
            .where((r) => r.isNotEmpty)
            .toList()
        : const <String>[];

    return FeenChatMessage(
      id: docId ?? (map['id'] as String?) ?? '',
      role: FeenMessageRole.fromName(map['role'] as String?),
      text: (map['text'] as String?) ?? '',
      createdAt: _parseChatDateTime(map['createdAt']),
      pose: _parseFeenPose(map['pose']),
      suggestedRoutes: routes,
    );
  }

  FeenChatMessage copyWith({
    String? id,
    FeenMessageRole? role,
    String? text,
    DateTime? createdAt,
    FeenPose? pose,
    List<String>? suggestedRoutes,
    bool? isPending,
  }) {
    return FeenChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      pose: pose ?? this.pose,
      suggestedRoutes: suggestedRoutes ?? this.suggestedRoutes,
      isPending: isPending ?? this.isPending,
    );
  }
}

/// Metadata satu sesi percakapan Tanya Feen yang tersimpan di Firestore.
class FeenChatSession {
  final String id;
  final String title;
  final String lastMessagePreview;
  final int messageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FeenChatSession({
    required this.id,
    required this.title,
    this.lastMessagePreview = '',
    this.messageCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  static String buildTitleFromPrompt(String prompt) {
    final collapsed = prompt.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isEmpty) return 'Obrolan Baru';
    if (collapsed.length <= 48) return collapsed;
    return '${collapsed.substring(0, 45).trimRight()}...';
  }

  static String buildPreview(String text) {
    final stripped = text
        .replaceAll('**', '')
        .replaceAll('*', '')
        .replaceAll('`', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (stripped.length <= 80) return stripped;
    return '${stripped.substring(0, 77).trimRight()}...';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'lastMessagePreview': lastMessagePreview,
      'messageCount': messageCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory FeenChatSession.fromMap(
    Map<String, dynamic> map, {
    String? docId,
  }) {
    final created = _parseChatDateTime(map['createdAt']);
    final updated = map['updatedAt'] != null
        ? _parseChatDateTime(map['updatedAt'])
        : created;

    return FeenChatSession(
      id: docId ?? (map['id'] as String?) ?? '',
      title: ((map['title'] as String?)?.trim().isNotEmpty ?? false)
          ? (map['title'] as String).trim()
          : 'Obrolan Baru',
      lastMessagePreview: (map['lastMessagePreview'] as String?) ?? '',
      messageCount: (map['messageCount'] as num?)?.toInt() ?? 0,
      createdAt: created,
      updatedAt: updated,
    );
  }

  FeenChatSession copyWith({
    String? id,
    String? title,
    String? lastMessagePreview,
    int? messageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FeenChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      messageCount: messageCount ?? this.messageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
