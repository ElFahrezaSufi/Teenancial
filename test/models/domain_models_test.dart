import 'package:flutter_test/flutter_test.dart';
import 'package:teenancial/models/belajar_model.dart';
import 'package:teenancial/models/dompet_model.dart';
import 'package:teenancial/models/target_model.dart';
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

  group('UserModel.calculateAge()', () {
    test('menghitung umur secara akurat sebelum dan sesudah hari ulang tahun', () {
      final birthDate = DateTime(2008, 8, 15);

      // Sebelum ulang tahun di tahun 2026
      expect(
        UserModel.calculateAge(birthDate, now: DateTime(2026, 8, 14)),
        17,
      );

      // Tepat saat ulang tahun di tahun 2026
      expect(
        UserModel.calculateAge(birthDate, now: DateTime(2026, 8, 15)),
        18,
      );

      // Setelah ulang tahun di tahun 2026
      expect(
        UserModel.calculateAge(birthDate, now: DateTime(2026, 11, 6)),
        18,
      );
    });
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

    test('BelajarProgressModel serialisasi toMap & fromMap secara terurut', () {
      const progress = BelajarProgressModel(
        completedModules: {'0_1', '0_0'},
        completedQuizzes: {'0_0'},
      );

      final map = progress.toMap();
      expect(map['completedModules'], ['0_0', '0_1']);
      expect(map['completedQuizzes'], ['0_0']);

      final restored = BelajarProgressModel.fromMap(map);
      expect(restored.completedModules, {'0_0', '0_1'});
      expect(restored.completedQuizzes, {'0_0'});
    });
  });
}
