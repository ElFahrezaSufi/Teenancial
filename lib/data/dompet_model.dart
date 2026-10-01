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