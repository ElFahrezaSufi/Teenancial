import 'package:flutter_test/flutter_test.dart';
import 'package:teenancial/data/pinjaman_model.dart';
import 'package:teenancial/data/sim_settings.dart';
import 'package:teenancial/data/transaction_model.dart';
import 'package:teenancial/repositories/dompet_repository.dart';
import 'package:teenancial/repositories/pinjaman_repository.dart';
import 'package:teenancial/repositories/transaction_repository.dart';

TransactionModel _trx(String id) => TransactionModel(
      id: id,
      title: 'Uji $id',
      amount: 1000,
      date: DateTime.now(),
      categoryId: 'c3',
      type: TransactionType.expense,
      isDigital: false,
    );

void main() {
  tearDown(() => SimSettings.forceError.value = false);

  group('Transaksi (CRUD + relasi ID)', () {
    test('minimal 20 record utama dan 5 kategori', () async {
      final repo = TransactionRepository.instance;
      final data = await repo.getTransactions();
      expect(data.length, greaterThanOrEqualTo(20));
      expect(repo.categories.length, greaterThanOrEqualTo(5));
    });

    test('setiap categoryId menunjuk kategori yang ada', () async {
      final repo = TransactionRepository.instance;
      final ids = repo.categories.map((c) => c.id).toSet();
      final data = await repo.getTransactions();
      for (final t in data) {
        expect(ids.contains(t.categoryId), isTrue, reason: t.id);
      }
    });

    test('tambah lalu hapus transaksi', () async {
      final repo = TransactionRepository.instance;
      await repo.addTransaction(_trx('uji-1'));
      expect((await repo.getTransactions()).any((t) => t.id == 'uji-1'), isTrue);
      await repo.deleteTransaction('uji-1');
      expect((await repo.getTransactions()).any((t) => t.id == 'uji-1'), isFalse);
    });

    test('edit transaksi mengubah data', () async {
      final repo = TransactionRepository.instance;
      await repo.addTransaction(_trx('uji-2'));
      await repo.updateTransaction(_trx('uji-2').copyWith(title: 'Diubah'));
      final t = await repo.getTransactionById('uji-2');
      expect(t.title, 'Diubah');
      await repo.deleteTransaction('uji-2');
    });

    test('ID tidak ada -> exception', () async {
      final repo = TransactionRepository.instance;
      await expectLater(() => repo.getTransactionById('tidak-ada'), throwsException);
      await expectLater(() => repo.updateTransaction(_trx('tidak-ada')), throwsException);
    });

    test('simulasi gagal memuat -> exception', () async {
      SimSettings.forceError.value = true;
      await expectLater(() => TransactionRepository.instance.getTransactions(), throwsException);
    });
  });

  group('Dompet & transfer', () {
    test('pemetaan pilihan UI ke id dompet', () {
      final repo = DompetRepository.instance;
      expect(repo.idFromSelection(0, null), 'd1');
      expect(repo.idFromSelection(1, 0), 'd2');
      expect(repo.idFromSelection(1, 3), 'd5');
      expect(repo.idFromSelection(1, null), isNull);
    });

    test('transfer antar dompet memindahkan saldo', () async {
      final repo = DompetRepository.instance;
      final before2 = repo.findById('d2')!.jumlah;
      final before3 = repo.findById('d3')!.jumlah;
      await repo.transfer(fromId: 'd2', toId: 'd3', amount: 1000);
      expect(repo.findById('d2')!.jumlah, before2 - 1000);
      expect(repo.findById('d3')!.jumlah, before3 + 1000);
    });

    test('saldo tidak cukup -> exception dan saldo tetap', () async {
      final repo = DompetRepository.instance;
      final before = repo.findById('d5')!.jumlah;
      await expectLater(() => repo.transfer(fromId: 'd5', amount: 999999999), throwsException);
      expect(repo.findById('d5')!.jumlah, before);
    });

    test('simulasi gagal memuat dompet -> exception', () async {
      SimSettings.forceError.value = true;
      await expectLater(() => DompetRepository.instance.getDompets(), throwsException);
    });
  });

  group('Pinjaman', () {
    test('tambah dan hapus pinjaman', () async {
      final repo = PinjamanRepository.instance;
      await repo.add(PinjamanItem(
        id: 'uji-p',
        jenis: JenisPinjaman.pinjaman,
        nama: 'Tes',
        jumlah: 5000,
        kategori: 'Lainnya',
        jatuhTempo: DateTime.now().add(const Duration(days: 1)),
      ));
      expect((await repo.getAll()).any((p) => p.id == 'uji-p'), isTrue);
      await repo.delete('uji-p');
      expect((await repo.getAll()).any((p) => p.id == 'uji-p'), isFalse);
    });
  });
}
