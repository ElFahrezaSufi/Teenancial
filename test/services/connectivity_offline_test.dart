import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:teenancial/screens/home_screen.dart';
import 'package:teenancial/services/connectivity_service.dart';
import 'package:teenancial/services/firestore_service.dart';
import 'package:teenancial/utils/error_mapper.dart';
import 'package:teenancial/widgets/common/custom_bottom_navbar.dart';
import 'package:teenancial/widgets/common/offline_banner.dart';

void main() {
  tearDown(() {
    ConnectivityService.instance.resetForTesting();
  });

  group('ConnectivityService, FirestoreService.ensureOnline & ErrorMapper', () {
    test('hasActiveInterface mendeteksi wifi/mobile aktif vs none/kosong', () {
      expect(
        ConnectivityService.hasActiveInterface([ConnectivityResult.wifi]),
        isTrue,
      );
      expect(
        ConnectivityService.hasActiveInterface([ConnectivityResult.mobile]),
        isTrue,
      );
      expect(
        ConnectivityService.hasActiveInterface([ConnectivityResult.none]),
        isFalse,
      );
      expect(ConnectivityService.hasActiveInterface(const []), isFalse);
    });

    test(
      'status offline/online & refreshStatus merespons probe jangkauan internet',
      () async {
        final service = ConnectivityService.instance;
        expect(service.isOffline, isFalse);

        service.markOfflineFromError();
        expect(service.isOffline, isTrue);
        expect(service.isUsingCachedData, isTrue);

        service.setTestState(reachabilityProbe: () async => true);
        final onlineNow = await service.refreshStatus();
        expect(onlineNow, isTrue);
        expect(service.isOffline, isFalse);
        expect(service.isUsingCachedData, isFalse);

        service.setTestState(reachabilityProbe: () async => false);
        final stillOnline = await service.refreshStatus();
        expect(stillOnline, isFalse);
        expect(service.isOffline, isTrue);
      },
    );

    test(
      'FirestoreService.ensureOnline melempar OfflineException saat offline dan lolos saat online',
      () {
        final service = ConnectivityService.instance;
        final fs = FirestoreService(connectivity: service);

        service.setTestState(isOffline: false);
        expect(() => fs.ensureOnline(actionLabel: 'menyimpan transaksi'), returnsNormally);

        service.setTestState(isOffline: true);
        expect(
          () => fs.ensureOnline(actionLabel: 'menyimpan transaksi'),
          throwsA(
            isA<OfflineException>().having(
              (e) => e.message,
              'message',
              contains('menyimpan transaksi'),
            ),
          ),
        );
      },
    );

    test('ErrorMapper memetakan OfflineException dan TimeoutException dengan ramah', () {
      expect(
        ErrorMapper.message(
          const OfflineException('Butuh internet untuk menyimpan dompet.'),
        ),
        'Butuh internet untuk menyimpan dompet.',
      );
      expect(
        ErrorMapper.message(TimeoutException('timed out')),
        contains('Koneksi internet lambat atau terputus'),
      );
    });
  });

  group('OfflineBanner Widget Test', () {
    testWidgets(
      'tampil saat offline, tersembunyi saat splash/online, dan tombol Cek menyegarkan status',
      (tester) async {
        final service = ConnectivityService.instance;
        service.setTestState(
          isOffline: true,
          reachabilityProbe: () async => true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  OfflineBanner(visible: true, connectivity: service),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Mode Offline'), findsOneWidget);
        expect(find.text('Cek'), findsOneWidget);

        // Tekan tombol Cek -> probe mengembalikan true -> banner hilang
        await tester.tap(find.text('Cek'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Mode Offline'), findsNothing);

        // Bila visible == false (misal saat SplashScreen), banner tetap tersembunyi meski offline
        service.setTestState(isOffline: true);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  OfflineBanner(visible: false, connectivity: service),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Mode Offline'), findsNothing);
      },
    );
  });

  group('ConnectivityService Auto-Recovery & Foreground Lifecycle', () {
    test(
      'memulihkan status online secara otomatis saat probe awal gagal lalu jaringan siap, dan tidak menjadwalkan timer saat antarmuka mati',
      () async {
        final service = ConnectivityService.instance;
        int probeCount = 0;

        service.setTestState(
          hasActiveInterface: true,
          autoRecoveryEnabled: true,
          recoveryDelays: const [
            Duration(milliseconds: 25),
            Duration(milliseconds: 25),
          ],
          reachabilityProbe: () async {
            probeCount++;
            return probeCount >= 2;
          },
        );

        service.markOfflineFromError();
        expect(service.isOffline, isTrue);
        expect(service.hasPendingRecoveryRetry, isTrue);

        // Tunggu 2 siklus singkat (percobaan 1 gagal -> percobaan 2 sukses)
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(probeCount, greaterThanOrEqualTo(2));
        expect(service.isOffline, isFalse);
        expect(service.hasPendingRecoveryRetry, isFalse);

        // Bila interface mati total (airplane mode), timer retry tidak dipasang
        service.setTestState(hasActiveInterface: false);
        service.markOfflineFromError();
        expect(service.isOffline, isTrue);
        expect(service.hasPendingRecoveryRetry, isFalse);
      },
    );

    test(
      'menjeda timer auto-recovery saat ke background dan langsung cek ulang saat resume',
      () async {
        final service = ConnectivityService.instance;
        bool reachable = false;

        service.setTestState(
          hasActiveInterface: true,
          autoRecoveryEnabled: true,
          recoveryDelays: const [Duration(seconds: 30)],
          reachabilityProbe: () async => reachable,
        );

        service.markOfflineFromError();
        expect(service.hasPendingRecoveryRetry, isTrue);

        // Pindah ke background -> timer harus dibatalkan
        service.setAppForeground(false);
        expect(service.hasPendingRecoveryRetry, isFalse);

        // Jaringan kembali pulih lalu user kembali membuka aplikasi (resumed)
        reachable = true;
        service.setAppForeground(true);
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(service.isOffline, isFalse);
        expect(service.hasPendingRecoveryRetry, isFalse);
      },
    );
  });

  group('HomeScreen Feen Position Bounds (Anti-Overlap Bottom Navbar)', () {
    test(
      'computeFeenBounds selalu menempatkan tombol Feen di atas navbar baik saat online maupun saat OfflineBanner menyusutkan viewport',
      () {
        // Simulasi layar normal online (tinggi penuh 870, bottom navbar 125)
        final onlineBounds = HomeScreen.computeFeenBounds(
          viewportWidth: 412,
          viewportHeight: 870,
          topPadding: 44,
          bottomPadding: 125,
        );
        expect(
          onlineBounds.defaultY + HomeScreen.feenButtonHeight,
          lessThan(870 - 125),
        );
        expect(onlineBounds.minY, greaterThanOrEqualTo(44));

        // Simulasi OfflineBanner muncul (viewport menyusut ~95px jadi 775)
        final offlineBounds = HomeScreen.computeFeenBounds(
          viewportWidth: 412,
          viewportHeight: 775,
          topPadding: 0,
          bottomPadding: 125,
        );
        expect(
          offlineBounds.defaultY + HomeScreen.feenButtonHeight,
          lessThan(775 - 125),
        );
        expect(offlineBounds.defaultY, lessThan(onlineBounds.defaultY));

        // Simulasi layar sangat sempit/pendek tidak pernah melempar RangeError
        final tinyBounds = HomeScreen.computeFeenBounds(
          viewportWidth: 100,
          viewportHeight: 150,
          topPadding: 40,
          bottomPadding: 125,
        );
        expect(tinyBounds.maxX, greaterThanOrEqualTo(tinyBounds.minX));
        expect(tinyBounds.maxY, greaterThanOrEqualTo(tinyBounds.minY));
      },
    );

    testWidgets(
      'posisi Feen tetap berada di atas CustomBottomNavBar saat OfflineBanner tampil maupun tersembunyi',
      (tester) async {
        tester.view.physicalSize = const Size(520, 870);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final service = ConnectivityService.instance;
        service.setTestState(isOffline: true);
        double? lastLocalTop;

        Widget buildShell() {
          return MaterialApp(
            home: Column(
              children: [
                OfflineBanner(visible: true, connectivity: service),
                Expanded(
                  child: Scaffold(
                    bottomNavigationBar: CustomBottomNavBar(
                      selectedIndex: 0,
                      onItemTapped: (_) {},
                    ),
                    body: LayoutBuilder(
                      builder: (context, constraints) {
                        final pad = MediaQuery.paddingOf(context);
                        final bounds = HomeScreen.computeFeenBounds(
                          viewportWidth: constraints.maxWidth,
                          viewportHeight: constraints.maxHeight,
                          topPadding: pad.top,
                          bottomPadding: pad.bottom,
                        );
                        lastLocalTop = bounds.defaultY;
                        return Stack(
                          children: [
                            Positioned(
                              left: bounds.defaultX,
                              top: bounds.defaultY,
                              child: const SizedBox(
                                key: Key('mock_feen_fab'),
                                width: HomeScreen.feenButtonWidth,
                                height: HomeScreen.feenButtonHeight,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        await tester.pumpWidget(buildShell());
        await tester.pumpAndSettle();

        // Saat OfflineBanner tampil, sisi bawah Feen harus strictly di atas sisi atas Navbar
        final localTopOffline = lastLocalTop!;
        final feenRectOffline =
            tester.getRect(find.byKey(const Key('mock_feen_fab')));
        final navRectOffline =
            tester.getRect(find.byType(CustomBottomNavBar));
        expect(feenRectOffline.bottom, lessThan(navRectOffline.top));

        // Saat koneksi kembali online dan OfflineBanner hilang, Feen tetap di atas Navbar
        service.setTestState(isOffline: false);
        await tester.pumpAndSettle();

        final localTopOnline = lastLocalTop!;
        final feenRectOnline =
            tester.getRect(find.byKey(const Key('mock_feen_fab')));
        final navRectOnline =
            tester.getRect(find.byType(CustomBottomNavBar));
        expect(feenRectOnline.bottom, lessThan(navRectOnline.top));
        // Koordinat lokal top di HomeScreen menyesuaikan tinggi viewport,
        // sehingga posisi global Feen tetap stabil tepat di atas navbar.
        expect(localTopOnline, greaterThan(localTopOffline));
        expect(feenRectOnline.top, closeTo(feenRectOffline.top, 0.5));
      },
    );
  });
}
