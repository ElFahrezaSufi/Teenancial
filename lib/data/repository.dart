import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';

class RepositoryException implements Exception {
  final String message;
  const RepositoryException(this.message);

  @override
  String toString() => message;
}

class NotFoundException extends RepositoryException {
  const NotFoundException(super.message);
}

class AppRepository extends ChangeNotifier {
  AppRepository(
      {this.latency = const Duration(milliseconds: 700), bool seed = true}) {
    if (seed) _seed();
  }

  static AppRepository instance = AppRepository();
  static const String catTransferOut = 'c_transfer_out';
  static const String catTransferIn = 'c_transfer_in';
  static const String catPinjaman = 'c_pinjaman';
  static const String catPiutang = 'c_piutang';

  Duration latency;
  bool simulateError = false;

  final List<DompetItem> _wallets = [];
  final List<Category> _categories = [];
  final List<AppTransaction> _transactions = [];
  int _seq = 100;

  List<DompetItem> get wallets => _wallets;
  List<Category> get categories => List.unmodifiable(_categories);
  List<AppTransaction> get transactions => _sorted();
  double get totalSaldo => _wallets.fold(0, (s, w) => s + w.jumlah);

  DompetItem? walletById(String id) {
    for (final w in _wallets) {
      if (w.id == id) return w;
    }
    return null;
  }

  Category? categoryById(String id) {
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  AppTransaction? transactionById(String id) {
    for (final t in _transactions) {
      if (t.id == id) return t;
    }
    return null;
  }

  DompetItem? walletForSelection(int source, int? accountIndex) {
    if (source == 0) {
      for (final w in _wallets) {
        if (w.jenis == JenisDompet.cash) return w;
      }
      return null;
    }
    final digital = _wallets.where((w) => w.jenis != JenisDompet.cash).toList();
    if (accountIndex == null ||
        accountIndex < 0 ||
        accountIndex >= digital.length) {
      return null;
    }
    return digital[accountIndex];
  }

  List<Category> userCategories({required bool isExpense}) =>
      _categories.where((c) => c.isExpense == isExpense && !c.system).toList();

  int transactionCountForWallet(String walletId) =>
      _transactions.where((t) => t.walletId == walletId).length;

  List<AppTransaction> _sorted() {
    final list = List<AppTransaction>.of(_transactions);
    list.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.id.compareTo(a.id);
    });
    return list;
  }

  Future<void> _simulate() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (simulateError) {
      throw const RepositoryException(
          'Simulasi gagal memuat data. Periksa koneksi lalu coba lagi.');
    }
  }

  Future<List<AppTransaction>> loadTransactions() async {
    await _simulate();
    return _sorted();
  }

  Future<List<DompetItem>> loadWallets() async {
    await _simulate();
    return List<DompetItem>.of(_wallets);
  }

  Future<AppTransaction> getTransaction(String id) async {
    await _simulate();
    final t = transactionById(id);
    if (t == null) {
      throw const NotFoundException('Transaksi tidak ditemukan');
    }
    return t;
  }

  void _validateTransaction(AppTransaction t) {
    if (t.amount <= 0) {
      throw const RepositoryException('Jumlah uang harus lebih dari Rp 0');
    }
    final wallet = walletById(t.walletId);
    if (wallet == null) {
      throw const RepositoryException('Dompet tidak ditemukan');
    }
    final cat = categoryById(t.categoryId);
    if (cat == null) {
      throw const RepositoryException('Kategori tidak ditemukan');
    }
    if (cat.isExpense != t.isExpense) {
      throw const RepositoryException(
          'Kategori tidak sesuai dengan jenis transaksi');
    }
    if (t.isExpense && wallet.jumlah < t.amount) {
      throw const RepositoryException('Saldo dompet tidak cukup');
    }
  }

  void _apply(AppTransaction t, {required bool reverse}) {
    final wallet = walletById(t.walletId);
    if (wallet == null) return;
    final sign = (t.isExpense ? -1 : 1) * (reverse ? -1 : 1);
    wallet.jumlah += sign * t.amount;
  }

  Future<AppTransaction> addTransaction({
    required String walletId,
    required String categoryId,
    required bool isExpense,
    required double amount,
    required String note,
    required DateTime date,
  }) async {
    await _simulate();
    final t = AppTransaction(
      id: 't${++_seq}',
      walletId: walletId,
      categoryId: categoryId,
      isExpense: isExpense,
      amount: amount,
      note: note.trim(),
      date: date,
    );
    _validateTransaction(t);
    _transactions.add(t);
    _apply(t, reverse: false);
    notifyListeners();
    return t;
  }

  Future<AppTransaction> updateTransaction(AppTransaction updated) async {
    await _simulate();
    final index = _transactions.indexWhere((t) => t.id == updated.id);
    if (index == -1) {
      throw const RepositoryException('Transaksi tidak ditemukan');
    }
    final old = _transactions[index];
    _apply(old, reverse: true);
    try {
      _validateTransaction(updated);
    } catch (_) {
      _apply(old, reverse: false);
      rethrow;
    }
    _transactions[index] = updated;
    _apply(updated, reverse: false);
    notifyListeners();
    return updated;
  }

  Future<void> deleteTransaction(String id) async {
    await _simulate();
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) {
      throw const RepositoryException('Transaksi tidak ditemukan');
    }
    _apply(_transactions[index], reverse: true);
    _transactions.removeAt(index);
    notifyListeners();
  }

  Future<void> transfer({
    required String fromWalletId,
    required String toWalletId,
    required double amount,
    required String note,
    required DateTime date,
  }) async {
    await _simulate();
    if (fromWalletId == toWalletId) {
      throw const RepositoryException(
          'Dompet asal dan tujuan tidak boleh sama');
    }
    final out = AppTransaction(
      id: 't${++_seq}',
      walletId: fromWalletId,
      categoryId: catTransferOut,
      isExpense: true,
      amount: amount,
      note: note.trim(),
      date: date,
    );
    final inn = AppTransaction(
      id: 't${++_seq}',
      walletId: toWalletId,
      categoryId: catTransferIn,
      isExpense: false,
      amount: amount,
      note: note.trim(),
      date: date,
    );
    _validateTransaction(out);
    _validateTransaction(inn);
    _transactions.addAll([out, inn]);
    _apply(out, reverse: false);
    _apply(inn, reverse: false);
    notifyListeners();
  }

  bool _walletNameTaken(String nama, {String? exceptId}) => _wallets.any((w) =>
      w.id != exceptId && w.nama.toLowerCase() == nama.trim().toLowerCase());

  Future<DompetItem> addWallet({
    required JenisDompet jenis,
    required String nama,
    required double jumlah,
    String? catatan,
  }) async {
    await _simulate();
    if (_walletNameTaken(nama)) {
      throw const RepositoryException('Nama dompet sudah dipakai');
    }
    final w = DompetItem(
      id: 'w${++_seq}',
      jenis: jenis,
      nama: nama.trim(),
      jumlah: jumlah,
      catatan:
          (catatan == null || catatan.trim().isEmpty) ? null : catatan.trim(),
    );
    _wallets.add(w);
    notifyListeners();
    return w;
  }

  Future<DompetItem> updateWallet(
    String id, {
    required JenisDompet jenis,
    required String nama,
    required double jumlah,
    String? catatan,
  }) async {
    await _simulate();
    final w = walletById(id);
    if (w == null) throw const RepositoryException('Dompet tidak ditemukan');
    if (_walletNameTaken(nama, exceptId: id)) {
      throw const RepositoryException('Nama dompet sudah dipakai');
    }
    w
      ..jenis = jenis
      ..nama = nama.trim()
      ..jumlah = jumlah
      ..catatan =
          (catatan == null || catatan.trim().isEmpty) ? null : catatan.trim();
    notifyListeners();
    return w;
  }

  Future<void> deleteWallet(String id) async {
    await _simulate();
    final w = walletById(id);
    if (w == null) throw const RepositoryException('Dompet tidak ditemukan');
    final used = transactionCountForWallet(id);
    if (used > 0) {
      throw RepositoryException(
          'Dompet "${w.nama}" masih dipakai $used transaksi. Hapus atau pindahkan transaksinya dulu.');
    }
    _wallets.remove(w);
    notifyListeners();
  }

  void _seed() {
    _wallets.addAll([
      DompetItem(
          id: 'w1', jenis: JenisDompet.cash, nama: 'Cash', jumlah: 150000),
      DompetItem(
          id: 'w2',
          jenis: JenisDompet.accounts,
          nama: 'SeaBank',
          jumlah: 500000),
      DompetItem(
          id: 'w3', jenis: JenisDompet.accounts, nama: 'Go-Pay', jumlah: 75000),
      DompetItem(
          id: 'w4', jenis: JenisDompet.accounts, nama: 'Dana', jumlah: 120000),
      DompetItem(
          id: 'w5', jenis: JenisDompet.accounts, nama: 'Ovo', jumlah: 200000),
      DompetItem(
          id: 'w6', jenis: JenisDompet.card, nama: 'Mandiri', jumlah: 300000),
    ]);

    _categories.addAll(const [
      Category(
          id: 'c1',
          nama: 'Makanan',
          isExpense: true,
          type: TransactionType.food),
      Category(
          id: 'c2',
          nama: 'Transportasi',
          isExpense: true,
          type: TransactionType.transport),
      Category(
          id: 'c3',
          nama: 'Hiburan',
          isExpense: true,
          type: TransactionType.entertainment),
      Category(
          id: 'c4',
          nama: 'Elektronik',
          isExpense: true,
          type: TransactionType.other),
      Category(
          id: 'c5',
          nama: 'Lainnya',
          isExpense: true,
          type: TransactionType.other),
      Category(
          id: 'c6',
          nama: 'Uang Jajan',
          isExpense: false,
          type: TransactionType.income),
      Category(
          id: 'c7',
          nama: 'Hadiah',
          isExpense: false,
          type: TransactionType.income),
      Category(
          id: 'c8',
          nama: 'Gaji',
          isExpense: false,
          type: TransactionType.income),
      Category(
          id: 'c9',
          nama: 'Lainnya',
          isExpense: false,
          type: TransactionType.income),
      Category(
          id: catTransferOut,
          nama: 'Transfer Keluar',
          isExpense: true,
          type: TransactionType.other,
          system: true),
      Category(
          id: catTransferIn,
          nama: 'Transfer Masuk',
          isExpense: false,
          type: TransactionType.income,
          system: true),
      Category(
          id: catPinjaman,
          nama: 'Pinjaman',
          isExpense: false,
          type: TransactionType.income,
          system: true),
      Category(
          id: catPiutang,
          nama: 'Piutang',
          isExpense: true,
          type: TransactionType.other,
          system: true),
    ]);

    const seeds = <(String, String, String, double, String, int)>[
      ('t1', 'w1', 'c1', 25000, 'Makan siang kantin', 12),
      ('t2', 'w3', 'c2', 15000, 'Ojek ke sekolah', 12),
      ('t3', 'w2', 'c3', 54000, 'Langganan streaming', 11),
      ('t4', 'w4', 'c1', 32000, 'Boba bareng teman', 11),
      ('t5', 'w1', 'c1', 18000, 'Jajan istirahat', 10),
      ('t6', 'w5', 'c4', 120000, 'Earphone baru', 10),
      ('t7', 'w1', 'c2', 10000, 'Angkot pulang', 9),
      ('t8', 'w3', 'c1', 45000, 'Makan malam keluarga', 9),
      ('t9', 'w2', 'c3', 70000, 'Nonton bioskop', 8),
      ('t10', 'w1', 'c5', 20000, 'Fotokopi tugas', 8),
      ('t11', 'w4', 'c2', 22000, 'Ojek online', 7),
      ('t12', 'w1', 'c1', 30000, 'Sarapan', 6),
      ('t13', 'w6', 'c4', 85000, 'Kabel charger', 5),
      ('t14', 'w1', 'c3', 25000, 'Game online', 4),
      ('t15', 'w3', 'c1', 28000, 'Bakso', 3),
      ('t16', 'w1', 'c6', 150000, 'Uang jajan mingguan', 12),
      ('t17', 'w2', 'c7', 200000, 'Hadiah ulang tahun', 10),
      ('t18', 'w4', 'c6', 100000, 'Uang jajan tambahan', 8),
      ('t19', 'w2', 'c8', 350000, 'Gaji part-time', 6),
      ('t20', 'w1', 'c6', 150000, 'Uang jajan mingguan', 5),
      ('t21', 'w5', 'c9', 50000, 'Menang lomba', 4),
      ('t22', 'w3', 'c7', 75000, 'Angpao', 3),
      ('t23', 'w6', 'c6', 200000, 'Kiriman orang tua', 2),
      ('t24', 'w1', 'c1', 22000, 'Jajan sore', 2),
    ];
    for (final s in seeds) {
      final cat = categoryById(s.$3)!;
      _transactions.add(AppTransaction(
        id: s.$1,
        walletId: s.$2,
        categoryId: s.$3,
        isExpense: cat.isExpense,
        amount: s.$4,
        note: s.$5,
        date: DateTime(2026, 7, s.$6),
      ));
    }
  }
}

class DompetData {
  DompetData._();
  static final DompetData instance = DompetData._();

  List<DompetItem> get items => AppRepository.instance.wallets;
  double get totalSaldo => AppRepository.instance.totalSaldo;
  List<DompetItem> byJenis(JenisDompet jenis) =>
      items.where((e) => e.jenis == jenis).toList();
}
