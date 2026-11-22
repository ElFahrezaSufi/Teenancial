import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

enum JenisDompet { cash, accounts, card }

extension JenisDompetLabel on JenisDompet {
  String get label {
    switch (this) {
      case JenisDompet.cash:
        return 'Tunai';
      case JenisDompet.accounts:
        return 'Rekening & E-Wallet';
      case JenisDompet.card:
        return 'Kartu';
    }
  }

  /// Urutan standar pengelompokan jenis dompet di seluruh aplikasi:
  /// Tunai -> Rekening & E-Wallet -> Kartu.
  int get sortOrder {
    switch (this) {
      case JenisDompet.cash:
        return 0;
      case JenisDompet.accounts:
        return 1;
      case JenisDompet.card:
        return 2;
    }
  }
}

class DompetItem {
  final String id;
  final JenisDompet jenis;
  final String nama;
  final double jumlah;
  final String? catatan;
  final DateTime? createdAt;

  const DompetItem({
    required this.id,
    required this.jenis,
    required this.nama,
    required this.jumlah,
    this.catatan,
    this.createdAt,
  });

  /// Comparator standar urutan dompet:
  /// 1. Jenis dompet: Tunai -> Rekening & E-Wallet -> Kartu.
  /// 2. Waktu pembuatan (`createdAt`, terlama di atas; dompet lama tanpa
  ///    `createdAt` seperti dompet awal diprioritaskan lebih dulu).
  /// 3. Fallback deterministik berdasarkan `id`.
  static int compareByTypeAndCreatedAt(DompetItem a, DompetItem b) {
    final jenisCmp = a.jenis.sortOrder.compareTo(b.jenis.sortOrder);
    if (jenisCmp != 0) return jenisCmp;

    if (a.createdAt != null && b.createdAt != null) {
      final createdCmp = a.createdAt!.compareTo(b.createdAt!);
      if (createdCmp != 0) return createdCmp;
    } else if (a.createdAt == null && b.createdAt != null) {
      return -1;
    } else if (a.createdAt != null && b.createdAt == null) {
      return 1;
    }
    return a.id.compareTo(b.id);
  }

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
