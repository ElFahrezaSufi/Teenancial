import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:teenancial/models/belajar_model.dart';
import 'package:teenancial/models/target_model.dart';
import 'package:teenancial/providers/belajar_provider.dart';
import 'package:teenancial/providers/target_provider.dart';
import 'package:teenancial/repositories/belajar_repository.dart';
import 'package:teenancial/repositories/target_repository.dart';

class _FakeTargetRepository extends TargetRepository {
  final List<TargetItem> store = [];

  @override
  Future<List<TargetItem>> getTargets(String uid) async {
    final copy = List<TargetItem>.from(store);
    copy.sort((a, b) {
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
        'availableToAllocate menghitung sisa saldo dompet dikurangi total alokasi',
        () {
      expect(provider.totalAllocated, 50000);
      expect(provider.availableToAllocate(200000), 150000);
      expect(provider.availableToAllocate(30000), 0);
    });

    test('allocateTargetFunds menambah dan menarik alokasi sesuai batas saldo',
        () async {
      await provider.allocateTargetFunds(
        targetId: 'tg_1',
        amountDelta: 100000,
        totalWalletBalance: 200000,
      );
      expect(provider.items.first.savedAmount, 150000);

      await provider.allocateTargetFunds(
        targetId: 'tg_1',
        amountDelta: -50000,
        totalWalletBalance: 200000,
      );
      expect(provider.items.first.savedAmount, 100000);
    });

    test('allocateTargetFunds menolak alokasi yang melebihi saldo bebas',
        () async {
      await expectLater(
        () => provider.allocateTargetFunds(
          targetId: 'tg_1',
          amountDelta: 200000,
          totalWalletBalance: 150000,
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
}
