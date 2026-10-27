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
  final DateTime? dueDate; // Batas waktu untuk pinjaman/piutang
  final String? contactId; // ID kontak terkait (teman/tujuan)
  final bool isPaid; // Status pelunasan (khusus hutang/piutang)

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
    this.dueDate,
    this.contactId,
    this.isPaid = false,
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
    DateTime? dueDate,
    String? contactId,
    bool? isPaid,
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
      dueDate: dueDate ?? this.dueDate,
      contactId: contactId ?? this.contactId,
      isPaid: isPaid ?? this.isPaid,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'notes': notes,
        'categoryId': categoryId,
        'type': type.name,
        'dompetId': dompetId,
        'destinationDompetId': destinationDompetId,
        'dueDate': dueDate?.toIso8601String(),
        'contactId': contactId,
        'isPaid': isPaid,
      };

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      notes: (json['notes'] as String?) ?? '',
      categoryId: json['categoryId'] as String,
      type: TransactionType.values.byName(json['type'] as String),
      dompetId: json['dompetId'] as String,
      destinationDompetId: json['destinationDompetId'] as String?,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      contactId: json['contactId'] as String?,
      isPaid: (json['isPaid'] as bool?) ?? false,
    );
  }
}

