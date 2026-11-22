import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:teenancial/services/connectivity_service.dart';
import 'package:teenancial/services/firestore_service.dart';
import 'package:teenancial/utils/error_mapper.dart';
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
}
