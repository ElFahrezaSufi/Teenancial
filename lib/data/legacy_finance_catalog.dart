import '../models/contact_model.dart';
import '../models/transaction_model.dart';

class LegacyFinanceCatalog {
  LegacyFinanceCatalog._();

  /// Kontak dummy untuk akun lama:
  /// - 'Budi' & 'Siti' berasal dari ContactRepository lama sebelum migrasi.
  /// - 'Raka' & 'Dinda' ditambahkan untuk data dummy Piutang.
  static List<ContactModel> buildExistingUserSeedContacts() {
    return const [
      ContactModel(id: 'c1', name: 'Budi'),
      ContactModel(id: 'c2', name: 'Siti'),
      ContactModel(id: 'c3', name: 'Raka'),
      ContactModel(id: 'c4', name: 'Dinda'),
    ];
  }

  /// 20 data dummy riwayat transaksi asli (t1..t20) dari kode sebelum migrasi
  /// ditambah 4 data dummy pinjaman hutang & piutang (p1..p4) khusus akun lama.
  static List<TransactionModel> buildExistingUserSeedTransactions({
    required Map<String, String> contactIdBySeedId,
    Set<String>? availableWalletIds,
  }) {
    final now = DateTime.now();

    String resolveWallet(String preferredId) {
      if (availableWalletIds == null ||
          availableWalletIds.isEmpty ||
          availableWalletIds.contains(preferredId)) {
        return preferredId;
      }
      return availableWalletIds.first;
    }

    final budiId = contactIdBySeedId['c1'] ?? 'c1';
    final sitiId = contactIdBySeedId['c2'] ?? 'c2';
    final rakaId = contactIdBySeedId['c3'] ?? 'c3';
    final dindaId = contactIdBySeedId['c4'] ?? 'c4';

    return [
      // --- 20 Riwayat Transaksi Dummy Asli (t1 - t20) ---
      // Hari ini
      TransactionModel(
        id: 't1',
        title: 'Jajan Kantin',
        amount: 25000,
        date: now.subtract(const Duration(hours: 2)),
        categoryId: 'c3',
        type: TransactionType.expense,
        dompetId: resolveWallet('d1'),
      ),
      TransactionModel(
        id: 't2',
        title: 'Uang Saku Mingguan',
        amount: 150000,
        date: now.subtract(const Duration(hours: 5)),
        categoryId: 'c1',
        type: TransactionType.income,
        dompetId: resolveWallet('d2'),
      ),
      TransactionModel(
        id: 't3',
        title: 'Beli Pulsa',
        amount: 20000,
        date: now.subtract(const Duration(hours: 10)),
        categoryId: 'c6',
        type: TransactionType.expense,
        dompetId: resolveWallet('d3'),
      ),
      // Kemarin
      TransactionModel(
        id: 't4',
        title: 'Ongkos Ojol',
        amount: 15000,
        date: now.subtract(const Duration(days: 1, hours: 1)),
        categoryId: 'c4',
        type: TransactionType.expense,
        dompetId: resolveWallet('d4'),
      ),
      TransactionModel(
        id: 't5',
        title: 'Nonton Bioskop',
        amount: 45000,
        date: now.subtract(const Duration(days: 1, hours: 6)),
        categoryId: 'c5',
        type: TransactionType.expense,
        dompetId: resolveWallet('d2'),
      ),
      TransactionModel(
        id: 't6',
        title: 'Hadiah Nenek',
        amount: 50000,
        date: now.subtract(const Duration(days: 1, hours: 10)),
        categoryId: 'c2',
        type: TransactionType.income,
        dompetId: resolveWallet('d1'),
      ),
      // 2 hari lalu
      TransactionModel(
        id: 't7',
        title: 'Makan Siang',
        amount: 20000,
        date: now.subtract(const Duration(days: 2, hours: 2)),
        categoryId: 'c3',
        type: TransactionType.expense,
        dompetId: resolveWallet('d1'),
      ),
      TransactionModel(
        id: 't8',
        title: 'Beli Buku Tulis',
        amount: 35000,
        date: now.subtract(const Duration(days: 2, hours: 4)),
        categoryId: 'c6',
        type: TransactionType.expense,
        dompetId: resolveWallet('d1'),
      ),
      // 3 hari lalu
      TransactionModel(
        id: 't9',
        title: 'Ongkos Angkot',
        amount: 5000,
        date: now.subtract(const Duration(days: 3, hours: 1)),
        categoryId: 'c4',
        type: TransactionType.expense,
        dompetId: resolveWallet('d1'),
      ),
      TransactionModel(
        id: 't10',
        title: 'Boba Drink',
        amount: 18000,
        date: now.subtract(const Duration(days: 3, hours: 5)),
        categoryId: 'c3',
        type: TransactionType.expense,
        dompetId: resolveWallet('d3'),
      ),
      TransactionModel(
        id: 't11',
        title: 'Uang Saku Tambahan',
        amount: 50000,
        date: now.subtract(const Duration(days: 3, hours: 8)),
        categoryId: 'c1',
        type: TransactionType.income,
        dompetId: resolveWallet('d1'),
      ),
      // Minggu lalu
      TransactionModel(
        id: 't12',
        title: 'Topup Game',
        amount: 60000,
        date: now.subtract(const Duration(days: 7, hours: 3)),
        categoryId: 'c5',
        type: TransactionType.expense,
        dompetId: resolveWallet('d5'),
      ),
      TransactionModel(
        id: 't13',
        title: 'Ongkos Pulang',
        amount: 15000,
        date: now.subtract(const Duration(days: 7, hours: 5)),
        categoryId: 'c4',
        type: TransactionType.expense,
        dompetId: resolveWallet('d1'),
      ),
      TransactionModel(
        id: 't14',
        title: 'Makan Bakso',
        amount: 15000,
        date: now.subtract(const Duration(days: 8, hours: 2)),
        categoryId: 'c3',
        type: TransactionType.expense,
        dompetId: resolveWallet('d1'),
      ),
      // Bulan lalu
      TransactionModel(
        id: 't15',
        title: 'Hadiah Ultah',
        amount: 200000,
        date: now.subtract(const Duration(days: 30, hours: 1)),
        categoryId: 'c2',
        type: TransactionType.income,
        dompetId: resolveWallet('d2'),
      ),
      TransactionModel(
        id: 't16',
        title: 'Beli Kuota',
        amount: 75000,
        date: now.subtract(const Duration(days: 30, hours: 4)),
        categoryId: 'c6',
        type: TransactionType.expense,
        dompetId: resolveWallet('d2'),
      ),
      TransactionModel(
        id: 't17',
        title: 'Makan Malam',
        amount: 30000,
        date: now.subtract(const Duration(days: 32, hours: 6)),
        categoryId: 'c3',
        type: TransactionType.expense,
        dompetId: resolveWallet('d3'),
      ),
      TransactionModel(
        id: 't18',
        title: 'Ongkos PP',
        amount: 30000,
        date: now.subtract(const Duration(days: 35, hours: 2)),
        categoryId: 'c4',
        type: TransactionType.expense,
        dompetId: resolveWallet('d1'),
      ),
      TransactionModel(
        id: 't19',
        title: 'Main Warnet',
        amount: 20000,
        date: now.subtract(const Duration(days: 36, hours: 3)),
        categoryId: 'c5',
        type: TransactionType.expense,
        dompetId: resolveWallet('d1'),
      ),
      TransactionModel(
        id: 't20',
        title: 'Jual Barang Bekas',
        amount: 100000,
        date: now.subtract(const Duration(days: 40, hours: 10)),
        categoryId: 'c1',
        type: TransactionType.income,
        dompetId: resolveWallet('d1'),
      ),

      // --- 4 Data Dummy Pinjaman (Hutang & Piutang) untuk Akun Lama (p1 - p4) ---
      TransactionModel(
        id: 'p1',
        title: 'Hutang dari Budi',
        amount: 35000,
        date: now.subtract(const Duration(days: 4, hours: 3)),
        notes: 'Talangan beli buku LKS koperasi',
        categoryId: 'c11',
        type: TransactionType.debt,
        dompetId: resolveWallet('d1'),
        dueDate: now.add(const Duration(days: 2)),
        contactId: budiId,
        isPaid: false,
      ),
      TransactionModel(
        id: 'p2',
        title: 'Hutang dari Siti',
        amount: 50000,
        date: now.subtract(const Duration(days: 2, hours: 6)),
        notes: 'Patungan kado ulang tahun wali kelas',
        categoryId: 'c13',
        type: TransactionType.debt,
        dompetId: resolveWallet('d3'),
        dueDate: now.add(const Duration(days: 7)),
        contactId: sitiId,
        isPaid: false,
      ),
      TransactionModel(
        id: 'p3',
        title: 'Piutang ke Raka',
        amount: 40000,
        date: now.subtract(const Duration(days: 3, hours: 4)),
        notes: 'Pinjam buat bayar sewa lapangan futsal',
        categoryId: 'c15',
        type: TransactionType.receivable,
        dompetId: resolveWallet('d2'),
        dueDate: now.add(const Duration(days: 5)),
        contactId: rakaId,
        isPaid: false,
      ),
      TransactionModel(
        id: 'p4',
        title: 'Piutang ke Dinda',
        amount: 25000,
        date: now.subtract(const Duration(days: 10, hours: 2)),
        notes: 'Titip beli makan siang di kantin',
        categoryId: 'c15',
        type: TransactionType.receivable,
        dompetId: resolveWallet('d4'),
        dueDate: now.subtract(const Duration(days: 6)),
        contactId: dindaId,
        isPaid: true,
        paidDompetId: resolveWallet('d4'),
      ),
    ];
  }
}

