import '../data/dompet_model.dart';
import '../data/sim_settings.dart';

class DompetRepository {
  DompetRepository._();
  static final DompetRepository instance = DompetRepository._();

  final List<DompetItem> _items = [
    DompetItem(
        id: 'd1',
        jenis: JenisDompet.cash,
        nama: 'Dompet Utama (Cash)',
        jumlah: 150000),
    DompetItem(
        id: 'd2', jenis: JenisDompet.accounts, nama: 'SeaBank', jumlah: 500000),
    DompetItem(
        id: 'd3', jenis: JenisDompet.accounts, nama: 'Go-Pay', jumlah: 75000),
    DompetItem(
        id: 'd4', jenis: JenisDompet.accounts, nama: 'Dana', jumlah: 125000),
    DompetItem(
        id: 'd5', jenis: JenisDompet.accounts, nama: 'Ovo', jumlah: 20000),
    DompetItem(
        id: 'd6', jenis: JenisDompet.card, nama: 'Mandiri', jumlah: 1200000),
  ];

  // READ
  Future<List<DompetItem>> getDompets({bool simulateError = false}) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    if (simulateError || SimSettings.forceError.value) {
      throw Exception('Simulasi gagal memuat data dompet');
    }
    return List<DompetItem>.from(_items);
  }

  // CREATE
  Future<void> addDompet(DompetItem item) async {
    await Future.delayed(const Duration(seconds: 1));
    _items.add(item);
  }

  // UPDATE
  Future<void> updateDompet(DompetItem item) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulasi Loading
    final index = _items.indexWhere((d) => d.id == item.id);
    if (index != -1) {
      _items[index] = item;
    } else {
      throw Exception('Data dompet tidak ditemukan');
    }
  }

  // DELETE
  Future<void> deleteDompet(String id) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulasi Loading
    _items.removeWhere((d) => d.id == id);
  }

  static const List<String> _digitalIds = ['d2', 'd3', 'd4', 'd5'];
  String? idFromSelection(int source, int? accountIndex) {
    if (source == 0) return 'd1';
    if (accountIndex == null ||
        accountIndex < 0 ||
        accountIndex >= _digitalIds.length) return null;
    return _digitalIds[accountIndex];
  }

  DompetItem? findById(String id) {
    for (final d in _items) {
      if (d.id == id) return d;
    }
    return null;
  }

  Future<void> transfer(
      {required String fromId, String? toId, required double amount}) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulasi Loading
    final from = findById(fromId);
    if (from == null) throw Exception('Dompet asal tidak ditemukan');
    if (amount <= 0) throw Exception('Jumlah harus lebih dari 0');
    if (from.jumlah < amount) throw Exception('Saldo ${from.nama} tidak cukup');
    DompetItem? to;
    if (toId != null) {
      to = findById(toId);
      if (to == null) throw Exception('Dompet tujuan tidak ditemukan');
    }
    from.jumlah -= amount;
    if (to != null) to.jumlah += amount;
  }

  Future<void> tambahSaldo(String id, double amount) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final d = findById(id);
    if (d == null) throw Exception('Dompet tidak ditemukan');
    d.jumlah += amount;
  }

  double get totalSaldo => _items.fold(0, (sum, item) => sum + item.jumlah);
}
