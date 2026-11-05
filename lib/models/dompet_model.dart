import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

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
  final DateTime? createdAt;

  DompetItem({
    required this.id,
    required this.jenis,
    required this.nama,
    required this.jumlah,
    this.catatan,
    this.createdAt,
  });

  /// Dompet awal default (Rp 0) untuk pengguna baru.
  factory DompetItem.initialWallet() {
    return DompetItem(
      id: AppConstants.defaultNewWalletId,
      jenis: JenisDompet.cash,
      nama: AppConstants.defaultNewWalletName,
      jumlah: AppConstants.defaultNewWalletBalance,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jenis': jenis.name,
      'nama': nama,
      'jumlah': jumlah,
      'catatan': catatan,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
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

    final rawCreatedAt = map['createdAt'];
    DateTime? parsedCreatedAt;
    if (rawCreatedAt is Timestamp) {
      parsedCreatedAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt);
    }

    return DompetItem(
      id: docId ?? (map['id'] as String?) ?? '',
      jenis: parsedJenis,
      nama: (map['nama'] as String?) ?? 'Dompet',
      jumlah: (map['jumlah'] as num?)?.toDouble() ?? 0.0,
      catatan: map['catatan'] as String?,
      createdAt: parsedCreatedAt,
    );
  }

  DompetItem copyWith({
    String? id,
    JenisDompet? jenis,
    String? nama,
    double? jumlah,
    String? catatan,
    bool clearCatatan = false,
    DateTime? createdAt,
  }) {
    return DompetItem(
      id: id ?? this.id,
      jenis: jenis ?? this.jenis,
      nama: nama ?? this.nama,
      jumlah: jumlah ?? this.jumlah,
      catatan: clearCatatan ? null : (catatan ?? this.catatan),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
