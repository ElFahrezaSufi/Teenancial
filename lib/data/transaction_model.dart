import 'package:flutter/material.dart';

enum TransactionType { income, expense }

class CategoryModel {
  final String id;
  final String name;
  final TransactionType type;
  final IconData icon;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
  });
}

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String notes;
  final String categoryId;
  final TransactionType type;
  final bool isDigital; // true for Digital, false for Cash

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    this.notes = '',
    required this.categoryId,
    required this.type,
    required this.isDigital,
  });

  TransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    String? notes,
    String? categoryId,
    TransactionType? type,
    bool? isDigital,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      isDigital: isDigital ?? this.isDigital,
    );
  }
}
