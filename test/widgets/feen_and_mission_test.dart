import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:teenancial/data/feen_catalog.dart';
import 'package:teenancial/models/mission_model.dart';
import 'package:teenancial/models/user_model.dart';
import 'package:teenancial/providers/mission_provider.dart';
import 'package:teenancial/providers/user_provider.dart';
import 'package:teenancial/repositories/user_repository.dart';
import 'package:teenancial/screens/feen_wardrobe_screen.dart';
import 'package:teenancial/screens/misi_screen.dart';
import 'package:teenancial/utils/xp_helper.dart';
import 'package:teenancial/widgets/common/user_avatar_with_frame.dart';
import 'package:teenancial/widgets/feen/feen_avatar.dart';
import 'package:teenancial/widgets/feen/feen_unlock_dialog.dart';
import 'package:teenancial/widgets/feen/level_roadmap_sheet.dart';

class _StubUserRepository extends UserRepository {
  UserModel profile;

  _StubUserRepository(this.profile);

  @override
  Future<UserModel> getUserProfile(String uid) async => profile;

  @override
  Future<void> incrementXp(String uid, int amount) async {
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

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('UserAvatarWithFrame', () {
    testWidgets(
      'merender avatar berbingkai secara presisi di dalam batas size x size tanpa overflow',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatarWithFrame(
                      key: Key('matcha_avatar'),
                      avatarImage: null,
                      frameId: 'frame_matcha',
                      size: 68,
                    ),
                    SizedBox(height: 12),
                    UserAvatarWithFrame(
                      key: Key('cloud_avatar'),
                      avatarImage: null,
                      frameId: 'frame_cloud',
                      size: 86,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byKey(const Key('matcha_avatar'))),
          const Size(68, 68),
        );
        expect(
          tester.getSize(find.byKey(const Key('cloud_avatar'))),
          const Size(86, 86),
        );
      },
    );
  });

  group('FeenWardrobeScreen', () {
    testWidgets(
      'menampilkan tahap evolusi Lv.1/15/30 dan tombol Lepas semua aksesoris menjaga bingkai tetap terpasang',
      (WidgetTester tester) async {
        final userRepo = _StubUserRepository(
          UserModel(
            uid: 'u1',
            email: 'teen@example.com',
            name: 'Rani',
            xp: XpHelper.totalXpForLevel(15),
            feenEquipped: const {'frame': 'frame_matcha'},
          ),
        );
        final userProvider = UserProvider(repository: userRepo);
        await tester.runAsync(() async {
          userProvider.updateUser('u1');
          await Future<void>.delayed(Duration.zero);
        });

        await tester.pumpWidget(
          ChangeNotifierProvider<UserProvider>.value(
            value: userProvider,
            child: const MaterialApp(home: FeenWardrobeScreen()),
          ),
        );
        await tester.pump();

        expect(find.text('Rookie (Lv.1)'), findsOneWidget);
        expect(find.text('Saver (Lv.15)'), findsOneWidget);
        expect(find.text('Pro (Lv.30)'), findsOneWidget);
        expect(find.text('Level 15  |  Feen Saver'), findsOneWidget);

        // Hanya bingkai yang terpasang -> tombol lepas aksesoris harus nonaktif
        final unequipButtonFinder = find.widgetWithText(
          TextButton,
          'Lepas semua aksesoris',
        );
        expect(
          tester.widget<TextButton>(unequipButtonFinder).onPressed,
          isNull,
        );

        // Pasang aksesoris kepala -> tombol aktif, lalu klik melepas aksesoris namun mempertahankan bingkai
        await userProvider.equipFeen(FeenSlot.head, 'beanie');
        await tester.pump();
        expect(
          tester.widget<TextButton>(unequipButtonFinder).onPressed,
          isNotNull,
        );

        await tester.tap(unequipButtonFinder);
        await tester.pump();

        expect(userProvider.feenEquipped, {'frame': 'frame_matcha'});
        expect(
          tester.widget<TextButton>(unequipButtonFinder).onPressed,
          isNull,
        );
      },
    );
  });

  group('LevelRoadmapSheet', () {
    testWidgets(
      'menampilkan milestone level 1, 15, dan 30 melalui modal bottom sheet tanpa menimpa locale aplikasi',
      (WidgetTester tester) async {
        final userRepo = _StubUserRepository(
          UserModel(
            uid: 'u1',
            email: 'teen@example.com',
            name: 'Rani',
            xp: XpHelper.totalXpForLevel(15),
          ),
        );
        final userProvider = UserProvider(repository: userRepo);
        await tester.runAsync(() async {
          userProvider.updateUser('u1');
          await Future<void>.delayed(Duration.zero);
        });

        await tester.pumpWidget(
          ChangeNotifierProvider<UserProvider>.value(
            value: userProvider,
            child: MaterialApp(
              locale: const Locale('id', 'ID'),
              supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showLevelRoadmapSheet(context),
                    child: const Text('Buka Peta'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Buka Peta'));
        await tester.pumpAndSettle();

        final sheetElement = tester.element(find.byType(LevelRoadmapSheet));
        expect(Localizations.localeOf(sheetElement), const Locale('id', 'ID'));
        expect(find.text('Peta Hadiah Level'), findsOneWidget);
        expect(find.text('Feen Rookie'), findsOneWidget);

        // Scroll ke bawah untuk memastikan evolusi Level 15 & Level 30 muncul
        final listFinder = find.byType(Scrollable).last;
        await tester.scrollUntilVisible(
          find.text('Feen Saver'),
          250,
          scrollable: listFinder,
        );
        expect(find.text('Level 15'), findsWidgets);
        expect(find.text('Feen Saver'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Feen Pro'),
          250,
          scrollable: listFinder,
        );
        expect(find.text('Level 30'), findsOneWidget);
        expect(find.text('Feen Pro'), findsOneWidget);
      },
    );
  });

  group('FeenUnlockDialog', () {
    testWidgets(
      'menampilkan preview UserAvatarWithFrame dan CTA Pasang Bingkai ketika hanya bingkai yang terbuka',
      (WidgetTester tester) async {
        final cloudFrame = feenById('frame_cloud')!;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showFeenUnlockDialog(
                    context,
                    level: 11,
                    unlocked: [cloudFrame],
                  ),
                  child: const Text('Tampilkan Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Tampilkan Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Bingkai profil baru terbuka:'), findsOneWidget);
        expect(find.text('Pasang Bingkai'), findsOneWidget);
        expect(find.byType(UserAvatarWithFrame), findsOneWidget);
        expect(find.byType(FeenAvatar), findsNothing);
      },
    );
  });

  group('MisiScreen', () {
    testWidgets(
      'menampilkan banner streak terputus adaptif dan tombol Klaim Semua saat lebih dari 1 misi siap diklaim',
      (WidgetTester tester) async {
        final fakeNow = DateTime(2026, 11, 5, 10, 0);
        final userRepo = _StubUserRepository(
          const UserModel(
            uid: 'u1',
            email: 'teen@example.com',
            name: 'Rani',
          ),
        );
        final userProvider = UserProvider(repository: userRepo);
        Map<String, dynamic>? storedDoc = {
          'streakCount': 4,
          'lastStreakDate': '2026-11-01',
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
        await tester.runAsync(() async {
          userProvider.updateUser('u1');
          await Future<void>.delayed(Duration.zero);
          missionProvider.bindDependencies('u1', userProvider);
          await Future<void>.delayed(Duration.zero);
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<UserProvider>.value(value: userProvider),
              ChangeNotifierProvider<MissionProvider>.value(
                value: missionProvider,
              ),
            ],
            child: const MaterialApp(home: MisiScreen()),
          ),
        );
        await tester.pump();

        expect(
          find.text(
            'Streak 4 harimu terputus. Selesaikan 1 misi harian hari ini untuk mulai membangun lagi.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Klaim Semua'), findsNothing);

        // Selesaikan 2 misi harian hari ini -> banner berubah apresiatif & tombol Klaim Semua muncul
        await missionProvider.recordTrigger(MissionTrigger.addIncomeExpense);
        await missionProvider.recordTrigger(MissionTrigger.saveTarget);
        await tester.pump();

        expect(
          find.text(
            'Streak 4 harimu sempat terputus. Bagus, kamu sudah mulai streak baru hari ini!',
          ),
          findsOneWidget,
        );
        expect(find.text('Klaim Semua (+45 XP)'), findsOneWidget);
      },
    );
  });
}
