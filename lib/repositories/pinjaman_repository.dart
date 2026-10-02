import '../data/pinjaman_model.dart';
import '../data/sim_settings.dart';

class PinjamanRepository {
  PinjamanRepository._();
  static final PinjamanRepository instance = PinjamanRepository._();

  final List<PinjamanItem> _items = [
    PinjamanItem(
        id: 'p1',
        jenis: JenisPinjaman.pinjaman,
        nama: 'Budi',
        jumlah: 50000,
        kategori: 'Makanan',
        jatuhTempo: DateTime.now().add(const Duration(days: 7)),
        dompetId: 'd1'),
    PinjamanItem(
        id: 'p2',
        jenis: JenisPinjaman.piutang,
        nama: 'Sari',
        jumlah: 25000,
        kategori: 'Transportasi',
        jatuhTempo: DateTime.now().add(const Duration(days: 3)),
        dompetId: 'd2'),
    PinjamanItem(
        id: 'p3',
        jenis: JenisPinjaman.piutang,
        nama: 'Andi',
        jumlah: 100000,
        kategori: 'Hiburan',
        jatuhTempo: DateTime.now().add(const Duration(days: 14)),
        dompetId: 'd3'),
  ];

  // READ
  Future<List<PinjamanItem>> getAll({bool simulateError = false}) async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (simulateError || SimSettings.forceError.value) {
      throw Exception('Simulasi gagal memuat data pinjaman');
    }
    return List<PinjamanItem>.from(_items);
  }

  // CREATE
  Future<void> add(PinjamanItem item) async {
    await Future.delayed(const Duration(milliseconds: 700));
    _items.insert(0, item);
  }

  // DELETE
  Future<void> delete(String id) async {
    await Future.delayed(const Duration(milliseconds: 700));
    _items.removeWhere((p) => p.id == id);
  }

  double total(JenisPinjaman jenis) =>
      _items.where((p) => p.jenis == jenis).fold(0.0, (s, p) => s + p.jumlah);
}
