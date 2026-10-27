enum JenisDompet { cash, accounts, card }

extension JenisDompetLabel on JenisDompet {
  String get label {
    switch (this) {
      case JenisDompet.cash:
        return 'Cash';
      case JenisDompet.accounts:
        return 'Accounts';
      case JenisDompet.card:
        return 'Card';
    }
  }
}

class DompetItem {
  final String id;
  final JenisDompet jenis;
  final String nama;
  double jumlah;
  final String? catatan;

  DompetItem({
    required this.id,
    required this.jenis,
    required this.nama,
    required this.jumlah,
    this.catatan,
  });

  DompetItem copyWith({
    String? id,
    JenisDompet? jenis,
    String? nama,
    double? jumlah,
    String? catatan,
  }) {
    return DompetItem(
      id: id ?? this.id,
      jenis: jenis ?? this.jenis,
      nama: nama ?? this.nama,
      jumlah: jumlah ?? this.jumlah,
      catatan: catatan ?? this.catatan,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'jenis': jenis.name,
        'nama': nama,
        'jumlah': jumlah,
        'catatan': catatan,
      };

  factory DompetItem.fromJson(Map<String, dynamic> json) {
    return DompetItem(
      id: json['id'] as String,
      jenis: JenisDompet.values.byName(json['jenis'] as String),
      nama: json['nama'] as String,
      jumlah: (json['jumlah'] as num).toDouble(),
      catatan: json['catatan'] as String?,
    );
  }
}