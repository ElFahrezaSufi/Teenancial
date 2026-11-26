import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:teenancial/data/feen_catalog.dart';
import 'package:teenancial/data/mission_catalog.dart';
import 'package:teenancial/models/belajar_model.dart';
import 'package:teenancial/models/dompet_model.dart';
import 'package:teenancial/models/mission_model.dart';
import 'package:teenancial/models/transaction_model.dart';
import 'package:teenancial/models/user_model.dart';
import 'package:teenancial/providers/auth_provider.dart';
import 'package:teenancial/providers/dompet_provider.dart';
import 'package:teenancial/providers/mission_provider.dart';
import 'package:teenancial/providers/transaction_provider.dart';
import 'package:teenancial/providers/user_provider.dart';
import 'package:teenancial/repositories/auth_repository.dart';
import 'package:teenancial/repositories/dompet_repository.dart';
import 'package:teenancial/repositories/transaction_repository.dart';
import 'package:teenancial/repositories/user_repository.dart';
import 'package:teenancial/screens/riwayat_screen.dart';
import 'package:teenancial/services/notification_service.dart';
import 'package:teenancial/utils/error_mapper.dart';
import 'package:teenancial/utils/xp_helper.dart';

class _FakeUserRepository extends UserRepository {
  UserModel profile;
  int xpAdded = 0;
  bool failIncrementXp = false;

  _FakeUserRepository(this.profile);

  @override
  Future<UserModel> getUserProfile(String uid) async => profile;

  @override
  Future<void> incrementXp(String uid, int amount) async {
    if (failIncrementXp) {
      throw Exception('Simulasi gagal jaringan saat menambah XP');
    }
    xpAdded += amount;
    profile = profile.copyWith(xp: profile.xp + amount);
  }

  @override
  Future<void> saveFeenEquipped(
    String uid,
    Map<String, String> equipped,
  ) async {
    profile = profile.copyWith(
      feenEquipped: Map<String, String>.from(equipped),
    );
  }
}

class _FakeDompetRepository extends DompetRepository {
  final List<DompetItem> store = [];

  @override
  Future<List<DompetItem>> getDompets(String uid) async =>
      List<DompetItem>.from(store);

  @override
  Future<void> addDompet(String uid, DompetItem item) async {}

  @override
  Future<void> updateDompet(String uid, DompetItem item) async {}

  @override
  Future<void> deleteDompet(String uid, String dompetId) async {}
}

class _FakeTransactionRepository extends TransactionRepository {
  final List<TransactionModel> store = [];

  @override
  Future<List<TransactionModel>> getTransactions(String uid) async =>
      List<TransactionModel>.from(store);

  @override
  Future<void> addTransaction(String uid, TransactionModel transaction) async {
    store.add(
      transaction.id.isEmpty
          ? transaction.copyWith(id: 'tx_${store.length + 1}')
          : transaction,
    );
  }

  @override
  Future<void> updateTransaction(String uid, TransactionModel updated) async {}

  @override
  Future<void> deleteTransaction(String uid, String transactionId) async {}

  @override
  Future<void> markAsPaid(
    String uid,
    String transactionId,
    String paidDompetId,
  ) async {
    final idx = store.indexWhere((t) => t.id == transactionId);
    if (idx != -1) {
      store[idx] = store[idx].copyWith(
        isPaid: true,
        paidDompetId: paidDompetId,
      );
    }
  }

  @override
  Future<void> addLoanPayment(
    String uid,
    String transactionId,
    LoanPayment payment,
  ) async {
    final idx = store.indexWhere((t) => t.id == transactionId);
    if (idx != -1) {
      store[idx] = store[idx].withPayment(payment);
    }
  }

  @override
  Future<void> removeLoanPayment(
    String uid,
    String transactionId,
    String paymentId,
  ) async {}
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('UserModel & FeenTier', () {
    test('UserModel.fromMap membersihkan key legacy dan duplikat modul/kuis', () {
      final user = UserModel.fromMap({
        'email': 'teen@example.com',
        'name': 'Rani',
        'completedModules': ['0_0', 'mod_1', 'mod_1', '0_1', 'mod_2', ''],
        'completedQuizzes': ['0_0', 'mod_1', 'mod_1', '  '],
      }, uidFallback: 'u1');

      expect(user.completedModules, ['mod_1', 'mod_2']);
      expect(user.completedQuizzes, ['mod_1']);
      expect(BelajarProgressModel.isLegacyKey('0_0'), isTrue);
      expect(BelajarProgressModel.isLegacyKey('mod_1'), isFalse);
    });

    test('tierForLevel memetakan Rookie (1-14), Saver (15-29), dan Pro (30+)', () {
      expect(tierForLevel(1), FeenTier.rookie);
      expect(tierForLevel(14), FeenTier.rookie);
      expect(tierForLevel(15), FeenTier.saver);
      expect(tierForLevel(29), FeenTier.saver);
      expect(tierForLevel(30), FeenTier.pro);
      expect(tierForLevel(40), FeenTier.pro);

      expect(tierUnlockedAt(1), FeenTier.rookie);
      expect(tierUnlockedAt(15), FeenTier.saver);
      expect(tierUnlockedAt(30), FeenTier.pro);
      expect(tierUnlockedAt(5), isNull);
    });

    test(
      'unequipAllFeen mempertahankan bingkai profil secara default dan melepas aksesoris maskot',
      () async {
        final userRepo = _FakeUserRepository(
          UserModel(
            uid: 'u1',
            email: 'teen@example.com',
            name: 'Rani',
            xp: XpHelper.totalXpForLevel(15),
          ),
        );
        final userProvider = UserProvider(repository: userRepo);
        userProvider.updateUser('u1');
        await Future<void>.delayed(Duration.zero);
        expect(userProvider.profile, isNotNull);

        await userProvider.equipFeen(FeenSlot.head, 'beanie');
        await userProvider.equipFeen(FeenSlot.face, 'glasses');
        await userProvider.equipFeen(FeenSlot.frame, 'frame_matcha');
        expect(userProvider.feenEquipped, {
          'head': 'beanie',
          'face': 'glasses',
          'frame': 'frame_matcha',
        });

        await userProvider.unequipAllFeen();
        expect(userProvider.feenEquipped, {'frame': 'frame_matcha'});

        await userProvider.unequipAllFeen(includeFrame: true);
        expect(userProvider.feenEquipped, isEmpty);
      },
    );
  });

  group('MissionProvider One-Time Sync & Rollback', () {
    test(
      'syncOneTimeLearningProgress membersihkan klaim prematur jika jumlah modul/kuis valid < target',
      () async {
        final userRepo = _FakeUserRepository(
          const UserModel(
            uid: 'u1',
            email: 'teen@example.com',
            name: 'Rani',
            completedModules: ['mod_1', 'mod_2'],
            completedQuizzes: ['mod_1', 'mod_2'],
          ),
        );
        final userProvider = UserProvider(repository: userRepo);
        userProvider.updateUser('u1');
        await userProvider.loadProfile();

        Map<String, dynamic>? storedDoc = {
          'counters': {
            'oneTime:completeModule': 3,
            'oneTime:passQuiz': 3,
          },
          'claimedKeys': [
            'oneTime:onetime_module_1',
            'oneTime:onetime_quiz_1',
            'oneTime:onetime_module_3',
            'oneTime:onetime_quiz_3',
          ],
        };

        final missionProvider = MissionProvider(
          onLoad: (_) async => storedDoc,
          onSave: (_, payload) async {
            storedDoc = Map<String, dynamic>.from(payload);
          },
        );
        missionProvider.bindDependencies('u1', userProvider);
        await missionProvider.loadMissions();

        final mod1 = MissionCatalog.all
            .firstWhere((m) => m.id == 'onetime_module_1');
        final mod3 = MissionCatalog.all
            .firstWhere((m) => m.id == 'onetime_module_3');
        final quiz3 = MissionCatalog.all
            .firstWhere((m) => m.id == 'onetime_quiz_3');

        expect(missionProvider.currentProgress(mod3), 2);
        expect(missionProvider.currentProgress(quiz3), 2);
        expect(missionProvider.statusOf(mod1), MissionClaimStatus.claimed);
        expect(missionProvider.statusOf(mod3), MissionClaimStatus.inProgress);
        expect(missionProvider.statusOf(quiz3), MissionClaimStatus.inProgress);

        // Memicu daily/weekly completeModule tidak boleh menggandakan progres oneTime
        // selama jumlah terverifikasi dari BelajarProvider bernilai 2.
        await missionProvider.syncOneTimeLearningProgress(
          completedModulesCount: 2,
          completedQuizzesCount: 2,
        );
        await missionProvider.recordTrigger(MissionTrigger.completeModule);

        expect(missionProvider.currentProgress(mod3), 2);
        expect(missionProvider.statusOf(mod3), MissionClaimStatus.inProgress);

        await missionProvider.syncOneTimeLearningProgress(
          completedModulesCount: 3,
          completedQuizzesCount: 3,
        );
        expect(missionProvider.currentProgress(mod3), 3);
        expect(missionProvider.statusOf(mod3), MissionClaimStatus.claimable);
      },
    );
  });

  group('MissionProvider Streak, Bonus XP, Claim All & Target Sync', () {
    test(
      'misi streak one-time terisi dari streak harian, tidak turun saat putus, dan tidak dapat diklaim ulang',
      () async {
        var fakeNow = DateTime(2026, 11, 1, 10, 0);
        final userRepo = _FakeUserRepository(
          const UserModel(
            uid: 'u1',
            email: 'teen@example.com',
            name: 'Rani',
          ),
        );
        final userProvider = UserProvider(repository: userRepo);
        userProvider.updateUser('u1');
        await userProvider.loadProfile();

        Map<String, dynamic>? storedDoc = {};
        final missionProvider = MissionProvider(
          clock: () => fakeNow,
          onLoad: (_) async => storedDoc,
          onSave: (_, payload) async {
            storedDoc = Map<String, dynamic>.from(payload);
          },
        );
        missionProvider.bindDependencies('u1', userProvider);
        await missionProvider.loadMissions();

        final streak3 = MissionCatalog.all
            .firstWhere((m) => m.id == 'onetime_streak_3');

        // Hari 1
        await missionProvider.recordTrigger(MissionTrigger.addIncomeExpense);
        expect(missionProvider.streakCount, 1);
        expect(missionProvider.isStreakActiveToday, isTrue);
        expect(missionProvider.currentProgress(streak3), 1);

        // Hari 2
        fakeNow = DateTime(2026, 11, 2, 11, 0);
        await missionProvider.recordTrigger(MissionTrigger.addIncomeExpense);
        expect(missionProvider.streakCount, 2);
        expect(missionProvider.currentProgress(streak3), 2);

        // Hari 3
        fakeNow = DateTime(2026, 11, 3, 9, 0);
        await missionProvider.recordTrigger(MissionTrigger.addIncomeExpense);
        expect(missionProvider.streakCount, 3);
        expect(missionProvider.currentProgress(streak3), 3);
        expect(missionProvider.statusOf(streak3), MissionClaimStatus.claimable);

        final xpGained = await missionProvider.claimMission(streak3);
        expect(xpGained, 50);
        expect(userProvider.xp, 50);
        expect(missionProvider.statusOf(streak3), MissionClaimStatus.claimed);

        // Lompat ke Hari 5 (melewati Hari 4 -> streak terputus)
        fakeNow = DateTime(2026, 11, 5, 8, 0);
        await missionProvider.refreshPeriodicState();
        expect(missionProvider.streakCount, 0);
        expect(missionProvider.brokenStreakCount, 3);
        expect(missionProvider.isStreakActiveToday, isFalse);
        expect(missionProvider.currentProgress(streak3), 3);
        expect(missionProvider.statusOf(streak3), MissionClaimStatus.claimed);

        // Sinkronisasi progres belajar tidak boleh mencabut klaim misi streak
        await missionProvider.syncOneTimeLearningProgress(
          completedModulesCount: 0,
          completedQuizzesCount: 0,
        );
        expect(missionProvider.statusOf(streak3), MissionClaimStatus.claimed);

        // Mulai streak baru di Hari 5
        await missionProvider.recordTrigger(MissionTrigger.addIncomeExpense);
        expect(missionProvider.streakCount, 1);
        expect(missionProvider.isStreakActiveToday, isTrue);
      },
    );

    test(
      'bonus streak XP hanya berlaku untuk misi rutin (harian/mingguan/bulanan) dan bukan sekali saja',
      () async {
        final fakeNow = DateTime(2026, 11, 10, 12, 0);
        final userRepo = _FakeUserRepository(
          const UserModel(
            uid: 'u1',
            email: 'teen@example.com',
            name: 'Rani',
          ),
        );
        final userProvider = UserProvider(repository: userRepo);
        userProvider.updateUser('u1');
        await userProvider.loadProfile();

        Map<String, dynamic>? storedDoc = {
          'streakCount': 5,
          'lastStreakDate': '2026-11-10',
          'counters': <String, int>{},
          'claimedKeys': <String>[],
        };
        final missionProvider = MissionProvider(
          clock: () => fakeNow,
          onLoad: (_) async => storedDoc,
          onSave: (_, payload) async {
            storedDoc = Map<String, dynamic>.from(payload);
          },
        );
        missionProvider.bindDependencies('u1', userProvider);
        await missionProvider.loadMissions();

        expect(missionProvider.streakBonusPercent, 10);

        final daily = MissionCatalog.all
            .firstWhere((m) => m.id == 'daily_tx_1');
        final weekly = MissionCatalog.all
            .firstWhere((m) => m.id == 'weekly_tx_5');
        final monthly = MissionCatalog.all
            .firstWhere((m) => m.id == 'monthly_tx_20');
        final oneTimeModule = MissionCatalog.all
            .firstWhere((m) => m.id == 'onetime_module_1');
        final oneTimeStreak = MissionCatalog.all
            .firstWhere((m) => m.id == 'onetime_streak_3');

        expect(missionProvider.effectiveXpReward(daily), 22);
        expect(missionProvider.effectiveXpReward(weekly), 88);
        expect(missionProvider.effectiveXpReward(monthly), 220);
        expect(missionProvider.effectiveXpReward(oneTimeModule), 100);
        expect(missionProvider.effectiveXpReward(oneTimeStreak), 50);
      },
    );

    test(
      'claimAllMissions mengklaim seluruh misi siap klaim sekaligus dan rollback saat gagal menambah XP',
      () async {
        final fakeNow = DateTime(2026, 11, 10, 14, 0);
        final userRepo = _FakeUserRepository(
          const UserModel(
            uid: 'u1',
            email: 'teen@example.com',
            name: 'Rani',
          ),
        );
        final userProvider = UserProvider(repository: userRepo);
        userProvider.updateUser('u1');
        await userProvider.loadProfile();

        Map<String, dynamic>? storedDoc = {};
        final missionProvider = MissionProvider(
          clock: () => fakeNow,
          onLoad: (_) async => storedDoc,
          onSave: (_, payload) async {
            storedDoc = Map<String, dynamic>.from(payload);
          },
        );
        missionProvider.bindDependencies('u1', userProvider);
        await missionProvider.loadMissions();

        await missionProvider.recordTrigger(MissionTrigger.addIncomeExpense);
        await missionProvider.recordTrigger(MissionTrigger.saveTarget);

        final dailyTx = MissionCatalog.all
            .firstWhere((m) => m.id == 'daily_tx_1');
        final dailySave = MissionCatalog.all
            .firstWhere((m) => m.id == 'daily_save_1');
        expect(missionProvider.claimableCount, 2);
        expect(missionProvider.claimableTotalXp, 45);

        // Simulasikan kegagalan penulisan XP -> harus rollback di memori & penyimpanan
        userRepo.failIncrementXp = true;
        await expectLater(
          missionProvider.claimAllMissions(),
          throwsException,
        );
        expect(userProvider.xp, 0);
        expect(missionProvider.statusOf(dailyTx), MissionClaimStatus.claimable);
        expect(
          missionProvider.statusOf(dailySave),
          MissionClaimStatus.claimable,
        );
        expect(storedDoc?['claimedKeys'], isEmpty);

        // Coba ulang saat jaringan pulih -> klaim berhasil
        userRepo.failIncrementXp = false;
        final totalXp = await missionProvider.claimAllMissions();
        expect(totalXp, 45);
        expect(userProvider.xp, 45);
        expect(missionProvider.statusOf(dailyTx), MissionClaimStatus.claimed);
        expect(missionProvider.statusOf(dailySave), MissionClaimStatus.claimed);
        expect(missionProvider.claimableCount, 0);
      },
    );

    test(
      'syncOneTimeTargetsCount memberi kredit onetime_create_target_1 dan tetap bertahan saat target dihapus',
      () async {
        final fakeNow = DateTime(2026, 11, 10, 14, 0);
        final userRepo = _FakeUserRepository(
          const UserModel(
            uid: 'u1',
            email: 'teen@example.com',
            name: 'Rani',
          ),
        );
        final userProvider = UserProvider(repository: userRepo);
        userProvider.updateUser('u1');
        await userProvider.loadProfile();

        Map<String, dynamic>? storedDoc = {};
        final missionProvider = MissionProvider(
          clock: () => fakeNow,
          onLoad: (_) async => storedDoc,
          onSave: (_, payload) async {
            storedDoc = Map<String, dynamic>.from(payload);
          },
        );
        missionProvider.bindDependencies('u1', userProvider);
        await missionProvider.loadMissions();

        final targetOneTime = MissionCatalog.all
            .firstWhere((m) => m.id == 'onetime_create_target_1');
        expect(missionProvider.currentProgress(targetOneTime), 0);

        await missionProvider.syncOneTimeTargetsCount(2);
        expect(missionProvider.currentProgress(targetOneTime), 1);
        expect(
          missionProvider.statusOf(targetOneTime),
          MissionClaimStatus.claimable,
        );

        await missionProvider.syncOneTimeTargetsCount(0);
        expect(missionProvider.currentProgress(targetOneTime), 1);
        expect(
          missionProvider.statusOf(targetOneTime),
          MissionClaimStatus.claimable,
        );
      },
    );

    test(
      'refreshPeriodicState mereset counter harian saat jam perangkat melewati tengah malam',
      () async {
        var fakeNow = DateTime(2026, 11, 10, 23, 55);
        final userRepo = _FakeUserRepository(
          const UserModel(
            uid: 'u1',
            email: 'teen@example.com',
            name: 'Rani',
          ),
        );
        final userProvider = UserProvider(repository: userRepo);
        userProvider.updateUser('u1');
        await userProvider.loadProfile();

        Map<String, dynamic>? storedDoc = {};
        final missionProvider = MissionProvider(
          clock: () => fakeNow,
          onLoad: (_) async => storedDoc,
          onSave: (_, payload) async {
            storedDoc = Map<String, dynamic>.from(payload);
          },
        );
        missionProvider.bindDependencies('u1', userProvider);
        await missionProvider.loadMissions();

        final dailyTx = MissionCatalog.all
            .firstWhere((m) => m.id == 'daily_tx_1');
        await missionProvider.recordTrigger(MissionTrigger.addIncomeExpense);
        expect(missionProvider.currentProgress(dailyTx), 1);
        expect(missionProvider.streakCount, 1);

        // Lewati tengah malam -> progres harian tereset, streak kemarin tetap terjaga
        fakeNow = DateTime(2026, 11, 11, 0, 1);
        await missionProvider.refreshPeriodicState();
        expect(missionProvider.currentProgress(dailyTx), 0);
        expect(
          missionProvider.statusOf(dailyTx),
          MissionClaimStatus.inProgress,
        );
        expect(missionProvider.streakCount, 1);
        expect(missionProvider.isStreakActiveToday, isFalse);
      },
    );
  });

  group('TransactionProvider Mission Trigger Separation', () {
    late _FakeTransactionRepository txRepo;
    late DompetProvider dompetProvider;
    late MissionProvider missionProvider;
    late TransactionProvider txProvider;

    setUp(() async {
      final userProvider = UserProvider(
        repository: _FakeUserRepository(
          const UserModel(
            uid: 'u1',
            email: 'teen@example.com',
            name: 'Rani',
          ),
        ),
      );
      userProvider.updateUser('u1');
      await userProvider.loadProfile();

      Map<String, dynamic>? missionDoc = {};
      missionProvider = MissionProvider(
        onLoad: (_) async => missionDoc,
        onSave: (_, payload) async {
          missionDoc = Map<String, dynamic>.from(payload);
        },
      );
      missionProvider.bindDependencies('u1', userProvider);
      await missionProvider.loadMissions();

      dompetProvider = DompetProvider(repository: _FakeDompetRepository());
      txRepo = _FakeTransactionRepository();
      txProvider = TransactionProvider(repository: txRepo);
      txProvider.bindDependencies('u1', dompetProvider, missionProvider);
      await Future<void>.delayed(Duration.zero);
    });

    test(
      'hutang, piutang, transfer, dan penyesuaian saldo tidak memicu misi pemasukan/pengeluaran harian',
      () async {
        final dailyIncomeExpense = MissionCatalog.all
            .firstWhere((m) => m.id == 'daily_tx_1');
        final weeklyAllTx = MissionCatalog.all
            .firstWhere((m) => m.id == 'weekly_tx_5');
        final monthlyAllTx = MissionCatalog.all
            .firstWhere((m) => m.id == 'monthly_tx_20');

        // 1. Penyesuaian saldo otomatis tidak boleh memicu misi mana pun
        await txProvider.addTransaction(
          TransactionModel(
            id: '',
            title: 'Penyesuaian Saldo',
            amount: 10000,
            date: DateTime(2026, 11, 15),
            notes: 'Penyesuaian saldo otomatis saat edit dompet',
            categoryId: 'c6',
            type: TransactionType.expense,
            dompetId: 'w1',
            isAdjustment: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(missionProvider.currentProgress(dailyIncomeExpense), 0);
        expect(missionProvider.currentProgress(weeklyAllTx), 0);
        expect(missionProvider.currentProgress(monthlyAllTx), 0);

        // 2. Transfer, hutang, piutang memicu weekly/monthly addTransaction, bukan daily_tx_1
        await txProvider.addTransaction(
          TransactionModel(
            id: '',
            title: 'Transfer Dompet',
            amount: 25000,
            date: DateTime(2026, 11, 15),
            categoryId: 't1',
            type: TransactionType.transfer,
            dompetId: 'w1',
            destinationDompetId: 'w2',
          ),
        );
        await txProvider.addTransaction(
          TransactionModel(
            id: 'loan_debt_1',
            title: 'Hutang',
            amount: 50000,
            date: DateTime(2026, 11, 15),
            categoryId: 'p1',
            type: TransactionType.debt,
            dompetId: 'w1',
            counterpartyName: 'Valmai',
          ),
        );
        await txProvider.addTransaction(
          TransactionModel(
            id: 'loan_rec_1',
            title: 'Piutang',
            amount: 30000,
            date: DateTime(2026, 11, 15),
            categoryId: 'p2',
            type: TransactionType.receivable,
            dompetId: 'w1',
            counterpartyName: 'Pocut',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(missionProvider.currentProgress(dailyIncomeExpense), 0);
        expect(missionProvider.currentProgress(weeklyAllTx), 3);
        expect(missionProvider.currentProgress(monthlyAllTx), 3);
        expect(missionProvider.hasCompletedAnyDailyToday, isFalse);

        // 3. Cicilan & pelunasan pinjaman hanya memicu addTransaction
        await txProvider.addLoanPayment(
          'loan_debt_1',
          LoanPayment(
            id: 'pay_1',
            amount: 20000,
            date: DateTime(2026, 11, 15),
            dompetId: 'w1',
          ),
        );
        await txProvider.markAsPaid('loan_rec_1', 'w1');
        await Future<void>.delayed(Duration.zero);

        expect(missionProvider.currentProgress(dailyIncomeExpense), 0);
        expect(missionProvider.currentProgress(weeklyAllTx), 5);
        expect(missionProvider.currentProgress(monthlyAllTx), 5);
        expect(missionProvider.hasCompletedAnyDailyToday, isFalse);

        // 4. Pengeluaran nyata memicu kedua counter: addIncomeExpense dan addTransaction
        await txProvider.addTransaction(
          TransactionModel(
            id: '',
            title: 'Makan Siang',
            amount: 15000,
            date: DateTime(2026, 11, 15),
            categoryId: 'c1',
            type: TransactionType.expense,
            dompetId: 'w1',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(missionProvider.currentProgress(dailyIncomeExpense), 1);
        expect(missionProvider.currentProgress(weeklyAllTx), 5);
        expect(missionProvider.currentProgress(monthlyAllTx), 6);
        expect(missionProvider.hasCompletedAnyDailyToday, isTrue);
      },
    );

    test(
      'pemasukan non-penyesuaian juga memicu misi harian pemasukan/pengeluaran',
      () async {
        final dailyIncomeExpense = MissionCatalog.all
            .firstWhere((m) => m.id == 'daily_tx_1');
        expect(missionProvider.currentProgress(dailyIncomeExpense), 0);

        await txProvider.addTransaction(
          TransactionModel(
            id: '',
            title: 'Uang Saku',
            amount: 50000,
            date: DateTime(2026, 11, 15),
            categoryId: 'i1',
            type: TransactionType.income,
            dompetId: 'w1',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(missionProvider.currentProgress(dailyIncomeExpense), 1);
        expect(missionProvider.hasCompletedAnyDailyToday, isTrue);
      },
    );
  });

  group('RiwayatScreen.buildAllGroups', () {
    test(
      'mengelompokkan seluruh transaksi berdasarkan hari tanpa terpotong filter tren',
      () {
        final transactions = [
          TransactionModel(
            id: 'tx_new',
            title: 'Jajan',
            amount: 10000,
            date: DateTime(2026, 11, 15, 12),
            categoryId: 'c1',
            type: TransactionType.expense,
            dompetId: 'w1',
          ),
          TransactionModel(
            id: 'tx_old',
            title: 'Uang Saku Bulan Lalu',
            amount: 200000,
            date: DateTime(2026, 9, 1, 9),
            categoryId: 'i1',
            type: TransactionType.income,
            dompetId: 'w1',
          ),
        ];

        final groups = RiwayatScreen.buildAllGroups(transactions);
        expect(groups.length, 2);
        expect(groups.first.items.single.id, 'tx_new');
        expect(groups.last.items.single.id, 'tx_old');
      },
    );
  });

  group('NotificationService.buildDailyMissionReminderPlan', () {
    test(
      'sebelum pukul 20:00 dan belum selesai misi harian -> jadwalkan hari ini pukul 20:00 & tandai armedDate',
      () {
        final plan = NotificationService.buildDailyMissionReminderPlan(
          now: DateTime(2026, 11, 15, 10, 30),
          hasCompletedAnyDailyToday: false,
        );

        expect(plan.scheduledDate, DateTime(2026, 11, 15, 20));
        expect(plan.shouldShowInstantNow, isFalse);
        expect(plan.armedDateToRecord, '2026-11-15');
        expect(plan.shouldClearArmedDate, isFalse);
      },
    );

    test(
      'sebelum pukul 20:00 tetapi misi harian hari ini sudah selesai -> skip hari ini ke besok 20:00',
      () {
        final plan = NotificationService.buildDailyMissionReminderPlan(
          now: DateTime(2026, 11, 15, 14, 0),
          hasCompletedAnyDailyToday: true,
          armedDate: '2026-11-15',
        );

        expect(plan.scheduledDate, DateTime(2026, 11, 16, 20));
        expect(plan.shouldShowInstantNow, isFalse);
        expect(plan.shouldClearArmedDate, isTrue);
      },
    );

    test(
      'jendela 20:00-23:59 saat misi harian 0 & belum tercakup -> munculkan notif instan 1x dan jadwalkan besok 20:00',
      () {
        final plan = NotificationService.buildDailyMissionReminderPlan(
          now: DateTime(2026, 11, 15, 21, 15),
          hasCompletedAnyDailyToday: false,
          lastRemindedDate: '2026-11-14',
        );

        expect(plan.scheduledDate, DateTime(2026, 11, 16, 20));
        expect(plan.shouldShowInstantNow, isTrue);
        expect(plan.lastRemindedDateToRecord, '2026-11-15');
        expect(plan.shouldClearArmedDate, isTrue);
      },
    );

    test(
      'jendela 20:00-23:59 jika sudah diingatkan hari ini -> tidak memunculkan notif instan kedua kalinya',
      () {
        final plan = NotificationService.buildDailyMissionReminderPlan(
          now: DateTime(2026, 11, 15, 22, 45),
          hasCompletedAnyDailyToday: false,
          lastRemindedDate: '2026-11-15',
        );

        expect(plan.scheduledDate, DateTime(2026, 11, 16, 20));
        expect(plan.shouldShowInstantNow, isFalse);
        expect(plan.lastRemindedDateToRecord, '2026-11-15');
      },
    );

    test(
      'jendela 20:00-23:59 jika alarm hari ini sudah dipasang sebelumnya atau notif masih aktif di tray -> cegah double notif',
      () {
        final coveredByArmed = NotificationService.buildDailyMissionReminderPlan(
          now: DateTime(2026, 11, 15, 20, 30),
          hasCompletedAnyDailyToday: false,
          armedDate: '2026-11-15',
        );
        expect(coveredByArmed.shouldShowInstantNow, isFalse);
        expect(coveredByArmed.lastRemindedDateToRecord, '2026-11-15');

        final coveredByTray = NotificationService.buildDailyMissionReminderPlan(
          now: DateTime(2026, 11, 15, 20, 30),
          hasCompletedAnyDailyToday: false,
          hasActiveDailyMissionNotification: true,
        );
        expect(coveredByTray.shouldShowInstantNow, isFalse);
        expect(coveredByTray.lastRemindedDateToRecord, '2026-11-15');
      },
    );

    test(
      'jendela 20:00-23:59 jika misi harian sudah selesai -> tidak memunculkan notif instan',
      () {
        final plan = NotificationService.buildDailyMissionReminderPlan(
          now: DateTime(2026, 11, 15, 21, 0),
          hasCompletedAnyDailyToday: true,
        );

        expect(plan.scheduledDate, DateTime(2026, 11, 16, 20));
        expect(plan.shouldShowInstantNow, isFalse);
      },
    );

    test(
      'saat status misi hari ini masih null (belum selesai load dari Firestore) -> tidak memicu notif instan dan menjaga jadwal 20:00',
      () {
        final planEvening = NotificationService.buildDailyMissionReminderPlan(
          now: DateTime(2026, 11, 15, 21, 0),
          hasCompletedAnyDailyToday: null,
          lastRemindedDate: '2026-11-14',
          armedDate: '2026-11-14',
        );

        expect(planEvening.scheduledDate, DateTime(2026, 11, 16, 20));
        expect(planEvening.shouldShowInstantNow, isFalse);
        expect(planEvening.lastRemindedDateToRecord, '2026-11-14');
        expect(planEvening.armedDateToRecord, '2026-11-14');
        expect(planEvening.shouldClearArmedDate, isFalse);
      },
    );

    test(
      'dailyMissionResponseDateKey hanya menandai hari ini pada jendela 20:00-23:59',
      () {
        expect(
          NotificationService.dailyMissionResponseDateKey(
            DateTime(2026, 11, 15, 8, 30),
          ),
          isNull,
        );
        expect(
          NotificationService.dailyMissionResponseDateKey(
            DateTime(2026, 11, 15, 20, 5),
          ),
          '2026-11-15',
        );
      },
    );

    test(
      'buildDailyMissionScheduleDates menjadwalkan 7 hari one-shot mulai besok 20:00 saat minimal 1 misi harian sudah selesai sebelum 20:00 (termasuk lintas bulan)',
      () {
        final plan = NotificationService.buildDailyMissionReminderPlan(
          now: DateTime(2026, 11, 30, 18, 30),
          hasCompletedAnyDailyToday: true,
        );
        final dates = NotificationService.buildDailyMissionScheduleDates(
          plan.scheduledDate,
        );

        expect(dates.length, NotificationService.dailyMissionScheduleHorizonDays);
        expect(dates.first, DateTime(2026, 12, 1, 20, 0));
        expect(dates.last, DateTime(2026, 12, 7, 20, 0));
        // Pastikan hari ini (30 Nov 20:00) tidak pernah masuk jadwal
        expect(
          dates.any((d) => d.year == 2026 && d.month == 11 && d.day == 30),
          isFalse,
        );
      },
    );

    test(
      'buildDailyMissionScheduleDates mulai hari ini 20:00 saat belum ada misi harian selesai sebelum 20:00',
      () {
        final plan = NotificationService.buildDailyMissionReminderPlan(
          now: DateTime(2026, 11, 21, 18, 30),
          hasCompletedAnyDailyToday: false,
        );
        final dates = NotificationService.buildDailyMissionScheduleDates(
          plan.scheduledDate,
        );

        expect(dates.length, 7);
        expect(dates.first, DateTime(2026, 11, 21, 20, 0));
        expect(dates.last, DateTime(2026, 11, 27, 20, 0));
      },
    );
  });

  group('AuthRepository.isMatchingGoogleEmail & ErrorMapper', () {
    test('mencocokkan email secara case-insensitive dan whitespace-trimmed', () {
      expect(
        AuthRepository.isMatchingGoogleEmail(
          'User.Satu@Gmail.com ',
          ' user.satu@gmail.com',
        ),
        isTrue,
      );
      expect(
        AuthRepository.isMatchingGoogleEmail(
          'akun.a@gmail.com',
          'akun.b@gmail.com',
        ),
        isFalse,
      );
      expect(
        AuthRepository.isMatchingGoogleEmail(null, 'akun.b@gmail.com'),
        isTrue,
      );
    });

    test(
      'isSessionFreshForDeletion mengembalikan true hanya jika sesi login < 4 menit',
      () {
        final now = DateTime(2026, 11, 21, 13, 0, 0);
        expect(
          AuthRepository.isSessionFreshForDeletion(
            now.subtract(const Duration(minutes: 2)),
            now: now,
          ),
          isTrue,
        );
        expect(
          AuthRepository.isSessionFreshForDeletion(
            now.subtract(const Duration(minutes: 4)),
            now: now,
          ),
          isFalse,
        );
        expect(
          AuthRepository.isSessionFreshForDeletion(
            now.subtract(const Duration(hours: 2)),
            now: now,
          ),
          isFalse,
        );
        expect(
          AuthRepository.isSessionFreshForDeletion(null, now: now),
          isFalse,
        );
      },
    );

    test(
      'ErrorMapper menerjemahkan error reautentikasi ke Bahasa Indonesia',
      () {
        expect(
          ErrorMapper.message(FirebaseAuthException(code: 'user-mismatch')),
          contains('Akun Google yang dipilih tidak cocok'),
        );
        expect(
          ErrorMapper.message(
            FirebaseAuthException(code: 'requires-recent-login'),
          ),
          contains('Demi keamanan'),
        );
        expect(
          ErrorMapper.message(
            FirebaseAuthException(code: 'popup-closed-by-user'),
          ),
          contains('dibatalkan'),
        );
        expect(
          ErrorMapper.message(
            FirebaseAuthException(code: 'cancelled-popup-request'),
          ),
          contains('dibatalkan'),
        );
        expect(
          ErrorMapper.message(
            FirebaseAuthException(code: 'weak-password'),
          ),
          contains('minimal 8 karakter'),
        );
        expect(
          ErrorMapper.message(
            FirebaseAuthException(code: 'email-already-in-use'),
          ),
          contains('Email/Password atau Google'),
        );
      },
    );

    test(
      'AuthProvider.requiresEmailVerification hanya mewajibkan verifikasi untuk akun Email/Password yang belum terverifikasi',
      () {
        expect(
          AuthProvider.requiresEmailVerification(
            providerIds: [EmailAuthProvider.PROVIDER_ID],
            emailVerified: false,
          ),
          isTrue,
        );
        expect(
          AuthProvider.requiresEmailVerification(
            providerIds: [EmailAuthProvider.PROVIDER_ID],
            emailVerified: true,
          ),
          isFalse,
        );
        expect(
          AuthProvider.requiresEmailVerification(
            providerIds: [GoogleAuthProvider.PROVIDER_ID],
            emailVerified: false,
          ),
          isFalse,
        );
        expect(
          AuthProvider.requiresEmailVerification(
            providerIds: [
              GoogleAuthProvider.PROVIDER_ID,
              EmailAuthProvider.PROVIDER_ID,
            ],
            emailVerified: false,
          ),
          isTrue,
        );
        expect(
          AuthProvider.requiresEmailVerification(
            providerIds: const [],
            emailVerified: false,
          ),
          isFalse,
        );
      },
    );
  });
}
