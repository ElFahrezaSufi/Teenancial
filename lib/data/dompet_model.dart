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
}

class DompetData {
  DompetData._();
  static final DompetData instance = DompetData._();

  final List<DompetItem> items = [
    DompetItem(id: '1', jenis: JenisDompet.cash, nama: 'Cash', jumlah: 0),
    DompetItem(id: '2', jenis: JenisDompet.accounts, nama: 'SeaBank', jumlah: 0),
    DompetItem(id: '3', jenis: JenisDompet.accounts, nama: 'Go-Pay', jumlah: 0),
    DompetItem(id: '4', jenis: JenisDompet.accounts, nama: 'Dana', jumlah: 0),
    DompetItem(id: '5', jenis: JenisDompet.accounts, nama: 'Ovo', jumlah: 0),
    DompetItem(id: '6', jenis: JenisDompet.card, nama: 'Mandiri', jumlah: 0),
  ];

  void tambah(DompetItem item) => items.add(item);

  List<DompetItem> byJenis(JenisDompet jenis) => items.where((e) => e.jenis == jenis).toList();

  double get totalSaldo => items.fold(0, (sum, item) => sum + item.jumlah);
}