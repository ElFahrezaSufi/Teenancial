import 'package:cloud_firestore/cloud_firestore.dart';

class TargetItem {
  final String id;
  final String nama;
  final double targetAmount;
  final double savedAmount;
  final String imageUrl;
  final bool isPinned;
  final DateTime createdAt;

  TargetItem({
    required this.id,
    required this.nama,
    required this.targetAmount,
    this.savedAmount = 0.0,
    required this.imageUrl,
    this.isPinned = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get progress => targetAmount > 0
      ? (savedAmount / targetAmount).clamp(0.0, 1.0)
      : 0.0;

  bool get isAchieved => targetAmount > 0 && savedAmount >= targetAmount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'targetAmount': targetAmount,
      'savedAmount': savedAmount,
      'imageUrl': imageUrl,
      'isPinned': isPinned,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TargetItem.fromMap(
    Map<String, dynamic> map, {
    String? docId,
  }) {
    final rawCreatedAt = map['createdAt'];
    DateTime parsedCreatedAt = DateTime.now();
    if (rawCreatedAt is Timestamp) {
      parsedCreatedAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    }

    return TargetItem(
      id: docId ?? (map['id'] as String?) ?? '',
      nama: (map['nama'] as String?) ?? '',
      targetAmount: (map['targetAmount'] as num?)?.toDouble() ?? 0.0,
      savedAmount: (map['savedAmount'] as num?)?.toDouble() ?? 0.0,
      imageUrl: (map['imageUrl'] as String?) ?? '',
      isPinned: map['isPinned'] == true,
      createdAt: parsedCreatedAt,
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
  }) {
    return TargetItem(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      imageUrl: imageUrl ?? this.imageUrl,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
