import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teenancial/data/category_catalog.dart';
import 'package:teenancial/data/category_icons.dart';
import 'package:teenancial/models/belajar_model.dart';
import 'package:teenancial/models/dompet_model.dart';
import 'package:teenancial/models/target_model.dart';
import 'package:teenancial/models/transaction_model.dart';
import 'package:teenancial/models/user_model.dart';

void main() {
  group('TargetItem (Model B Alokasi)', () {
    test('progress dan isAchieved dihitung dari savedAmount / targetAmount', () {
      final target = TargetItem(
        id: 'tg1',
        nama: 'Sepatu Lari',
        targetAmount: 500000,
        savedAmount: 250000,
        imageUrl: 'https://example.com/shoes.jpg',
      );

      expect(target.progress, 0.5);
      expect(target.isAchieved, isFalse);

      final achieved = target.copyWith(savedAmount: 500000);
      expect(achieved.progress, 1.0);
      expect(achieved.isAchieved, isTrue);

      final over = target.copyWith(savedAmount: 600000);
      expect(over.progress, 1.0);
      expect(over.isAchieved, isTrue);
    });

    test('fromMap aman untuk dokumen lama tanpa field savedAmount', () {
      final item = TargetItem.fromMap({
        'nama': 'Kamera',
        'targetAmount': 1000000,
        'imageUrl': 'https://example.com/cam.jpg',
        'isPinned': true,
      }, docId: 'legacy_target');

      expect(item.id, 'legacy_target');
      expect(item.savedAmount, 0.0);
      expect(item.progress, 0.0);
      expect(item.isPinned, isTrue);
      expect(item.deadline, isNull);
    });

    test('deadline opsional terserialisasi dan dapat dihapus lewat copyWith(clearDeadline: true)', () {
      final deadlineDate = DateTime(2026, 12, 31);
      final target = TargetItem(
        id: 'tg_dl',
        nama: 'Laptop',
        targetAmount: 5000000,
        savedAmount: 1000000,
        imageUrl: 'https://example.com/laptop.jpg',
        deadline: deadlineDate,
      );

      final restored = TargetItem.fromMap(target.toMap(), docId: 'tg_dl');
      expect(restored.deadline, deadlineDate);
      expect(restored.remainingAmount, 4000000);

      final cleared = restored.copyWith(clearDeadline: true);
      expect(cleared.deadline, isNull);
    });
  });

  group('UserModel', () {
    test(
      'fromMap aman mengabaikan field lama age, birthDate, dan gender serta toMap tidak menyertakannya',
      () {
        final legacyRaw = <String, dynamic>{
          'uid': 'legacy_u1',
          'email': 'legacy@example.com',
          'name': 'User Lama',
          'age': '18',
          'birthDate': '2008-08-15T00:00:00.000',
          'gender': 'Perempuan',
        };

        expect(UserModel.hasDeprecatedFields(legacyRaw), isTrue);
        expect(UserModel.hasDeprecatedFields({'age': ''}), isTrue);
        expect(UserModel.hasDeprecatedFields({'birthDate': null}), isTrue);
        expect(UserModel.hasDeprecatedFields({'gender': ''}), isTrue);

        final parsed = UserModel.fromMap(legacyRaw);
        expect(parsed.uid, 'legacy_u1');
        expect(parsed.email, 'legacy@example.com');
        expect(parsed.name, 'User Lama');

        final serialized = parsed.toMap();
        expect(serialized.containsKey('age'), isFalse);
        expect(serialized.containsKey('birthDate'), isFalse);
        expect(serialized.containsKey('gender'), isFalse);
        expect(UserModel.hasDeprecatedFields(serialized), isFalse);
      },
    );

    test(
      'initialBalanceOnboardingDone default true untuk pengguna lama dan terserialisasi dengan benar untuk pengguna baru',
      () {
        final legacyUser = UserModel.fromMap({
          'uid': 'old_u1',
          'email': 'lama@example.com',
          'name': 'User Lama',
        });
        expect(legacyUser.initialBalanceOnboardingDone, isTrue);

        final newUser = UserModel.fromMap({
          'uid': 'new_u1',
          'email': 'baru@example.com',
          'name': 'User Baru',
          'initialBalanceOnboardingDone': false,
        });
        expect(newUser.initialBalanceOnboardingDone, isFalse);
        expect(newUser.toMap()['initialBalanceOnboardingDone'], isFalse);

        final finished = newUser.copyWith(initialBalanceOnboardingDone: true);
        expect(finished.initialBalanceOnboardingDone, isTrue);
      },
    );
  });

  group('DompetItem & BelajarProgressModel', () {
    test('JenisDompet.label mengembalikan label Bahasa Indonesia', () {
      expect(JenisDompet.cash.label, 'Tunai');
      expect(JenisDompet.accounts.label, 'Rekening & E-Wallet');
      expect(JenisDompet.card.label, 'Kartu');
    });

    test('DompetItem.copyWith(clearCatatan: true) menghapus catatan', () {
      const dompet = DompetItem(
        id: 'd1',
        jenis: JenisDompet.cash,
        nama: 'Dompet Saku',
        jumlah: 100000,
        catatan: 'Catatan awal',
      );

      final updated = dompet.copyWith(clearCatatan: true);
      expect(updated.catatan, isNull);
    });

    test(
      'DompetItem.compareByTypeAndCreatedAt mengurutkan Tunai -> Rekening & E-Wallet -> Kartu lalu createdAt',
      () {
        final list = [
          DompetItem(
            id: 'd_card_1',
            jenis: JenisDompet.card,
            nama: 'Mandiri',
            jumlah: 100000,
            createdAt: DateTime(2026, 1, 2),
          ),
          DompetItem(
            id: 'd_acc_2',
            jenis: JenisDompet.accounts,
            nama: 'Go-Pay',
            jumlah: 50000,
            createdAt: DateTime(2026, 1, 5),
          ),
          DompetItem(
            id: 'd_cash_2',
            jenis: JenisDompet.cash,
            nama: 'Cadangan',
            jumlah: 20000,
            createdAt: DateTime(2026, 1, 10),
          ),
          DompetItem(
            id: 'd_acc_1',
            jenis: JenisDompet.accounts,
            nama: 'SeaBank',
            jumlah: 80000,
            createdAt: DateTime(2026, 1, 1),
          ),
          const DompetItem(
            id: 'd1',
            jenis: JenisDompet.cash,
            nama: 'Dompet Utama',
            jumlah: 150000,
          ),
          DompetItem(
            id: 'd_card_2',
            jenis: JenisDompet.card,
            nama: 'Bank Sumut',
            jumlah: 30000,
            createdAt: DateTime(2026, 1, 8),
          ),
        ];

        list.sort(DompetItem.compareByTypeAndCreatedAt);

        expect(
          list.map((d) => d.nama).toList(),
          [
            'Dompet Utama',
            'Cadangan',
            'SeaBank',
            'Go-Pay',
            'Mandiri',
            'Bank Sumut',
          ],
        );
      },
    );

    test('BelajarProgressModel serialisasi toMap & fromMap secara terurut', () {
      const progress = BelajarProgressModel(
        completedModules: {'mod_b', 'mod_a'},
        completedQuizzes: {'mod_a'},
      );

      final map = progress.toMap();
      expect(map['completedModules'], ['mod_a', 'mod_b']);
      expect(map['completedQuizzes'], ['mod_a']);

      final restored = BelajarProgressModel.fromMap(map);
      expect(restored.completedModules, {'mod_a', 'mod_b'});
      expect(restored.completedQuizzes, {'mod_a'});
    });

    test('BelajarProgressModel memfilter key legacy indeks dan key kosong', () {
      expect(BelajarProgressModel.isLegacyKey('0_0'), isTrue);
      expect(BelajarProgressModel.isLegacyKey('1_2'), isTrue);
      expect(BelajarProgressModel.isLegacyKey('mod_1'), isFalse);
      expect(BelajarProgressModel.isLegacyKey(''), isFalse);

      final restored = BelajarProgressModel.fromMap({
        'completedModules': ['0_0', '0_1', 'mod_1', '', 'mod_2'],
        'completedQuizzes': ['0_0', 'mod_1', '  '],
      });

      expect(restored.completedModules, {'mod_1', 'mod_2'});
      expect(restored.completedQuizzes, {'mod_1'});
    });
  });

  group('CategoryModel, CategoryIcons & CategoryCatalog', () {
    test('CategoryModel serialisasi toMap/fromMap mempertahankan iconKey dan colorValue', () {
      final custom = CategoryModel(
        id: 'cat_custom_1',
        name: 'Kopi & Jajan',
        type: TransactionType.expense,
        icon: CategoryIcons.iconForKey('drink'),
        iconKey: 'drink',
        colorValue: 0xFFE18151,
        isCustom: true,
        createdAt: DateTime(2026, 11, 14),
      );

      final restored = CategoryModel.fromMap(
        custom.toMap(),
        docId: 'cat_custom_1',
      );
      expect(restored.id, 'cat_custom_1');
      expect(restored.name, 'Kopi & Jajan');
      expect(restored.type, TransactionType.expense);
      expect(restored.iconKey, 'drink');
      expect(restored.icon, Icons.local_cafe_outlined);
      expect(restored.colorValue, 0xFFE18151);
      expect(restored.isCustom, isTrue);
    });

    test('mergeWithCustom menempatkan kategori kustom sebelum kategori Lainnya bawaan', () {
      final customExpense = CategoryModel(
        id: 'cat_custom_exp',
        name: 'Skincare',
        type: TransactionType.expense,
        icon: CategoryIcons.iconForKey('shopping'),
        iconKey: 'shopping',
        colorValue: 0xFFEC407A,
        isCustom: true,
      );

      final merged = CategoryCatalog.mergeWithCustom(
        TransactionType.expense,
        [customExpense],
      );

      expect(merged.last.id, 'c6'); // "Lainnya" selalu paling bawah
      expect(merged[merged.length - 2].id, 'cat_custom_exp');

      final resolved = CategoryCatalog.resolveWithCustom(
        'cat_custom_exp',
        [customExpense],
        fallbackType: TransactionType.expense,
      );
      expect(resolved.name, 'Skincare');

      final missingFallback = CategoryCatalog.resolveWithCustom(
        'deleted_id',
        [customExpense],
        fallbackType: TransactionType.expense,
      );
      expect(missingFallback.id, 'c6');
    });
  });
}
