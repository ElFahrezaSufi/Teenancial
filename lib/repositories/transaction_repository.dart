import 'package:flutter/material.dart';
import '../data/transaction_model.dart';

class TransactionRepository {
  TransactionRepository._();
  static final TransactionRepository instance = TransactionRepository._();

  // 5 Data Referensi / Kategori
  final List<CategoryModel> categories = const [
    CategoryModel(id: 'c1', name: 'Uang Jajan', type: TransactionType.income, icon: Icons.attach_money),
    CategoryModel(id: 'c2', name: 'Hadiah', type: TransactionType.income, icon: Icons.card_giftcard),
    CategoryModel(id: 'c3', name: 'Makanan', type: TransactionType.expense, icon: Icons.restaurant),
    CategoryModel(id: 'c4', name: 'Transportasi', type: TransactionType.expense, icon: Icons.directions_bus),
    CategoryModel(id: 'c5', name: 'Hiburan', type: TransactionType.expense, icon: Icons.sports_esports),
    CategoryModel(id: 'c6', name: 'Lainnya', type: TransactionType.expense, icon: Icons.category),
  ];

  // Minimal 20 Data Utama (Data Transaksi)
  final List<TransactionModel> _transactions = [
    // Hari ini (simulasi)
    TransactionModel(id: 't1', title: 'Jajan Kantin', amount: 25000, date: DateTime.now().subtract(const Duration(hours: 2)), categoryId: 'c3', type: TransactionType.expense, isDigital: false),
    TransactionModel(id: 't2', title: 'Uang Saku Mingguan', amount: 150000, date: DateTime.now().subtract(const Duration(hours: 5)), categoryId: 'c1', type: TransactionType.income, isDigital: true),
    TransactionModel(id: 't3', title: 'Beli Pulsa', amount: 20000, date: DateTime.now().subtract(const Duration(hours: 10)), categoryId: 'c6', type: TransactionType.expense, isDigital: true),
    // Kemarin
    TransactionModel(id: 't4', title: 'Ongkos Ojol', amount: 15000, date: DateTime.now().subtract(const Duration(days: 1, hours: 1)), categoryId: 'c4', type: TransactionType.expense, isDigital: true),
    TransactionModel(id: 't5', title: 'Nonton Bioskop', amount: 45000, date: DateTime.now().subtract(const Duration(days: 1, hours: 6)), categoryId: 'c5', type: TransactionType.expense, isDigital: true),
    TransactionModel(id: 't6', title: 'Hadiah Nenek', amount: 50000, date: DateTime.now().subtract(const Duration(days: 1, hours: 10)), categoryId: 'c2', type: TransactionType.income, isDigital: false),
    // 2 hari lalu
    TransactionModel(id: 't7', title: 'Makan Siang', amount: 20000, date: DateTime.now().subtract(const Duration(days: 2, hours: 2)), categoryId: 'c3', type: TransactionType.expense, isDigital: false),
    TransactionModel(id: 't8', title: 'Beli Buku Tulis', amount: 35000, date: DateTime.now().subtract(const Duration(days: 2, hours: 4)), categoryId: 'c6', type: TransactionType.expense, isDigital: false),
    // 3 hari lalu
    TransactionModel(id: 't9', title: 'Ongkos Angkot', amount: 5000, date: DateTime.now().subtract(const Duration(days: 3, hours: 1)), categoryId: 'c4', type: TransactionType.expense, isDigital: false),
    TransactionModel(id: 't10', title: 'Boba Drink', amount: 18000, date: DateTime.now().subtract(const Duration(days: 3, hours: 5)), categoryId: 'c3', type: TransactionType.expense, isDigital: true),
    TransactionModel(id: 't11', title: 'Uang Saku Tambahan', amount: 50000, date: DateTime.now().subtract(const Duration(days: 3, hours: 8)), categoryId: 'c1', type: TransactionType.income, isDigital: false),
    // Minggu lalu
    TransactionModel(id: 't12', title: 'Topup Game', amount: 60000, date: DateTime.now().subtract(const Duration(days: 7, hours: 3)), categoryId: 'c5', type: TransactionType.expense, isDigital: true),
    TransactionModel(id: 't13', title: 'Ongkos Pulang', amount: 15000, date: DateTime.now().subtract(const Duration(days: 7, hours: 5)), categoryId: 'c4', type: TransactionType.expense, isDigital: false),
    TransactionModel(id: 't14', title: 'Makan Bakso', amount: 15000, date: DateTime.now().subtract(const Duration(days: 8, hours: 2)), categoryId: 'c3', type: TransactionType.expense, isDigital: false),
    // Bulan lalu
    TransactionModel(id: 't15', title: 'Hadiah Ultah', amount: 200000, date: DateTime.now().subtract(const Duration(days: 30, hours: 1)), categoryId: 'c2', type: TransactionType.income, isDigital: true),
    TransactionModel(id: 't16', title: 'Beli Kuota', amount: 75000, date: DateTime.now().subtract(const Duration(days: 30, hours: 4)), categoryId: 'c6', type: TransactionType.expense, isDigital: true),
    TransactionModel(id: 't17', title: 'Makan Malam', amount: 30000, date: DateTime.now().subtract(const Duration(days: 32, hours: 6)), categoryId: 'c3', type: TransactionType.expense, isDigital: true),
    TransactionModel(id: 't18', title: 'Ongkos PP', amount: 30000, date: DateTime.now().subtract(const Duration(days: 35, hours: 2)), categoryId: 'c4', type: TransactionType.expense, isDigital: false),
    TransactionModel(id: 't19', title: 'Main Warnet', amount: 20000, date: DateTime.now().subtract(const Duration(days: 36, hours: 3)), categoryId: 'c5', type: TransactionType.expense, isDigital: false),
    TransactionModel(id: 't20', title: 'Jual Barang Bekas', amount: 100000, date: DateTime.now().subtract(const Duration(days: 40, hours: 10)), categoryId: 'c1', type: TransactionType.income, isDigital: false),
  ];

  CategoryModel getCategoryById(String id) {
    return categories.firstWhere((cat) => cat.id == id, orElse: () => categories.last);
  }

  // CREATE
  Future<void> addTransaction(TransactionModel transaction) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulasi Loading
    _transactions.insert(0, transaction); // Add to top
  }

  // READ
  Future<List<TransactionModel>> getTransactions({bool simulateError = false}) async {
    await Future.delayed(const Duration(milliseconds: 1000)); // Simulasi Loading
    if (simulateError) {
      throw Exception('Simulasi gagal memuat data');
    }
    // Return a sorted copy
    final copy = List<TransactionModel>.from(_transactions);
    copy.sort((a, b) => b.date.compareTo(a.date));
    return copy;
  }

  // UPDATE
  Future<void> updateTransaction(TransactionModel transaction) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulasi Loading
    final index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      _transactions[index] = transaction;
    } else {
      throw Exception('Data tidak ditemukan');
    }
  }

  // DELETE
  Future<void> deleteTransaction(String id) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulasi Loading
    _transactions.removeWhere((t) => t.id == id);
  }

  List<CategoryModel> getCategoriesByType(TransactionType type) {
    return categories.where((c) => c.type == type).toList();
  }
}
