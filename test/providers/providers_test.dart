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
  }) async {
    final item = TargetItem(
      id: 'tg_${store.length + 1}',
      nama: nama,
      targetAmount: targetAmount,
      savedAmount: 0,
      imageUrl: 'https://example.com/${imageFile.path}',
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

  @override
  Future<BelajarProgressModel> getProgress(String uid) async => saved;

  @override
  Future<void> saveProgress(String uid, BelajarProgressModel progress) async {
    saved = progress;
  }
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

    test('availableToAllocate menghitung sisa saldo dompet dikurangi total alokasi', () {
      expect(provider.totalAllocated, 50000);
      expect(provider.availableToAllocate(200000), 150000);
      expect(provider.availableToAllocate(30000), 0);
    });

    test('allocateTargetFunds menambah dan menarik alokasi sesuai batas saldo', () async {
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

    test('allocateTargetFunds menolak alokasi yang melebihi saldo bebas', () async {
      await expectLater(
        () => provider.allocateTargetFunds(
          targetId: 'tg_1',
          amountDelta: 200000,
          totalWalletBalance: 150000,
        ),
        throwsException,
      );
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

    test('modul pertama terbuka secara default dan modul kedua terkunci sampai modul+kuis pertama selesai', () async {
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
  });
}
