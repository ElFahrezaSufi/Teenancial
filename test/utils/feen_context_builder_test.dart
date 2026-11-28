import 'package:flutter_test/flutter_test.dart';
import 'package:teenancial/config/app_routes.dart';
import 'package:teenancial/data/feen_catalog.dart';
import 'package:teenancial/data/feen_knowledge_base.dart';
import 'package:teenancial/models/dompet_model.dart';
import 'package:teenancial/models/target_model.dart';
import 'package:teenancial/models/transaction_model.dart';
import 'package:teenancial/models/user_model.dart';
import 'package:teenancial/utils/feen_context_builder.dart';

void main() {
  group('FeenContextBuilder & FeenKnowledgeBase', () {
    test(
      'merakit ringkasan live lengkap tanpa PII dan membatasi transaksi terbaru maks 10',
      () {
        final now = DateTime(2026, 11, 20);
        final txs = <TransactionModel>[
          for (int i = 1; i <= 12; i++)
            TransactionModel(
              id: 'tx_$i',
              title: 'Jajan Hari $i',
              amount: 15000,
              date: DateTime(2026, 11, i),
              categoryId: 'c3',
              type: TransactionType.expense,
              dompetId: 'd1',
            ),
          TransactionModel(
            id: 'tx_in',
            title: 'Uang Bulanan',
            amount: 1000000,
            date: DateTime(2026, 11, 1),
            categoryId: 'c1',
            type: TransactionType.income,
            dompetId: 'd1',
          ),
          TransactionModel(
            id: 'tx_save',
            title: 'Tabungan: Laptop',
            amount: 200000,
            date: DateTime(2026, 11, 5),
            categoryId: 'c6',
            type: TransactionType.expense,
            dompetId: 'd1',
            isAdjustment: true,
            targetId: 'tg1',
          ),
          TransactionModel(
            id: 'tx_debt',
            title: 'Hutang dari Budi',
            amount: 50000,
            date: DateTime(2026, 11, 10),
            categoryId: 'c8',
            type: TransactionType.debt,
            dompetId: 'd1',
            counterpartyName: 'Budi',
            dueDate: DateTime(2026, 11, 25),
          ),
        ];

        final snapshot = FeenLiveSnapshot(
          displayName: 'Alya Putri',
          occupationStatus: 'Mahasiswa',
          feenTone: FeenTone.concise,
          level: 4,
          xp: 450,
          xpIntoLevel: 50,
          xpNeededForNext: 200,
          dompets: const [
            DompetItem(
              id: 'd1',
              jenis: JenisDompet.cash,
              nama: 'Dompet Tunai',
              jumlah: 350000,
            ),
          ],
          transactions: txs,
          targets: [
            TargetItem(
              id: 'tg1',
              nama: 'Laptop Kuliah',
              targetAmount: 5000000,
              savedAmount: 1000000,
              imageUrl: 'https://example.com/laptop.jpg',
              isPinned: true,
              deadline: DateTime(2027, 2, 20),
            ),
          ],
          completedModulesCount: 2,
          completedQuizzesCount: 1,
          currentModuleTitle: 'Mengenal Dana Darurat',
          currentLevelTitle: 'Tingkat 1',
          gamification: const FeenGamificationSnapshot(
            streakCount: 5,
            streakBonusPercent: 10,
            claimableCount: 1,
            completedDailyCount: 2,
            totalDailyCount: 3,
            activeMissionLines: [
              'Disiplin Arus Kas (Harian): 2/3 (berjalan, +44 XP)',
            ],
          ),
          now: now,
        );

        final contextBlock = FeenContextBuilder.buildContextBlock(snapshot);
        expect(contextBlock, contains('Nama panggilan: Alya'));
        expect(contextBlock, contains('Status pendidikan/pekerjaan: Mahasiswa'));
        expect(contextBlock, contains('Dompet Tunai (Tunai): Rp 350.000'));
        expect(contextBlock, contains('Perkiraan saldo 7 hari ke depan'));
        expect(contextBlock, contains('Alokasi tabungan target bulan ini: Rp 200.000 (20% dari pemasukan)'));
        expect(contextBlock, contains('Laptop Kuliah'));
        expect(contextBlock, contains('Hutang (Budi)'));
        expect(contextBlock, contains('Mengenal Dana Darurat'));
        expect(contextBlock, contains('Streak harian: 5 hari (bonus XP periodik: +10%)'));
        expect(contextBlock, isNot(contains('@')));
        expect(contextBlock, isNot(contains('uid')));

        // Verifikasi maksimal 10 transaksi terbaru
        final recentSection = contextBlock.split('[TRANSAKSI TERBARU (MAKS 10)]')[1].split('[TARGET MENABUNG]')[0];
        final bulletLines = recentSection
            .split('\n')
            .where((line) => line.trim().startsWith('- '))
            .length;
        expect(bulletLines, 10);

        // Verifikasi system prompt mencakup gaya bahasa, profil, & guardrail off-topic
        final systemPrompt = FeenKnowledgeBase.buildSystemPrompt(
          tone: snapshot.feenTone,
          occupationStatus: snapshot.occupationStatus,
          liveContextBlock: contextBlock,
        );
        expect(systemPrompt, contains('Ringkas & Langsung ke Inti'));
        expect(systemPrompt, contains('Profil pengguna: Mahasiswa'));
        expect(systemPrompt, contains('tolak dengan ramah'));
        expect(systemPrompt, contains('Anti-Halusinasi Angka'));
      },
    );

    test('smart suggestions beradaptasi antara pengguna aktif dan pengguna baru', () {
      final now = DateTime(2026, 11, 20);
      final emptyUser = FeenLiveSnapshot(displayName: 'Baru', now: now);
      final emptySuggestions =
          FeenContextBuilder.buildSmartSuggestions(emptyUser);
      expect(emptySuggestions.length, lessThanOrEqualTo(4));
      expect(
        emptySuggestions.any((s) => s.contains('50/30/20')),
        isTrue,
      );

      final activeUser = FeenLiveSnapshot(
        displayName: 'Aktif',
        now: now,
        transactions: [
          TransactionModel(
            id: 'e1',
            title: 'Kopi',
            amount: 25000,
            date: DateTime(2026, 11, 18),
            categoryId: 'c3',
            type: TransactionType.expense,
            dompetId: 'd1',
          ),
          TransactionModel(
            id: 'd1',
            title: 'Hutang dari Rina',
            amount: 40000,
            date: DateTime(2026, 11, 17),
            categoryId: 'c8',
            type: TransactionType.debt,
            dompetId: 'd1',
          ),
        ],
        targets: [
          TargetItem(
            id: 'tg1',
            nama: 'Sepatu Lari',
            targetAmount: 500000,
            savedAmount: 100000,
            imageUrl: 'https://example.com/s.jpg',
          ),
        ],
      );

      final activeSuggestions =
          FeenContextBuilder.buildSmartSuggestions(activeUser);
      expect(activeSuggestions, contains('Evaluasi pengeluaranku bulan ini'));
      expect(activeSuggestions, contains('Strategi capai target Sepatu Lari'));
      expect(activeSuggestions, contains('Bantu atur pelunasan pinjamanku'));
    });

    test('inferPose dan resolveSuggestedRoutes bekerja tepat serta kosong saat tolak off-topic', () {
      expect(
        FeenKnowledgeBase.inferPose('Bantu strategi target menabungku', 'Ayo sisihkan rutin'),
        FeenPose.saving,
      );
      expect(
        FeenKnowledgeBase.inferPose('Hutangku jatuh tempo besok', 'Segera lunasi ya'),
        FeenPose.alert,
      );

      final routes = FeenKnowledgeBase.resolveSuggestedRoutes(
        'Evaluasi pengeluaranku bulan ini',
        'Cek rincian kategori di Laporan Keuangan dan Target Menabung ya.',
      );
      expect(routes, contains(AppRoutes.laporan));
      expect(routes, contains(AppRoutes.targetMenabung));
      expect(routes.length, lessThanOrEqualTo(2));

      final offTopicRoutes = FeenKnowledgeBase.resolveSuggestedRoutes(
        'Resep nasi goreng dong',
        'Maaf ya aku cuma paham soal keuangan dan Teenancial.',
      );
      expect(offTopicRoutes, isEmpty);
    });
  });
}
