import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:teenancial/data/feen_catalog.dart';
import 'package:teenancial/data/mission_catalog.dart';
import 'package:teenancial/models/belajar_model.dart';
import 'package:teenancial/models/dompet_model.dart';
import 'package:teenancial/models/mission_model.dart';
import 'package:teenancial/models/transaction_model.dart';
import 'package:teenancial/models/user_model.dart';
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

class _FakeUserRepository extends UserRepository {
  UserModel profile;
  int xpAdded = 0;

  _FakeUserRepository(this.profile);

  @override
  Future<UserModel> getUserProfile(String uid) async => profile;

  @override
  Future<void> incrementXp(String uid, int amount) async {
    xpAdded += amount;
    profile = profile.copyWith(xp: profile.xp + amount);
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

    test('tierForLevel memetakan Rookie (1-5), Saver (6-10), dan Pro (11+)', () {
      expect(tierForLevel(1), FeenTier.rookie);
      expect(tierForLevel(5), FeenTier.rookie);
      expect(tierForLevel(6), FeenTier.saver);
      expect(tierForLevel(10), FeenTier.saver);
      expect(tierForLevel(11), FeenTier.pro);
      expect(tierForLevel(20), FeenTier.pro);
    });
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
      },
    );
  });
}
