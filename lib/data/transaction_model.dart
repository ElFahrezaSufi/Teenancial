import 'package:flutter/material.dart';

enum TransactionType { income, expense, transfer, debt, receivable }

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
  final String dompetId; // Mandatory untuk semua jenis transaksi (dompet sumber)
  final String? destinationDompetId; // Khusus untuk transaksi Transfer (dompet tujuan)

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    this.notes = '',
    required this.categoryId,
    required this.type,
    required this.dompetId,
    this.destinationDompetId,
  });

  TransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    String? notes,
    String? categoryId,
    TransactionType? type,
    String? dompetId,
    String? destinationDompetId,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      dompetId: dompetId ?? this.dompetId,
      destinationDompetId: destinationDompetId ?? this.destinationDompetId,
    );
  }
}
