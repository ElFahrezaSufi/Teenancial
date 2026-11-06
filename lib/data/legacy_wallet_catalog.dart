import '../config/app_constants.dart';
import '../models/dompet_model.dart';

class LegacyWalletCatalog {
  LegacyWalletCatalog._();

  /// 6 dompet dummy beserta saldonya untuk di-seed satu kali ke Firestore
  /// bagi akun-akun lama (existing accounts) yang sudah terdaftar sebelumnya.
  static List<DompetItem> buildExistingUserSeedWallets() {
    return [
      DompetItem(
        id: 'd1',
        jenis: JenisDompet.cash,
        nama: 'Dompet Utama',
        jumlah: 150000,
      ),
      DompetItem(
        id: 'd2',
        jenis: JenisDompet.accounts,
        nama: 'SeaBank',
        jumlah: 500000,
      ),
      DompetItem(
        id: 'd3',
        jenis: JenisDompet.accounts,
        nama: 'Go-Pay',
        jumlah: 75000,
      ),
      DompetItem(
        id: 'd4',
        jenis: JenisDompet.accounts,
        nama: 'Dana',
        jumlah: 125000,
      ),
      DompetItem(
        id: 'd5',
        jenis: JenisDompet.accounts,
        nama: 'Ovo',
        jumlah: 20000,
      ),
      DompetItem(
        id: 'd6',
        jenis: JenisDompet.card,
        nama: 'Mandiri',
        jumlah: 1200000,
      ),
    ];
  }

  /// 1 dompet awal (Rp 0) untuk akun baru yang mendaftar mulai sekarang.
  static DompetItem buildNewUserInitialWallet() {
    return DompetItem(
      id: AppConstants.defaultNewWalletId,
      jenis: JenisDompet.cash,
      nama: AppConstants.defaultNewWalletName,
      jumlah: AppConstants.defaultNewWalletBalance,
    );
  }
}
