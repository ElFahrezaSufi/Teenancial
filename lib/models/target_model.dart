import 'package:cloud_firestore/cloud_firestore.dart';

class TargetItem {
  final String id;
  final String nama;
  final double targetAmount;
  final String imageUrl;
  bool isPinned;
  final DateTime createdAt;

  TargetItem({
    required this.id,
    required this.nama,
    required this.targetAmount,
    required this.imageUrl,
    this.isPinned = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'targetAmount': targetAmount,
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
      imageUrl: (map['imageUrl'] as String?) ?? '',
      isPinned: map['isPinned'] == true,
      createdAt: parsedCreatedAt,
    );
  }

  TargetItem copyWith({
    String? id,
    String? nama,
    double? targetAmount,
    String? imageUrl,
    bool? isPinned,
    DateTime? createdAt,
  }) {
    return TargetItem(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      targetAmount: targetAmount ?? this.targetAmount,
      imageUrl: imageUrl ?? this.imageUrl,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
