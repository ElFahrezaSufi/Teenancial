import 'package:cloud_firestore/cloud_firestore.dart';

class TargetItem {
  final String id;
  final String nama;
  final double targetAmount;
  final double savedAmount;
  final String imageUrl;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime? deadline;

  TargetItem({
    required this.id,
    required this.nama,
    required this.targetAmount,
    this.savedAmount = 0.0,
    required this.imageUrl,
    this.isPinned = false,
    DateTime? createdAt,
    this.deadline,
  }) : createdAt = createdAt ?? DateTime.now();

  double get progress => targetAmount > 0
      ? (savedAmount / targetAmount).clamp(0.0, 1.0)
      : 0.0;

  bool get isAchieved => targetAmount > 0 && savedAmount >= targetAmount;

  double get remainingAmount =>
      (targetAmount - savedAmount).clamp(0.0, double.infinity);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'targetAmount': targetAmount,
      'savedAmount': savedAmount,
      'imageUrl': imageUrl,
      'isPinned': isPinned,
      'createdAt': Timestamp.fromDate(createdAt),
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
    };
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }

  factory TargetItem.fromMap(
    Map<String, dynamic> map, {
    String? docId,
  }) {
    final parsedCreatedAt = _parseDateTime(map['createdAt']) ?? DateTime.now();

    return TargetItem(
      id: docId ?? (map['id'] as String?) ?? '',
      nama: (map['nama'] as String?) ?? '',
      targetAmount: (map['targetAmount'] as num?)?.toDouble() ?? 0.0,
      savedAmount: (map['savedAmount'] as num?)?.toDouble() ?? 0.0,
      imageUrl: (map['imageUrl'] as String?) ?? '',
      isPinned: map['isPinned'] == true,
      createdAt: parsedCreatedAt,
      deadline: _parseDateTime(map['deadline']),
    );
  }

  TargetItem copyWith({
    String? id,
    String? nama,
    double? targetAmount,
    double? savedAmount,
    String? imageUrl,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? deadline,
    bool clearDeadline = false,
  }) {
    return TargetItem(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      imageUrl: imageUrl ?? this.imageUrl,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
    );
  }
}
