import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:teenancial/config/app_routes.dart';
import 'package:teenancial/models/dompet_model.dart';
import 'package:teenancial/models/target_model.dart';
import 'package:teenancial/models/transaction_model.dart';
import 'package:teenancial/models/user_model.dart';
import 'package:teenancial/providers/dompet_provider.dart';
import 'package:teenancial/providers/mission_provider.dart';
import 'package:teenancial/providers/target_provider.dart';
import 'package:teenancial/providers/transaction_provider.dart';
import 'package:teenancial/providers/user_provider.dart';
import 'package:teenancial/repositories/dompet_repository.dart';
import 'package:teenancial/repositories/target_repository.dart';
import 'package:teenancial/repositories/transaction_repository.dart';
import 'package:teenancial/repositories/user_repository.dart';
import 'package:teenancial/screens/laporan_screen.dart';
import 'package:teenancial/screens/misi_screen.dart';
import 'package:teenancial/screens/target_menabung_screen.dart';
import 'package:teenancial/widgets/common/app_fallback_views.dart';
import 'package:teenancial/widgets/common/async_state_view.dart';
import 'package:teenancial/widgets/common/user_avatar_with_frame.dart';

class _StubUserRepo extends UserRepository {
  final UserModel profile;
  _StubUserRepo(this.profile);

  @override
  Future<UserModel> getUserProfile(String uid) async => profile;
}

class _StubDompetRepo extends DompetRepository {
  @override
  Future<List<DompetItem>> getDompets(String uid) async => const [];
}

class _ToggleFailTargetRepo extends TargetRepository {
  bool shouldFail = true;

  @override
  Future<List<TargetItem>> getTargets(String uid) async {
    if (shouldFail) {
      throw Exception('Simulasi server target gagal');
    }
    return [
      TargetItem(
        id: 't1',
        nama: 'Sepeda Baru',
        imageUrl: '',
        targetAmount: 1000000,
        savedAmount: 250000,
        isPinned: true,
      ),
    ];
  }

  @override
  Future<void> togglePinTarget({
    required String uid,
    required String targetId,
    required bool shouldPin,
  }) async {}
}

class _ToggleFailTransactionRepo extends TransactionRepository {
  bool shouldFail = true;

  @override
  Future<List<TransactionModel>> getTransactions(String uid) async {
    if (shouldFail) {
      throw Exception('Simulasi server transaksi gagal');
    }
    return const [];
  }
}

/// ImageProvider tiruan yang selalu gagal memuat (simulasi URL 404 / offline).
class _FailingImageProvider extends ImageProvider<_FailingImageProvider> {
  const _FailingImageProvider();

  @override
  Future<_FailingImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_FailingImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _FailingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      Future<ImageInfo>.error(Exception('HTTP 404 Not Found')),
    );
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('Global & Routing Fallbacks (404, Error Boundary, Startup)', () {
    testWidgets(
      'GoRouter errorBuilder menampilkan NotFoundScreen 404 dan tombol Kembali ke Beranda berpindah ke /home',
      (WidgetTester tester) async {
        final router = GoRouter(
          initialLocation: '/rute-tidak-dikenal-xyz',
          errorBuilder: (context, state) => NotFoundScreen(
            location: state.uri.toString(),
          ),
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (_, __) => const Scaffold(
                body: Center(child: Text('Halaman Beranda Dummy')),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(find.text('404'), findsOneWidget);
        expect(find.text('Halaman Tidak Ditemukan'), findsOneWidget);
        expect(find.text('Kembali ke Beranda'), findsOneWidget);

        await tester.tap(find.text('Kembali ke Beranda'));
        await tester.pumpAndSettle();

        expect(find.text('Halaman Beranda Dummy'), findsOneWidget);
      },
    );

    testWidgets(
      'RenderErrorFallbackView merender aman tanpa ancestor MaterialApp atau Provider',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          RenderErrorFallbackView(
            details: FlutterErrorDetails(exception: StateError('Simulasi bug')),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Tampilan Sedang Bermasalah'), findsOneWidget);
      },
    );

    testWidgets(
      'StartupErrorApp menampilkan pesan error dan memanggil onRetry saat Coba Lagi ditekan',
      (WidgetTester tester) async {
        int retryCount = 0;

        await tester.pumpWidget(
          StartupErrorApp(
            errorMessage: 'Layanan Firebase belum siap.',
            onRetry: () async {
              retryCount++;
            },
          ),
        );
        await tester.pump();

        expect(find.text('Gagal Memulai Aplikasi'), findsOneWidget);
        expect(find.text('Layanan Firebase belum siap.'), findsOneWidget);

        await tester.tap(find.text('Coba Lagi'));
        await tester.pump();

        expect(retryCount, 1);
      },
    );
  });

  group('Screen Error + Retry Fallbacks', () {
    testWidgets(
      'MisiScreen menampilkan ErrorStateView saat loadMissions gagal dan pulih setelah Coba Lagi',
      (WidgetTester tester) async {
        final userProvider = UserProvider(
          repository: _StubUserRepo(
            const UserModel(uid: 'u1', email: 'a@b.com', name: 'Rani'),
          ),
        );
        bool shouldFail = true;
        final missionProvider = MissionProvider(
          onLoad: (_) async {
            if (shouldFail) throw Exception('Server misi gangguan');
            return <String, dynamic>{};
          },
          onSave: (_, __) async {},
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

        expect(find.byType(ErrorStateView), findsOneWidget);
        expect(find.text('Coba Lagi'), findsOneWidget);

        shouldFail = false;
        await tester.tap(find.text('Coba Lagi'));
        await tester.pumpAndSettle();

        expect(find.byType(ErrorStateView), findsNothing);
        expect(find.text('Catat Keuangan Hari Ini'), findsOneWidget);
      },
    );

    testWidgets(
      'TargetMenabungScreen menampilkan ErrorStateView saat gagal memuat target dan pulih setelah Coba Lagi',
      (WidgetTester tester) async {
        final userProvider = UserProvider(
          repository: _StubUserRepo(
            const UserModel(uid: 'u1', email: 'a@b.com', name: 'Rani'),
          ),
        );
        final dompetProvider = DompetProvider(repository: _StubDompetRepo());
        final missionProvider = MissionProvider(
          onLoad: (_) async => <String, dynamic>{},
          onSave: (_, __) async {},
        );
        final txProvider = TransactionProvider(
          repository: _ToggleFailTransactionRepo()..shouldFail = false,
        );
        final targetRepo = _ToggleFailTargetRepo();
        final targetProvider = TargetProvider(repository: targetRepo);

        await tester.runAsync(() async {
          userProvider.updateUser('u1');
          dompetProvider.updateUser('u1');
          missionProvider.bindDependencies('u1', userProvider);
          txProvider.bindDependencies('u1', dompetProvider, missionProvider);
          targetProvider.bindDependencies('u1', missionProvider);
          await Future<void>.delayed(Duration.zero);
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<UserProvider>.value(value: userProvider),
              ChangeNotifierProvider<DompetProvider>.value(
                value: dompetProvider,
              ),
              ChangeNotifierProvider<TransactionProvider>.value(
                value: txProvider,
              ),
              ChangeNotifierProvider<TargetProvider>.value(
                value: targetProvider,
              ),
            ],
            child: const MaterialApp(home: TargetMenabungScreen()),
          ),
        );
        await tester.pump();

        expect(find.byType(ErrorStateView), findsOneWidget);
        expect(find.text('Belum ada target impian nih!'), findsNothing);

        targetRepo.shouldFail = false;
        await tester.tap(find.text('Coba Lagi'));
        await tester.pumpAndSettle();

        expect(find.byType(ErrorStateView), findsNothing);
        expect(find.text('Sepeda Baru'), findsOneWidget);
      },
    );

    testWidgets(
      'LaporanScreen menampilkan ErrorStateView saat transaksi gagal dimuat dan pulih setelah Coba Lagi',
      (WidgetTester tester) async {
        final dompetProvider = DompetProvider(repository: _StubDompetRepo());
        final missionProvider = MissionProvider(
          onLoad: (_) async => <String, dynamic>{},
          onSave: (_, __) async {},
        );
        final txRepo = _ToggleFailTransactionRepo();
        final txProvider = TransactionProvider(repository: txRepo);

        await tester.runAsync(() async {
          dompetProvider.updateUser('u1');
          txProvider.bindDependencies('u1', dompetProvider, missionProvider);
          await Future<void>.delayed(Duration.zero);
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<TransactionProvider>.value(
                value: txProvider,
              ),
            ],
            child: const MaterialApp(home: LaporanScreen()),
          ),
        );
        await tester.pump();

        expect(find.byType(ErrorStateView), findsOneWidget);

        txRepo.shouldFail = false;
        await tester.tap(find.text('Coba Lagi'));
        await tester.pumpAndSettle();

        expect(find.byType(ErrorStateView), findsNothing);
        expect(find.text('Selisih Bersih'), findsOneWidget);
      },
    );
  });

  group('Avatar Network Error Fallback', () {
    testWidgets(
      'UserAvatarWithFrame kembali ke ikon Icons.person tanpa exception ketika gambar gagal dimuat',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: UserAvatarWithFrame(
                  avatarImage: _FailingImageProvider(),
                  frameId: 'frame_matcha',
                  size: 86,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.person), findsOneWidget);
      },
    );
  });
}
