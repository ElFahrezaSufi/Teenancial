import 'package:flutter/material.dart';
import 'transaction_model.dart';

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
