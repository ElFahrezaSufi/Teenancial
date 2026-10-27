import 'package:uuid/uuid.dart';

class TargetItem {
  final String id;
  final String nama;
  final double targetAmount;
  final String imageUrl;
  bool isPinned;

  TargetItem({
    String? id,
    required this.nama,
    required this.targetAmount,
    required this.imageUrl,
    this.isPinned = false,
  }) : id = id ?? const Uuid().v4();

  TargetItem copyWith({
    String? id,
    String? nama,
    double? targetAmount,
    String? imageUrl,
    bool? isPinned,
  }) {
    return TargetItem(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      targetAmount: targetAmount ?? this.targetAmount,
      imageUrl: imageUrl ?? this.imageUrl,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'targetAmount': targetAmount,
        'imageUrl': imageUrl,
        'isPinned': isPinned,
      };

  factory TargetItem.fromJson(Map<String, dynamic> json) {
    return TargetItem(
      id: json['id'] as String?,
      nama: json['nama'] as String,
      targetAmount: (json['targetAmount'] as num).toDouble(),
      imageUrl: json['imageUrl'] as String,
      isPinned: (json['isPinned'] as bool?) ?? false,
    );
  }
}

class TargetData {
  TargetData._();
  static final TargetData instance = TargetData._();

  final List<TargetItem> items = [];

  void pinItem(TargetItem itemToPin) {
    for (var item in items) {
      item.isPinned = (item == itemToPin);
    }
  }

  TargetItem? get pinnedItem {
    try {
      return items.firstWhere((element) => element.isPinned);
    } catch (e) {
      return null;
    }
  }
}
