import 'dart:convert';
import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:teenancial/data/feen_catalog.dart';
import 'package:teenancial/models/belajar_model.dart';
import 'package:teenancial/models/dompet_model.dart';
import 'package:teenancial/models/feen_chat_model.dart';
import 'package:teenancial/models/target_model.dart';
import 'package:teenancial/models/transaction_model.dart';
import 'package:teenancial/models/user_model.dart';
import 'package:teenancial/providers/belajar_provider.dart';
import 'package:teenancial/providers/dompet_provider.dart';
import 'package:teenancial/providers/feen_chat_provider.dart';
import 'package:teenancial/providers/mission_provider.dart';
import 'package:teenancial/providers/target_provider.dart';
import 'package:teenancial/providers/transaction_provider.dart';
import 'package:teenancial/providers/user_provider.dart';
import 'package:teenancial/repositories/belajar_repository.dart';
import 'package:teenancial/repositories/dompet_repository.dart';
import 'package:teenancial/repositories/feen_chat_repository.dart';
import 'package:teenancial/repositories/target_repository.dart';
import 'package:teenancial/repositories/transaction_repository.dart';
import 'package:teenancial/repositories/user_repository.dart';
import 'package:teenancial/screens/laporan_screen.dart';
import 'package:teenancial/screens/tanya_feen_screen.dart';
import 'package:teenancial/services/gemini_service.dart';
import 'package:teenancial/utils/weekly_balance_forecaster.dart';
import 'package:teenancial/widgets/feen/feen_markdown_text.dart';
import 'package:teenancial/widgets/home/weekly_forecast_sheet.dart';

class _StubUserRepo extends UserRepository {
  UserModel profile;
  _StubUserRepo(this.profile);

  @override
  Future<UserModel> getUserProfile(String uid) async => profile;

  @override
  Future<void> updatePersonalization({
    required String uid,
    String? occupationStatus,
    required FeenTone feenTone,
  }) async {
    profile = profile.copyWith(
      occupationStatus: occupationStatus,
      clearOccupationStatus: occupationStatus == null,
      feenTone: feenTone,
    );
  }
}

class _StubDompetRepo extends DompetRepository {
  final List<DompetItem> items;
  _StubDompetRepo(this.items);

  @override
  Future<List<DompetItem>> getDompets(String uid) async => items;
}

class _StubTxRepo extends TransactionRepository {
  final List<TransactionModel> items;
  _StubTxRepo(this.items);

  @override
  Future<List<TransactionModel>> getTransactions(String uid) async => items;
}

class _StubTargetRepo extends TargetRepository {
  final List<TargetItem> items;
  _StubTargetRepo(this.items);

  @override
  Future<List<TargetItem>> getTargets(String uid) async => items;
}

class _StubBelajarRepo extends BelajarRepository {
  @override
  Future<List<LevelData>> getLevels() async => const [];

  @override
  Future<List<ModuleData>> getAllModules() async => const [];

  @override
  Future<BelajarProgressModel> getProgress(String uid) async =>
      const BelajarProgressModel();
}

class _StubChatRepo extends FeenChatRepository {
  final List<FeenChatSession> sessions = [];
  final Map<String, List<FeenChatMessage>> msgs = {};
  int _seq = 0;

  @override
  Future<List<FeenChatSession>> getSessions(String uid) async =>
      List<FeenChatSession>.from(sessions);

  @override
  Future<List<FeenChatMessage>> getMessages(
    String uid,
    String sessionId,
  ) async =>
      List<FeenChatMessage>.from(msgs[sessionId] ?? const []);

  @override
  Future<SavedChatTurn> saveTurnAtomic({
    required String uid,
    FeenChatSession? existingSession,
    required String userText,
    required String modelText,
    required FeenPose pose,
    required List<String> suggestedRoutes,
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    final id = existingSession?.id ?? 's_${++_seq}';
    final uMsg = FeenChatMessage(
      id: 'm_${++_seq}',
      role: FeenMessageRole.user,
      text: userText,
      createdAt: ts,
    );
    final mMsg = FeenChatMessage(
      id: 'm_${++_seq}',
      role: FeenMessageRole.model,
      text: modelText,
      createdAt: ts.add(const Duration(milliseconds: 1)),
      pose: pose,
      suggestedRoutes: suggestedRoutes,
    );
    final session = FeenChatSession(
      id: id,
      title: existingSession?.title ?? FeenChatSession.buildTitleFromPrompt(userText),
      lastMessagePreview: FeenChatSession.buildPreview(modelText),
      messageCount: (existingSession?.messageCount ?? 0) + 2,
      createdAt: existingSession?.createdAt ?? ts,
      updatedAt: ts,
    );
    sessions.removeWhere((s) => s.id == id);
    sessions.insert(0, session);
    msgs.putIfAbsent(id, () => []).addAll([uMsg, mMsg]);
    return SavedChatTurn(
      session: session,
      userMessage: uMsg,
      modelMessage: mMsg,
    );
  }

  @override
  Future<void> deleteSession(String uid, String sessionId) async {
    sessions.removeWhere((s) => s.id == sessionId);
    msgs.remove(sessionId);
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('FeenMarkdownText', () {
    testWidgets('merender teks tebal dan poin tanpa menampilkan bintang mentah',
        (WidgetTester tester) async {
      const sample =
          '### Saran Singkat\n- Sisihkan **Rp 50.000** per minggu\n1. Cek *Laporan Keuangan*';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeenMarkdownText(
              text: sample,
              baseStyle: TextStyle(fontSize: 14, color: Colors.black),
            ),
          ),
        ),
      );

      expect(find.textContaining('**'), findsNothing);
      expect(find.textContaining('Rp 50.000', findRichText: true), findsOneWidget);
      expect(find.textContaining('Saran Singkat', findRichText: true), findsOneWidget);
      expect(
        FeenMarkdownText.toPlainText(sample),
        'Saran Singkat\n- Sisihkan Rp 50.000 per minggu\n1. Cek *Laporan Keuangan*',
      );
    });
  });

  group('TanyaFeenScreen Widget Tests', () {
    Widget buildHarness({
      required FeenChatProvider chatProvider,
      required UserProvider userProvider,
      required DompetProvider dompetProvider,
      required TransactionProvider txProvider,
      required TargetProvider targetProvider,
      required BelajarProvider belajarProvider,
      required MissionProvider missionProvider,
      double textScale = 1.0,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ChangeNotifierProvider<DompetProvider>.value(value: dompetProvider),
          ChangeNotifierProvider<TransactionProvider>.value(value: txProvider),
          ChangeNotifierProvider<TargetProvider>.value(value: targetProvider),
          ChangeNotifierProvider<BelajarProvider>.value(value: belajarProvider),
          ChangeNotifierProvider<MissionProvider>.value(value: missionProvider),
          ChangeNotifierProvider<FeenChatProvider>.value(value: chatProvider),
        ],
        child: MaterialApp(
          locale: const Locale('id', 'ID'),
          supportedLocales: const [Locale('id', 'ID')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: const TanyaFeenScreen(),
        ),
      );
    }

    testWidgets(
      'mengirim pesan via chip saran, merender balasan Feen + shortcut, dan bebas overflow di 320x640 font 1.25x',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final userProvider = UserProvider(
          repository: _StubUserRepo(
            const UserModel(
              uid: 'u1',
              email: 'alya@example.com',
              name: 'Alya',
            ),
          ),
        )..updateUser('u1');

        final dompetProvider = DompetProvider(
          repository: _StubDompetRepo(const [
            DompetItem(
              id: 'd1',
              jenis: JenisDompet.cash,
              nama: 'Dompet Tunai',
              jumlah: 250000,
            ),
          ]),
        )..updateUser('u1');

        final missionProvider = MissionProvider(
          onLoad: (_) async => null,
          onSave: (_, __) async {},
        )..bindDependencies('u1', userProvider);

        final txProvider = TransactionProvider(
          repository: _StubTxRepo([
            TransactionModel(
              id: 't1',
              title: 'Makan Siang',
              amount: 25000,
              date: DateTime.now(),
              categoryId: 'c3',
              type: TransactionType.expense,
              dompetId: 'd1',
            ),
          ]),
        )..bindDependencies('u1', dompetProvider, missionProvider);

        final targetProvider = TargetProvider(
          repository: _StubTargetRepo(const []),
        )..bindDependencies('u1', missionProvider);

        final belajarProvider = BelajarProvider(
          repository: _StubBelajarRepo(),
        )..bindDependencies('u1', missionProvider);

        final mockClient = MockClient((_) async {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text':
                            'Pengeluaranmu bulan ini sebesar **Rp 25.000**. Yuk pantau terus di Laporan Keuangan!',
                      },
                    ],
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });

        final chatProvider = FeenChatProvider(
          repository: _StubChatRepo(),
          geminiService: GeminiService(
            client: mockClient,
            apiKey: 'AIzaTestKey123',
          ),
        )..updateUser('u1');

        await tester.pumpWidget(
          buildHarness(
            chatProvider: chatProvider,
            userProvider: userProvider,
            dompetProvider: dompetProvider,
            txProvider: txProvider,
            targetProvider: targetProvider,
            belajarProvider: belajarProvider,
            missionProvider: missionProvider,
            textScale: 1.25,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(txProvider.transactions.length, 1);
        expect(chatProvider.isLoadingSessions, isFalse);
        expect(chatProvider.messages, isEmpty);
        expect(find.text('Tanya Feen'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Evaluasi pengeluaranku bulan ini'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Evaluasi pengeluaranku bulan ini'), findsOneWidget);

        // Ketuk chip saran -> langsung mengirim pertanyaan dan menampilkan balasan Feen
        await tester.tap(find.text('Evaluasi pengeluaranku bulan ini'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Buka Laporan Keuangan'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.textContaining('Rp 25.000', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('Buka Laporan Keuangan'), findsOneWidget);

        // Buka sheet Riwayat Obrolan -> sesi tersimpan tampil tanpa overflow
        await tester.tap(find.byTooltip('Riwayat Obrolan'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Riwayat Obrolan'), findsOneWidget);
      },
    );
  });

  group('LaporanScreen & WeeklyForecastSheet Widget Tests', () {
    testWidgets(
      'LaporanScreen menampilkan ikon lampu wawasan, persentase tabungan target, dan pintasan Tanya Feen',
      (WidgetTester tester) async {
        final nov2026 = DateTime(2026, 11, 1);
        final userProvider = UserProvider(
          repository: _StubUserRepo(
            const UserModel(uid: 'u1', email: 'a@b.com', name: 'Alya'),
          ),
        )..updateUser('u1');
        final dompetProvider = DompetProvider(
          repository: _StubDompetRepo(const []),
        )..updateUser('u1');
        final missionProvider = MissionProvider(
          onLoad: (_) async => null,
          onSave: (_, __) async {},
        )..bindDependencies('u1', userProvider);

        final txProvider = TransactionProvider(
          repository: _StubTxRepo([
            TransactionModel(
              id: 'i1',
              title: 'Uang Saku',
              amount: 1000000,
              date: DateTime(2026, 11, 2),
              categoryId: 'c1',
              type: TransactionType.income,
              dompetId: 'd1',
            ),
            TransactionModel(
              id: 'e1',
              title: 'Makan',
              amount: 200000,
              date: DateTime(2026, 11, 5),
              categoryId: 'c3',
              type: TransactionType.expense,
              dompetId: 'd1',
            ),
            TransactionModel(
              id: 's1',
              title: 'Tabungan: Laptop',
              amount: 250000,
              date: DateTime(2026, 11, 6),
              categoryId: 'c6',
              type: TransactionType.expense,
              dompetId: 'd1',
              isAdjustment: true,
              targetId: 'tg1',
            ),
          ]),
        )..bindDependencies('u1', dompetProvider, missionProvider);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<UserProvider>.value(value: userProvider),
              ChangeNotifierProvider<TransactionProvider>.value(
                value: txProvider,
              ),
            ],
            child: MaterialApp(
              locale: const Locale('id', 'ID'),
              supportedLocales: const [Locale('id', 'ID')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: LaporanScreen(initialMonth: nov2026),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.lightbulb_rounded), findsOneWidget);
        expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
        expect(
          find.text('Tabungan target bulan ini: Rp 250.000 (25% dari pemasukan).'),
          findsOneWidget,
        );
        expect(
          find.text('Tanya Feen untuk Evaluasi & Saran Bulan Depan'),
          findsOneWidget,
        );
      },
    );

    testWidgets('WeeklyForecastSheet tampil rapi tanpa overflow di layar 320x640',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const sampleForecast = WeeklyBalanceForecast(
        currentBalance: 500000,
        scheduledRecurringIncome: 150000,
        scheduledRecurringExpense: 50000,
        scheduledRecurringCount: 2,
        estimatedDailyExpense: 20000,
        estimatedWeeklyNonRecurringExpense: 140000,
        lookbackDays: 14,
        projectedBalance: 460000,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklyForecastSheet(
              forecast: sampleForecast,
              userLevel: 3,
              feenEquipped: const {},
              onAskFeen: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Perkiraan Minggu Depan'), findsOneWidget);
      expect(find.text('Rp 460.000'), findsOneWidget);
      expect(find.text('Tanya Feen soal proyeksi ini'), findsOneWidget);
    });
  });
}
