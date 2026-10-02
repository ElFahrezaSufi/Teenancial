enum JenisPinjaman { pinjaman, piutang }

extension JenisPinjamanLabel on JenisPinjaman {
  String get label => this == JenisPinjaman.pinjaman ? 'Pinjaman' : 'Piutang';
}

class PinjamanItem {
  final String id;
  final JenisPinjaman jenis;
  final String nama; // nama teman
  final double jumlah;
  final String kategori;
  final DateTime jatuhTempo;
  final String catatan;
  final String? dompetId; // relasi ke DompetItem.id (sumber uang)

  const PinjamanItem({
    required this.id,
    required this.jenis,
    required this.nama,
    required this.jumlah,
    required this.kategori,
    required this.jatuhTempo,
    this.catatan = '',
    this.dompetId,
  });
}
