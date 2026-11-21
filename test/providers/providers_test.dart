import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:teenancial/data/category_icons.dart';
import 'package:teenancial/models/belajar_model.dart';
import 'package:teenancial/models/dompet_model.dart';
import 'package:teenancial/models/recurring_model.dart';
import 'package:teenancial/models/target_model.dart';
import 'package:teenancial/models/transaction_model.dart';
import 'package:teenancial/providers/belajar_provider.dart';
import 'package:teenancial/providers/category_provider.dart';
import 'package:teenancial/providers/dompet_provider.dart';
import 'package:teenancial/providers/recurring_provider.dart';
import 'package:teenancial/providers/target_provider.dart';
import 'package:teenancial/providers/transaction_provider.dart';
import 'package:teenancial/repositories/belajar_repository.dart';
import 'package:teenancial/repositories/category_repository.dart';
import 'package:teenancial/repositories/dompet_repository.dart';
import 'package:teenancial/repositories/recurring_repository.dart';
import 'package:teenancial/repositories/target_repository.dart';
import 'package:teenancial/repositories/transaction_repository.dart';
import 'package:teenancial/services/connectivity_service.dart';
import 'package:teenancial/utils/report_calculator.dart';

class _FakeTargetRepository extends TargetRepository {
  final List<TargetItem> store = [];
  final Map<String, double> walletBalances = {};
  final List<TransactionModel> createdTransactions = [];

  @override
  Future<List<TargetItem>> getTargets(String uid) async {
    final copy = List<TargetItem>.from(store);
    copy.sort((a, b) {
      if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return copy;
  }

  @override
  Future<TargetItem> createTarget({
    required String uid,
    required String nama,
    required double targetAmount,
    required File imageFile,
    bool isPinned = false,
    DateTime? deadline,
  }) async {
    final item = TargetItem(
      id: 'tg_${store.length + 1}',
      nama: nama,
      targetAmount: targetAmount,
      savedAmount: 0,
      imageUrl: 'https://example.com/${imageFile.path}',
      isPinned: isPinned,
      deadline: deadline,
    );
    store.add(item);
    return item;
  }

  @override
  Future<void> updateTarget({
    required String uid,
    required String targetId,
    required String nama,
    required double targetAmount,
    File? newImageFile,
    DateTime? deadline,
    bool clearDeadline = false,
  }) async {
    final index = store.indexWhere((t) => t.id == targetId);
    if (index != -1) {
      store[index] = store[index].copyWith(
        nama: nama,
        targetAmount: targetAmount,
        imageUrl: newImageFile != null
            ? 'https://example.com/${newImageFile.path}'
            : store[index].imageUrl,
        deadline: deadline,
        clearDeadline: clearDeadline,
      );
    }
  }

  @override
  Future<void> updateSavedAmount({
    required String uid,
    required String targetId,
    required double savedAmount,
  }) async {
    final index = store.indexWhere((t) => t.id == targetId);
    if (index != -1) {
      store[index] = store[index].copyWith(savedAmount: savedAmount);
    }
  }

  @override
  Future<void> markSettled({
    required String uid,
    required String targetId,
    required bool isSettled,
  }) async {
    final index = store.indexWhere((t) => t.id == targetId);
    if (index != -1) {
      store[index] = store[index].copyWith(
        isSettled: isSettled,
        isPinned: isSettled ? false : store[index].isPinned,
      );
    }
  }

  @override
  Future<TransactionModel> allocateFundsWithWallet({
    required String uid,
    required String targetId,
    required String walletId,
    required double amountDelta,
    double? maxWithdrawable,
  }) async {
    final index = store.indexWhere((t) => t.id == targetId);
    if (index == -1) throw Exception('Target menabung tidak ditemukan.');
    if (!walletBalances.containsKey(walletId)) {
      throw Exception('Dompet tidak ditemukan.');
    }
    final target = store[index];
    if (target.isSettled) throw Exception('Target ini sudah diselesaikan.');
    final currentWalletBalance = walletBalances[walletId]!;
    final bool isDeposit = amountDelta > 0;
    final double absAmount = amountDelta.abs();

    late final double newSaved;
    late final double newWalletBalance;
    if (isDeposit) {
      final remaining =
          (target.targetAmount - target.savedAmount).clamp(0.0, double.infinity);
      if (absAmount > remaining + 0.0001) {
        throw Exception('Nominal melebihi sisa target yang dibutuhkan.');
      }
      if (currentWalletBalance + 0.0001 < absAmount) {
        throw Exception('Saldo dompet tidak mencukupi.');
      }
      newSaved = (target.savedAmount + absAmount).clamp(0.0, target.targetAmount);
      newWalletBalance = currentWalletBalance - absAmount;
    } else {
      final allowed = maxWithdrawable != null
          ? (maxWithdrawable < target.savedAmount
              ? maxWithdrawable
              : target.savedAmount)
          : target.savedAmount;
      if (absAmount > allowed + 0.0001) {
        throw Exception(
          'Nominal penarikan melebihi dana yang dapat ditarik dari target ini.',
        );
      }
      newSaved = (target.savedAmount - absAmount).clamp(0.0, target.targetAmount);
      newWalletBalance = currentWalletBalance + absAmount;
    }

    final tx = TransactionModel(
      id: 'tx_tg_${createdTransactions.length + 1}',
      title: isDeposit
          ? 'Tabungan: ${target.nama}'
          : 'Tarik Tabungan: ${target.nama}',
      amount: absAmount,
      date: DateTime(2026, 11, 19),
      notes: isDeposit
          ? 'Alokasi ke target menabung'
          : 'Penarikan dari target menabung',
      categoryId: isDeposit ? 'c6' : 'c19',
      type: isDeposit ? TransactionType.expense : TransactionType.income,
      dompetId: walletId,
      isAdjustment: true,
      targetId: target.id,
    );
    store[index] = target.copyWith(savedAmount: newSaved);
    walletBalances[walletId] = newWalletBalance;
    createdTransactions.add(tx);
    return tx;
  }

  @override
  Future<TransactionModel> settleTargetWithExpense({
    required String uid,
    required String targetId,
    required String walletId,
    String categoryId = 'c6',
  }) async {
    final index = store.indexWhere((t) => t.id == targetId);
    if (index == -1) throw Exception('Target menabung tidak ditemukan.');
    final target = store[index];
    if (target.isSettled) {
      throw Exception('Target ini sudah diselesaikan sebelumnya.');
    }
    if (!target.isAchieved || target.savedAmount <= 0) {
      throw Exception('Target belum mencapai 100% untuk diselesaikan.');
    }
    final tx = TransactionModel(
      id: 'tx_settle_${createdTransactions.length + 1}',
      title: target.nama,
      amount: target.savedAmount,
      date: DateTime(2026, 11, 19),
      notes: 'Pembelian dari dana target menabung',
      categoryId: categoryId.trim().isNotEmpty ? categoryId.trim() : 'c6',
      type: TransactionType.expense,
      dompetId: walletId,
      targetId: target.id,
      skipWalletEffect: true,
    );
    store[index] = target.copyWith(isSettled: true, isPinned: false);
    createdTransactions.add(tx);
    return tx;
  }

  @override
  Future<void> togglePinTarget({
    required String uid,
    required String targetId,
    required bool shouldPin,
  }) async {
    for (int i = 0; i < store.length; i++) {
      final desired = shouldPin && store[i].id == targetId;
      store[i] = store[i].copyWith(isPinned: desired);
    }
  }

  @override
  Future<void> deleteTarget(String uid, String targetId) async {
    store.removeWhere((t) => t.id == targetId);
  }
}

class _FakeBelajarRepository extends BelajarRepository {
  BelajarProgressModel saved = const BelajarProgressModel();

  // Minimal in-memory catalog: 2 levels, 2 modules each.
  static final List<LevelData> _levels = [
    const LevelData(
      id: 'level_1',
      tingkat: 'Dasar',
      subtitle: 'Level dasar',
      order: 0,
      modules: [],
    ),
    const LevelData(
      id: 'level_2',
      tingkat: 'Sedang',
      subtitle: 'Level sedang',
      order: 1,
      modules: [],
    ),
  ];

  static final List<ModuleData> _modules = [
    const ModuleData(
      id: 'mod_1_1',
      levelId: 'level_1',
      order: 0,
      title: 'Modul 1.1',
      description: 'Deskripsi 1.1',
      quiz: QuizData(label: 'Kuis 1.1'),
    ),
    const ModuleData(
      id: 'mod_1_2',
      levelId: 'level_1',
      order: 1,
      title: 'Modul 1.2',
      description: 'Deskripsi 1.2',
      quiz: QuizData(label: 'Kuis 1.2'),
    ),
    const ModuleData(
      id: 'mod_2_1',
      levelId: 'level_2',
      order: 0,
      title: 'Modul 2.1',
      description: 'Deskripsi 2.1',
      quiz: QuizData(label: 'Kuis 2.1'),
    ),
    const ModuleData(
      id: 'mod_2_2',
      levelId: 'level_2',
      order: 1,
      title: 'Modul 2.2',
      description: 'Deskripsi 2.2',
      quiz: QuizData(label: 'Kuis 2.2'),
    ),
  ];

  @override
  Future<BelajarProgressModel> getProgress(String uid) async => saved;

  @override
  Future<void> saveProgress(String uid, BelajarProgressModel progress) async {
    saved = progress;
  }

  @override
  Future<List<LevelData>> getLevels() async => _levels;

  @override
  Future<List<ModuleData>> getAllModules() async => _modules;
}

void main() {
  group('TargetProvider (Alokasi Dana Model B)', () {
    late _FakeTargetRepository fakeRepo;
    late TargetProvider provider;

    setUp(() async {
      fakeRepo = _FakeTargetRepository();
      fakeRepo.store.add(
        TargetItem(
          id: 'tg_1',
          nama: 'Headphone',
          targetAmount: 300000,
          savedAmount: 50000,
          imageUrl: 'https://example.com/hp.jpg',
        ),
      );
      provider = TargetProvider(repository: fakeRepo);
      provider.updateUser('user_1');
      await Future<void>.delayed(Duration.zero);
    });

    test(
        'availableToAllocate mengikuti saldo dompet karena dana target sudah dipindahkan',
        () {
      expect(provider.totalAllocated, 50000);
      expect(provider.availableToAllocate(200000), 200000);
      expect(provider.availableToAllocate(-5000), 0);
    });

    test('allocateTargetFunds menambah dan menarik alokasi sesuai batas target',
        () async {
      await provider.allocateTargetFunds(
        targetId: 'tg_1',
        amountDelta: 100000,
      );
      expect(provider.items.first.savedAmount, 150000);

      await provider.allocateTargetFunds(
        targetId: 'tg_1',
        amountDelta: -50000,
      );
      expect(provider.items.first.savedAmount, 100000);
    });

    test('allocateTargetFunds menolak alokasi yang melebihi sisa target',
        () async {
      await expectLater(
        () => provider.allocateTargetFunds(
          targetId: 'tg_1',
          amountDelta: 400000,
        ),
        throwsException,
      );
    });

    test('settleTarget menandai selesai dan menolak alokasi berikutnya',
        () async {
      await provider.settleTarget('tg_1');
      expect(provider.items.first.isSettled, isTrue);
      expect(provider.totalAllocated, 0);

      await expectLater(
        () => provider.allocateTargetFunds(
          targetId: 'tg_1',
          amountDelta: 10000,
        ),
        throwsException,
      );
    });

    test(
        'target pertama otomatis di-pin dan pin tidak bisa dimatikan sendiri melainkan hanya berpindah ke target lain',
        () async {
      // Target pertama di setUp ('tg_1') otomatis di-pin saat loadTargets
      expect(provider.items.first.isPinned, isTrue);
      expect(provider.pinnedItem?.id, 'tg_1');

      // Menekan togglePin pada target yang sudah ter-pin tidak mematikan pin
      await provider.togglePin(provider.items.first);
      expect(provider.items.first.isPinned, isTrue);

      // Membuat target kedua tidak menggeser pin dari target pertama
      await provider.createTarget(
        nama: 'Sepeda',
        targetAmount: 1500000,
        imageFile: File('sepeda.jpg'),
      );
      expect(provider.pinnedItem?.id, 'tg_1');

      // Memindahkan pin ke target kedua
      final secondTarget = provider.items.firstWhere((t) => t.id == 'tg_2');
      await provider.togglePin(secondTarget);
      expect(provider.pinnedItem?.id, 'tg_2');

      // Menghapus target yang sedang di-pin ('tg_2') otomatis memindahkan pin ke 'tg_1'
      await provider.deleteTarget('tg_2');
      expect(provider.pinnedItem?.id, 'tg_1');
      expect(provider.items.first.isPinned, isTrue);
    });

    test(
        'updateTarget memperbarui nama, nominal, dan tenggat serta menolak nominal di bawah dana terkumpul',
        () async {
      final deadline = DateTime(2026, 12, 31);
      await provider.updateTarget(
        targetId: 'tg_1',
        nama: 'Headphone Pro',
        targetAmount: 450000,
        deadline: deadline,
      );

      final updated = provider.items.first;
      expect(updated.nama, 'Headphone Pro');
      expect(updated.targetAmount, 450000);
      expect(updated.savedAmount, 50000);
      expect(updated.deadline, deadline);

      // Menolak nominal target di bawah savedAmount (Rp 50.000)
      await expectLater(
        () => provider.updateTarget(
          targetId: 'tg_1',
          nama: 'Headphone Murah',
          targetAmount: 40000,
        ),
        throwsException,
      );

      // Menghapus tenggat dengan clearDeadline: true
      await provider.updateTarget(
        targetId: 'tg_1',
        nama: 'Headphone Pro',
        targetAmount: 450000,
        clearDeadline: true,
      );
      expect(provider.items.first.deadline, isNull);
    });

    test(
      'allocateTargetFunds atomik dengan walletId memotong/mengembalikan saldo dompet dan menghormati batas penarikan dana lama',
      () async {
        fakeRepo.walletBalances['w1'] = 200000;

        // Menabung Rp 150.000 dari dompet w1 (saldo awal 200k -> 50k, saved 50k -> 200k)
        await provider.allocateTargetFunds(
          targetId: 'tg_1',
          amountDelta: 150000,
          walletId: 'w1',
        );
        expect(provider.items.first.savedAmount, 200000);
        expect(fakeRepo.walletBalances['w1'], 50000);
        expect(fakeRepo.createdTransactions.length, 1);
        expect(fakeRepo.createdTransactions.last.isAdjustment, isTrue);
        expect(fakeRepo.createdTransactions.last.targetId, 'tg_1');
        expect(fakeRepo.createdTransactions.last.type, TransactionType.expense);

        // Menabung melebihi saldo dompet (minta 100k padahal saldo 50k) gagal tanpa mengubah state
        await expectLater(
          () => provider.allocateTargetFunds(
            targetId: 'tg_1',
            amountDelta: 100000,
            walletId: 'w1',
          ),
          throwsException,
        );
        expect(provider.items.first.savedAmount, 200000);
        expect(fakeRepo.walletBalances['w1'], 50000);
        expect(fakeRepo.createdTransactions.length, 1);

        // Kasus campuran (50k legacy + 150k dari dompet): batas tarik hanya 150k
        await expectLater(
          () => provider.allocateTargetFunds(
            targetId: 'tg_1',
            amountDelta: -160000,
            walletId: 'w1',
            maxWithdrawable: 150000,
          ),
          throwsException,
        );
        await provider.allocateTargetFunds(
          targetId: 'tg_1',
          amountDelta: -100000,
          walletId: 'w1',
          maxWithdrawable: 150000,
        );
        expect(provider.items.first.savedAmount, 100000);
        expect(fakeRepo.walletBalances['w1'], 150000);
        expect(fakeRepo.createdTransactions.last.type, TransactionType.income);
        expect(fakeRepo.createdTransactions.last.isAdjustment, isTrue);
      },
    );

    test(
      'settleTarget atomik dengan walletId menolak <100%, memindahkan pin ke target aktif lain, dan mengunci edit/pin target selesai',
      () async {
        fakeRepo.walletBalances['w1'] = 500000;
        await provider.createTarget(
          nama: 'Keyboard',
          targetAmount: 400000,
          imageFile: File('kb.jpg'),
        );

        // Belum 100% -> tolak penyelesaian atomik
        await expectLater(
          () => provider.settleTarget('tg_1', walletId: 'w1'),
          throwsException,
        );

        // Penuhi target tg_1 hingga 100% (50k + 250k = 300k)
        await provider.allocateTargetFunds(
          targetId: 'tg_1',
          amountDelta: 250000,
          walletId: 'w1',
        );
        expect(fakeRepo.walletBalances['w1'], 250000);

        // Selesaikan tg_1 dengan kategori Belanja ('c23'): saldo dompet tidak terpotong lagi,
        // transaksi skipWalletEffect tercatat sesuai kategori, dan pin pindah ke 'tg_2'
        await provider.settleTarget('tg_1', walletId: 'w1', categoryId: 'c23');
        expect(fakeRepo.walletBalances['w1'], 250000);
        final settleTx = fakeRepo.createdTransactions.last;
        expect(settleTx.skipWalletEffect, isTrue);
        expect(settleTx.isAdjustment, isFalse);
        expect(settleTx.type, TransactionType.expense);
        expect(settleTx.categoryId, 'c23');
        expect(settleTx.amount, 300000);
        expect(settleTx.targetId, 'tg_1');

        final settled = provider.items.firstWhere((t) => t.id == 'tg_1');
        expect(settled.isSettled, isTrue);
        expect(settled.isPinned, isFalse);
        expect(provider.pinnedItem?.id, 'tg_2');
        expect(provider.items.first.id, 'tg_2');

        // Target selesai tidak bisa diselesaikan ulang, diubah, atau di-pin
        await expectLater(
          () => provider.settleTarget('tg_1', walletId: 'w1'),
          throwsException,
        );
        await expectLater(
          () => provider.updateTarget(
            targetId: 'tg_1',
            nama: 'Diubah',
            targetAmount: 350000,
          ),
          throwsException,
        );
        await provider.togglePin(settled);
        expect(provider.pinnedItem?.id, 'tg_2');
      },
    );

    test(
      'deleteTarget memblokir penghapusan target aktif yang masih menyimpan dana dompet dan mengizinkan bila aman',
      () async {
        // tg_1 punya savedAmount 50k dan belum settled -> diblokir
        await expectLater(
          () => provider.deleteTarget('tg_1'),
          throwsException,
        );
        await expectLater(
          () => provider.deleteTarget('tg_1', walletBackedAmount: 50000),
          throwsException,
        );

        // Target dengan dana legacy murni (walletBackedAmount: 0) boleh dihapus
        await provider.deleteTarget('tg_1', walletBackedAmount: 0);
        expect(provider.items, isEmpty);

        // Target selesai (isSettled: true) juga boleh dihapus meski savedAmount > 0
        fakeRepo.store.add(
          TargetItem(
            id: 'tg_done',
            nama: 'Kamera',
            targetAmount: 500000,
            savedAmount: 500000,
            imageUrl: 'https://example.com/cam.jpg',
            isSettled: true,
          ),
        );
        await provider.loadTargets(silent: true);
        expect(provider.items.first.isPinned, isFalse);
        await provider.deleteTarget('tg_done');
        expect(provider.items, isEmpty);
      },
    );
  });

  group('TransactionModel alokasi target menabung', () {
    TransactionModel buildTx({
      required bool isAdjustment,
      required bool skipWalletEffect,
    }) {
      return TransactionModel(
        id: 'tx',
        title: 'Tabungan: laptop',
        amount: 200000,
        date: DateTime(2026, 1, 1),
        categoryId: 'c6',
        type: TransactionType.expense,
        dompetId: 'd1',
        isAdjustment: isAdjustment,
        targetId: 'tg_1',
        skipWalletEffect: skipWalletEffect,
      );
    }

    test('alokasi tabungan memotong dompet tetapi tidak dihitung pengeluaran',
        () {
      final tx = buildTx(isAdjustment: true, skipWalletEffect: false);

      expect(tx.walletEffects()['d1'], -200000);
      expect(tx.isBalanceAdjustment, isTrue);
      expect(ReportCalculator.isReportExpense(tx), isFalse);
      expect(ReportCalculator.isReportIncome(tx), isFalse);
      expect(tx.isEditable, isFalse);
    });

    test(
        'penyelesaian target dicatat sebagai pengeluaran tanpa memotong dompet',
        () {
      final tx = buildTx(isAdjustment: false, skipWalletEffect: true);

      expect(tx.walletEffects(), isEmpty);
      expect(tx.balanceEvents(), isEmpty);
      expect(ReportCalculator.isReportExpense(tx), isTrue);
    });
  });

  group('BelajarProvider (Immutable State & Lock Progression)', () {
    late _FakeBelajarRepository fakeRepo;
    late BelajarProvider provider;

    setUp(() async {
      fakeRepo = _FakeBelajarRepository();
      provider = BelajarProvider(repository: fakeRepo);
      provider.updateUser('user_1');
      await Future<void>.delayed(Duration.zero);
    });

    test(
        'modul pertama terbuka secara default dan modul kedua terkunci sampai modul+kuis pertama selesai',
        () async {
      expect(provider.levels[0].modules[0].status, ModuleStatus.available);
      expect(provider.levels[0].modules[1].status, ModuleStatus.locked);

      await provider.completeModule(0, 0);
      expect(provider.levels[0].modules[0].status, ModuleStatus.completed);
      expect(provider.levels[0].modules[0].quiz.status, ModuleStatus.available);
      expect(provider.levels[0].modules[1].status, ModuleStatus.locked);

      await provider.completeQuiz(0, 0);
      expect(provider.levels[0].modules[0].quiz.status, ModuleStatus.completed);
      expect(provider.levels[0].modules[1].status, ModuleStatus.available);
    });

    test('toggleExpand hanya membuka modul yang tidak terkunci', () {
      provider.toggleExpand(0, 0);
      expect(provider.levels[0].modules[0].isExpanded, isTrue);

      provider.toggleExpand(0, 1);
      expect(provider.levels[0].modules[1].isExpanded, isFalse);
    });

    test('kuis yang sudah selesai tetap dapat dikerjakan ulang', () async {
      await provider.completeModule(0, 0);
      await provider.completeQuiz(0, 0);

      final result = await provider.completeQuiz(0, 0, scorePercent: 100);

      expect(result, isTrue);
      expect(provider.levels[0].modules[0].status, ModuleStatus.completed);
      expect(
        provider.levels[0].modules[0].quiz.status,
        ModuleStatus.completed,
      );
    });

    test('updateUser(null) mereset daftar level dan progres saat logout',
        () async {
      expect(provider.levels, isNotEmpty);

      provider.updateUser(null);
      await Future<void>.delayed(Duration.zero);

      expect(provider.levels, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.currentModule, isNull);
    });
  });

  group('CategoryProvider & CategoryRepository Validation', () {
    late _FakeCategoryRepository fakeCategoryRepo;
    late CategoryProvider categoryProvider;

    setUp(() async {
      fakeCategoryRepo = _FakeCategoryRepository();
      categoryProvider = CategoryProvider(repository: fakeCategoryRepo);
      categoryProvider.updateUser('user_1');
      await Future<void>.delayed(Duration.zero);
    });

    test(
        'tambah, ubah, dan hapus kategori kustom pada berbagai jenis transaksi',
        () async {
      final created = await categoryProvider.addCategory(
        name: 'Kopi Kampus',
        type: TransactionType.expense,
        iconKey: 'drink',
        colorValue: 0xFFE18151,
      );

      expect(created.name, 'Kopi Kampus');
      expect(created.isCustom, isTrue);

      final expenseCats =
          categoryProvider.categoriesFor(TransactionType.expense);
      expect(expenseCats.last.id, 'c6'); // "Lainnya" tetap di paling bawah
      expect(expenseCats[expenseCats.length - 2].id, created.id);
      expect(categoryProvider.resolve(created.id).name, 'Kopi Kampus');

      // Mendukung jenis transaksi lain (Opsi A: Transfer / Pinjaman)
      final customTransfer = await categoryProvider.addCategory(
        name: 'Arisan Kelas',
        type: TransactionType.transfer,
        iconKey: 'send',
        colorValue: 0xFF2E7D6B,
      );
      expect(
        categoryProvider.resolve(customTransfer.id).name,
        'Arisan Kelas',
      );

      // Update nama & warna
      await categoryProvider.updateCategory(
        categoryId: created.id,
        name: 'Nongkrong & Kopi',
        type: TransactionType.expense,
        iconKey: 'food',
        colorValue: 0xFF5C6BC0,
      );
      expect(categoryProvider.resolve(created.id).name, 'Nongkrong & Kopi');

      // Hapus kategori kustom -> resolve jatuh ke "Lainnya" (c6)
      fakeCategoryRepo.mockUsageCount[created.id] = 3;
      final reassigned = await categoryProvider.deleteCategory(
        categoryId: created.id,
        type: TransactionType.expense,
      );
      expect(reassigned, 3);
      expect(
        categoryProvider
            .resolve(created.id, fallbackType: TransactionType.expense)
            .id,
        'c6',
      );
    });

    test(
        'validasi menolak nama kosong, terlalu panjang, atau duplikat bawaan/kustom',
        () async {
      // Duplikat nama kategori bawaan (case-insensitive)
      await expectLater(
        () => categoryProvider.addCategory(
          name: 'makanan',
          type: TransactionType.expense,
          iconKey: 'food',
          colorValue: 0xFFE18151,
        ),
        throwsException,
      );

      // Nama lebih dari 20 karakter
      await expectLater(
        () => categoryProvider.addCategory(
          name: 'Kategori Sangat Panjang Sekali',
          type: TransactionType.expense,
          iconKey: 'food',
          colorValue: 0xFFE18151,
        ),
        throwsException,
      );

      await categoryProvider.addCategory(
        name: 'Skincare',
        type: TransactionType.expense,
        iconKey: 'shopping',
        colorValue: 0xFFEC407A,
      );

      // Duplikat nama kategori kustom pada jenis yang sama
      await expectLater(
        () => categoryProvider.addCategory(
          name: 'SKINCARE',
          type: TransactionType.expense,
          iconKey: 'shopping',
          colorValue: 0xFFEC407A,
        ),
        throwsException,
      );
    });
  });

  group('RecurringProvider Catch-Up & Lifecycle', () {
    late _FakeRecurringRepository fakeRecRepo;
    late RecurringProvider recProvider;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      fakeRecRepo = _FakeRecurringRepository();
      recProvider = RecurringProvider(repository: fakeRecRepo);
      recProvider.bindDependencies(
        'user_1',
        DompetProvider(repository: _NoopDompetRepository()),
        TransactionProvider(repository: _NoopTransactionRepository()),
      );
      await Future<void>.delayed(Duration.zero);
    });

    tearDown(() {
      recProvider.dispose();
    });

    test(
        'menjalankan catch-up otomatis saat login dan mengelola jadwal aktif/dijeda',
        () async {
      expect(fakeRecRepo.processDueCalls, 1);

      final item = RecurringModel(
        id: '',
        title: 'Langganan Musik',
        amount: 55000,
        categoryId: 'c16',
        type: TransactionType.expense,
        dompetId: 'w1',
        frequency: RecurrenceFrequency.monthly,
        intervalCount: 1,
        startDate: DateTime(2026, 11, 1),
        nextRunDate: DateTime(2026, 12, 1),
      );

      final added = await recProvider.addRecurring(item);
      expect(recProvider.activeItems.length, 1);
      expect(recProvider.inactiveItems, isEmpty);

      await recProvider.toggleActive(added.id, false);
      expect(recProvider.activeItems, isEmpty);
      expect(recProvider.inactiveItems.length, 1);

      await recProvider.deleteRecurring(added.id);
      expect(recProvider.items, isEmpty);
    });

    test(
      'saat offline runCatchUpAndLoad melewati processDue tanpa error dan tetap memuat templat dari cache',
      () async {
        fakeRecRepo.store.add(
          RecurringModel(
            id: 'rec_cached',
            title: 'Uang Saku Mingguan',
            amount: 100000,
            categoryId: 'c1',
            type: TransactionType.income,
            dompetId: 'd1',
            frequency: RecurrenceFrequency.weekly,
            intervalCount: 1,
            startDate: DateTime(2026, 11, 1),
            nextRunDate: DateTime(2026, 11, 8),
          ),
        );

        final callsBefore = fakeRecRepo.processDueCalls;
        ConnectivityService.instance.setTestState(isOffline: true);
        addTearDown(() => ConnectivityService.instance.resetForTesting());

        await recProvider.runCatchUpAndLoad(silent: true);

        expect(fakeRecRepo.processDueCalls, callsBefore);
        expect(recProvider.errorMessage, isNull);
        expect(recProvider.items.length, 1);
        expect(recProvider.items.first.id, 'rec_cached');
      },
    );
  });

  group('Offline Rollback BelajarProvider & Initial Wallet Balance DompetProvider',
      () {
    test(
      'completeModule dan completeQuiz melakukan rollback state dan melempar ulang OfflineException saat gagal simpan',
      () async {
        final failingRepo = _FailingSaveBelajarRepository();
        final belajarProvider = BelajarProvider(repository: failingRepo);
        belajarProvider.updateUser('user_1');
        await Future<void>.delayed(Duration.zero);

        expect(
          belajarProvider.levels.first.modules.first.status,
          ModuleStatus.available,
        );

        await expectLater(
          () => belajarProvider.completeModule(0, 0),
          throwsA(isA<OfflineException>()),
        );
        expect(
          belajarProvider.levels.first.modules.first.status,
          ModuleStatus.available,
        );
        expect(belajarProvider.isRecentlyLearned, isFalse);

        // Jika modul sudah selesai, lalu kuis gagal simpan karena offline -> kuis tetap available
        failingRepo.shouldFailSave = false;
        await belajarProvider.completeModule(0, 0);
        expect(
          belajarProvider.levels.first.modules.first.status,
          ModuleStatus.completed,
        );
        expect(
          belajarProvider.levels.first.modules.first.quiz.status,
          ModuleStatus.available,
        );

        failingRepo.shouldFailSave = true;
        await expectLater(
          () => belajarProvider.completeQuiz(0, 0, scorePercent: 100),
          throwsA(isA<OfflineException>()),
        );
        expect(
          belajarProvider.levels.first.modules.first.quiz.status,
          ModuleStatus.available,
        );
      },
    );

    test(
      'DompetProvider.setInitialWalletBalance memperbarui saldo awal d1 tanpa membuat transaksi penyesuaian',
      () async {
        final fakeDompetRepo = _InitialBalanceDompetRepository();
        final dompetProvider = DompetProvider(repository: fakeDompetRepo);
        dompetProvider.updateUser('user_1');
        await Future<void>.delayed(Duration.zero);

        expect(dompetProvider.totalSaldo, 0);
        await dompetProvider.setInitialWalletBalance('d1', 150000);
        expect(dompetProvider.totalSaldo, 150000);
        expect(fakeDompetRepo.initialBalanceCalls, 1);
      },
    );
  });
}

class _InitialBalanceDompetRepository extends DompetRepository {
  final List<DompetItem> store = [DompetItem.initialWallet()];
  int initialBalanceCalls = 0;

  @override
  Future<List<DompetItem>> getDompets(String uid) async =>
      List<DompetItem>.from(store);

  @override
  Future<void> setInitialWalletBalance(
    String uid,
    String dompetId,
    double initialBalance,
  ) async {
    initialBalanceCalls++;
    final idx = store.indexWhere((d) => d.id == dompetId);
    if (idx != -1) {
      store[idx] = store[idx].copyWith(jumlah: initialBalance);
    }
  }
}

class _FailingSaveBelajarRepository extends BelajarRepository {
  bool shouldFailSave = true;

  @override
  Future<List<LevelData>> getLevels() async => const [
        LevelData(
          id: 'lvl_1',
          order: 1,
          tingkat: 'Level 1',
          subtitle: 'Dasar Keuangan',
        ),
      ];

  @override
  Future<List<ModuleData>> getAllModules() async => const [
        ModuleData(
          id: 'mod_1',
          levelId: 'lvl_1',
          order: 1,
          title: 'Dasar Menabung',
          description: 'Pengantar',
          sections: [
            ModuleSection(heading: 'Ringkasan', body: 'Isi materi'),
          ],
          quiz: QuizData(label: 'Kuis 1', passingScore: 70, questions: []),
        ),
      ];

  @override
  Future<BelajarProgressModel> getProgress(String uid) async =>
      const BelajarProgressModel();

  @override
  Future<void> saveProgress(String uid, BelajarProgressModel progress) async {
    if (shouldFailSave) {
      throw const OfflineException(
        'Tidak ada koneksi internet. Hubungkan ke internet untuk menyimpan progres belajar.',
      );
    }
  }
}

class _NoopDompetRepository extends DompetRepository {
  @override
  Future<List<DompetItem>> getDompets(String uid) async => const [];
}

class _NoopTransactionRepository extends TransactionRepository {
  @override
  Future<List<TransactionModel>> getTransactions(String uid) async => const [];
}

class _FakeRecurringRepository extends RecurringRepository {
  final List<RecurringModel> store = [];
  int processDueCalls = 0;

  @override
  Future<List<RecurringModel>> getRecurringTemplates(String uid) async {
    return List<RecurringModel>.from(store);
  }

  @override
  Future<RecurringCatchUpResult> processDue(
    String uid, {
    DateTime? now,
  }) async {
    processDueCalls++;
    return const RecurringCatchUpResult();
  }

  @override
  Future<RecurringModel> addRecurring(String uid, RecurringModel item) async {
    RecurringRepository.validateTemplate(item);
    final saved = item.copyWith(id: 'rec_${store.length + 1}');
    store.add(saved);
    return saved;
  }

  @override
  Future<RecurringModel> updateRecurring(
    String uid,
    RecurringModel item,
  ) async {
    RecurringRepository.validateTemplate(item);
    final idx = store.indexWhere((r) => r.id == item.id);
    if (idx != -1) store[idx] = item;
    return item;
  }

  @override
  Future<void> toggleActive(String uid, String id, bool isActive) async {
    final idx = store.indexWhere((r) => r.id == id);
    if (idx != -1) {
      store[idx] = store[idx].copyWith(isActive: isActive);
    }
  }

  @override
  Future<void> deleteRecurring(String uid, String id) async {
    store.removeWhere((r) => r.id == id);
  }
}

class _FakeCategoryRepository extends CategoryRepository {
  final List<CategoryModel> store = [];
  final Map<String, int> mockUsageCount = {};

  @override
  Future<List<CategoryModel>> getCategories(String uid) async {
    return List<CategoryModel>.from(store);
  }

  @override
  Future<CategoryModel> addCategory({
    required String uid,
    required String name,
    required TransactionType type,
    required String iconKey,
    required int colorValue,
  }) async {
    final validatedName = CategoryRepository.validateCategoryName(
      name: name,
      type: type,
      existingCustom: store,
    );
    final created = CategoryModel(
      id: 'cat_${store.length + 1}',
      name: validatedName,
      type: type,
      icon: CategoryIcons.iconForKey(iconKey),
      iconKey: iconKey,
      colorValue: colorValue,
      isCustom: true,
      createdAt: DateTime(2026, 11, 14),
    );
    store.add(created);
    return created;
  }

  @override
  Future<CategoryModel> updateCategory({
    required String uid,
    required String categoryId,
    required String name,
    required TransactionType type,
    required String iconKey,
    required int colorValue,
  }) async {
    final idx = store.indexWhere((c) => c.id == categoryId);
    if (idx == -1) throw Exception('Kategori tidak ditemukan');
    final validatedName = CategoryRepository.validateCategoryName(
      name: name,
      type: type,
      existingCustom: store,
      editingCategoryId: categoryId,
    );
    final updated = store[idx].copyWith(
      name: validatedName,
      type: type,
      iconKey: iconKey,
      colorValue: colorValue,
    );
    store[idx] = updated;
    return updated;
  }

  @override
  Future<int> countUsages(String uid, String categoryId) async {
    return mockUsageCount[categoryId] ?? 0;
  }

  @override
  Future<int> deleteCategory({
    required String uid,
    required String categoryId,
    required TransactionType type,
  }) async {
    store.removeWhere((c) => c.id == categoryId);
    return mockUsageCount[categoryId] ?? 0;
  }
}
