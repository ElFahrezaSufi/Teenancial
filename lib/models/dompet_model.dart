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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jenis': jenis.name,
      'nama': nama,
      'jumlah': jumlah,
      'catatan': catatan,
    };
  }

  factory DompetItem.fromMap(
    Map<String, dynamic> map, {
    String? docId,
  }) {
    final jenisStr = (map['jenis'] as String?) ?? JenisDompet.cash.name;
    final parsedJenis = JenisDompet.values.firstWhere(
      (e) => e.name == jenisStr,
      orElse: () => JenisDompet.cash,
    );

    return DompetItem(
      id: docId ?? (map['id'] as String?) ?? '',
      jenis: parsedJenis,
      nama: (map['nama'] as String?) ?? 'Dompet',
      jumlah: (map['jumlah'] as num?)?.toDouble() ?? 0.0,
      catatan: map['catatan'] as String?,
    );
  }

  DompetItem copyWith({
    String? id,
    JenisDompet? jenis,
    String? nama,
    double? jumlah,
    String? catatan,
    bool clearCatatan = false,
  }) {
    return DompetItem(
      id: id ?? this.id,
      jenis: jenis ?? this.jenis,
      nama: nama ?? this.nama,
      jumlah: jumlah ?? this.jumlah,
      catatan: clearCatatan ? null : (catatan ?? this.catatan),
    );
  }
}
