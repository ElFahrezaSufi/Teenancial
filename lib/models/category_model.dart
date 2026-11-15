import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/category_icons.dart';
import 'transaction_model.dart';

typedef CategoryResolver = CategoryModel Function(
  String id, {
  TransactionType? fallbackType,
});

class CategoryModel {
  final String id;
  final String name;
  final TransactionType type;
  final IconData icon;
  final String iconKey;
  final int colorValue;
  final bool isCustom;
  final DateTime? createdAt;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    this.iconKey = 'category',
    this.colorValue = 0xFF627931,
    this.isCustom = false,
    this.createdAt,
  });

  Color get color => Color(colorValue);

  /// Menandakan apakah kategori ini adalah kategori "Lainnya" bawaan yang
  /// selalu diletakkan di urutan paling akhir pada jenis transaksinya.
  bool get isDefaultFallback =>
      id == 'c19' || id == 'c6' || id == 'c10' || id == 'c14' || id == 'c18';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'iconKey': iconKey,
      'colorValue': colorValue,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    };
  }

  factory CategoryModel.fromMap(
    Map<String, dynamic> map, {
    String? docId,
  }) {
    final rawType = (map['type'] as String?) ?? TransactionType.expense.name;
    final parsedType = TransactionType.values.firstWhere(
      (e) => e.name == rawType,
      orElse: () => TransactionType.expense,
    );

    final rawIconKey = (map['iconKey'] as String?) ?? 'category';
    final rawColor = (map['colorValue'] as num?)?.toInt() ?? 0xFF627931;

    DateTime? parsedCreatedAt;
    final rawCreatedAt = map['createdAt'];
    if (rawCreatedAt is Timestamp) {
      parsedCreatedAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt);
    }

    return CategoryModel(
      id: docId ?? (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      type: parsedType,
      icon: CategoryIcons.iconForKey(rawIconKey),
      iconKey: rawIconKey,
      colorValue: rawColor,
      isCustom: true,
      createdAt: parsedCreatedAt,
    );
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    TransactionType? type,
    IconData? icon,
    String? iconKey,
    int? colorValue,
    bool? isCustom,
    DateTime? createdAt,
  }) {
    final resolvedIconKey = iconKey ?? this.iconKey;
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ??
          (iconKey != null ? CategoryIcons.iconForKey(iconKey) : this.icon),
      iconKey: resolvedIconKey,
      colorValue: colorValue ?? this.colorValue,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
