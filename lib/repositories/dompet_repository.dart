import '../data/dompet_model.dart';

class DompetRepository {
  DompetRepository._();
  static final DompetRepository instance = DompetRepository._();

  final List<DompetItem> _items = [
    DompetItem(id: 'd1', jenis: JenisDompet.cash, nama: 'Dompet Utama (Cash)', jumlah: 150000),
    DompetItem(id: 'd2', jenis: JenisDompet.accounts, nama: 'SeaBank', jumlah: 500000),
    DompetItem(id: 'd3', jenis: JenisDompet.accounts, nama: 'Go-Pay', jumlah: 75000),
    DompetItem(id: 'd4', jenis: JenisDompet.accounts, nama: 'Dana', jumlah: 125000),
    DompetItem(id: 'd5', jenis: JenisDompet.accounts, nama: 'Ovo', jumlah: 20000),
    DompetItem(id: 'd6', jenis: JenisDompet.card, nama: 'Mandiri', jumlah: 1200000),
  ];

  // READ
  Future<List<DompetItem>> getDompets({bool simulateError = false}) async {
    await Future.delayed(const Duration(milliseconds: 1000)); // Simulasi Loading
    if (simulateError) {
      throw Exception('Simulasi gagal memuat data dompet');
    }
    return List<DompetItem>.from(_items);
  }

  // CREATE
  Future<void> addDompet(DompetItem item) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulasi Loading
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

  double get totalSaldo => _items.fold(0, (sum, item) => sum + item.jumlah);
}
