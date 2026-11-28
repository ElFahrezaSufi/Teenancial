import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:teenancial/models/target_model.dart';
import 'package:teenancial/models/user_model.dart';
import 'package:teenancial/providers/user_provider.dart';
import 'package:teenancial/repositories/user_repository.dart';
import 'package:teenancial/screens/feen_wardrobe_screen.dart';
import 'package:teenancial/screens/get_started.dart';
import 'package:teenancial/screens/signup_screen.dart';
import 'package:teenancial/utils/currency_formatter.dart';
import 'package:teenancial/utils/xp_helper.dart';
import 'package:teenancial/widgets/common/custom_bottom_navbar.dart';
import 'package:teenancial/widgets/common/responsive_app_shell.dart';
import 'package:teenancial/widgets/home/action_menu.dart';
import 'package:teenancial/widgets/home/section_header.dart';
import 'package:teenancial/widgets/home/target_menabung_home.dart';

class _StubUserRepo extends UserRepository {
  final UserModel profile;
  _StubUserRepo(this.profile);

  @override
  Future<UserModel> getUserProfile(String uid) async => profile;
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('ResponsiveAppShell', () {
    testWidgets(
      'pada ponsel (<= 600 dp) mempertahankan lebar penuh dan membatasi skala font 0.85x-1.25x',
      (WidgetTester tester) async {
        _setViewport(tester, const Size(360, 740));

        double? observedWidth;
        double? observedScale;

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 740),
                textScaler: TextScaler.linear(1.8),
              ),
              child: ResponsiveAppShell(
                child: Builder(
                  builder: (context) {
                    observedWidth = MediaQuery.sizeOf(context).width;
                    observedScale =
                        MediaQuery.textScalerOf(context).scale(10) / 10;
                    return const Scaffold(body: SizedBox.expand());
                  },
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(observedWidth, 360);
        expect(observedScale, closeTo(1.25, 0.001));
      },
    );

    testWidgets(
      'pada tablet (> 600 dp) memusatkan tampilan pada lebar maksimal 540 dp',
      (WidgetTester tester) async {
        _setViewport(tester, const Size(800, 1024));

        double? observedMediaWidth;
        const innerKey = Key('tablet_inner_box');

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(800, 1024)),
              child: ResponsiveAppShell(
                child: Builder(
                  builder: (context) {
                    observedMediaWidth = MediaQuery.sizeOf(context).width;
                    return const Scaffold(
                      body: SizedBox.expand(key: innerKey),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(observedMediaWidth, ResponsiveAppShell.maxContentWidth);
        expect(
          tester.getSize(find.byKey(innerKey)).width,
          ResponsiveAppShell.maxContentWidth,
        );
      },
    );
  });

  group('Layout Responsif Layar Sempit (320 dp) & Font 1.25x', () {
    testWidgets(
      'GetStarted bebas overflow di layar sempit/pendek 320x568 font 1.25x dan menjaga lebar tombol 310 di layar standar 412x915',
      (WidgetTester tester) async {
        _setViewport(tester, const Size(320, 568));

        await tester.pumpWidget(
          const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(1.25),
              ),
              child: GetStarted(),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Mulai'), findsOneWidget);

        // Pada HP standar 412x915, tombol tetap tampil pada lebar maksimal 310 dp
        tester.view.physicalSize = const Size(412, 915);
        await tester.pumpWidget(
          const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(412, 915)),
              child: GetStarted(),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        final buttonRect = tester.getRect(
          find.ancestor(
            of: find.text('Mulai'),
            matching: find.byType(Stack),
          ).first,
        );
        expect(buttonRect.width, closeTo(310, 0.5));
      },
    );

    testWidgets(
      'CustomBottomNavBar bebas overflow di 320x640 dengan font 1.25x dan merespons tap',
      (WidgetTester tester) async {
        _setViewport(tester, const Size(320, 640));
        int tappedIndex = -1;

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.25),
              ),
              child: Scaffold(
                bottomNavigationBar: CustomBottomNavBar(
                  selectedIndex: 0,
                  onItemTapped: (i) => tappedIndex = i,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Beranda'), findsOneWidget);
        expect(find.text('Dompet'), findsOneWidget);
        expect(find.text('Riwayat'), findsOneWidget);
        expect(find.text('Akun'), findsOneWidget);

        // Pastikan bottom navbar menempel penuh di tepi bawah layar (docked)
        final navRect = tester.getRect(find.byType(CustomBottomNavBar));
        expect(navRect.bottom, closeTo(640, 0.5));
        expect(navRect.width, closeTo(320, 0.5));

        await tester.tap(find.text('Riwayat'));
        expect(tappedIndex, 2);
      },
    );

    testWidgets(
      'Baris ActionMenu, SectionHeader, dan TargetMenabungHome bebas overflow di 320x640 font 1.25x dengan nominal besar',
      (WidgetTester tester) async {
        _setViewport(tester, const Size(320, 640));

        final target = TargetItem(
          id: 't1',
          nama: 'Laptop Kuliah & Coding Generasi Terbaru',
          imageUrl: '',
          targetAmount: 150000000,
          savedAmount: 99999999,
          deadline: DateTime.now().add(const Duration(days: 20)),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.25),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LayoutBuilder(
                        builder: (context, menuConstraints) {
                          final double circleSize =
                              ((menuConstraints.maxWidth - 24) / 4)
                                  .clamp(54.0, 72.0);
                          final double iconSize =
                              (circleSize * 0.5).clamp(27.0, 36.0);
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ActionMenu(
                                  assetPath: 'assets/images/pemasukan.svg',
                                  label: 'Pemasukan',
                                  circleSize: circleSize,
                                  iconSize: iconSize,
                                  onTap: () {},
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ActionMenu(
                                  assetPath: 'assets/images/pengeluaran.svg',
                                  label: 'Pengeluaran',
                                  circleSize: circleSize,
                                  iconSize: iconSize,
                                  onTap: () {},
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ActionMenu(
                                  assetPath: 'assets/images/pinjaman.svg',
                                  label: 'Pinjaman',
                                  circleSize: circleSize,
                                  iconSize: iconSize,
                                  onTap: () {},
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ActionMenu(
                                  assetPath: 'assets/images/transfer.png',
                                  label: 'Transfer',
                                  circleSize: circleSize,
                                  iconSize: iconSize,
                                  onTap: () {},
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      SectionHeader(
                        title: 'Target Menabung Impian Panjang',
                        actionText: 'Lihat Semua',
                        onActionTap: () {},
                      ),
                      const SizedBox(height: 12),
                      TargetMenabungHome(
                        currentTarget: target,
                        totalSaldoReal: 25000000,
                        formatRupiah: Formatters.rupiah,
                        onTambahTarget: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Pengeluaran'), findsOneWidget);
        expect(find.text('Lihat Semua'), findsOneWidget);
      },
    );

    testWidgets(
      'FeenWardrobeScreen bebas overflow di 320x640 font 1.25x dan adaptif menjadi 4 kolom di layar tablet',
      (WidgetTester tester) async {
        _setViewport(tester, const Size(320, 640));

        final userProvider = UserProvider(
          repository: _StubUserRepo(
            UserModel(
              uid: 'u1',
              email: 'teen@example.com',
              name: 'Rani',
              xp: XpHelper.totalXpForLevel(30),
              feenEquipped: const {'head': 'beanie', 'frame': 'frame_gold'},
            ),
          ),
        );
        await tester.runAsync(() async {
          userProvider.updateUser('u1');
          await Future<void>.delayed(Duration.zero);
        });

        await tester.pumpWidget(
          ChangeNotifierProvider<UserProvider>.value(
            value: userProvider,
            child: const MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(320, 640),
                  textScaler: TextScaler.linear(1.25),
                ),
                child: FeenWardrobeScreen(),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        final narrowGrid = tester.widget<GridView>(find.byType(GridView).first);
        final narrowDelegate =
            narrowGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(narrowDelegate.crossAxisCount, 3);

        // Buka di tablet 800x1024 dalam ResponsiveAppShell (lebar konten 540 -> grid >= 460 -> 4 kolom)
        tester.view.physicalSize = const Size(800, 1024);
        await tester.pumpWidget(
          ChangeNotifierProvider<UserProvider>.value(
            value: userProvider,
            child: const MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(size: Size(800, 1024)),
                child: ResponsiveAppShell(child: FeenWardrobeScreen()),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        final tabletGrid = tester.widget<GridView>(find.byType(GridView).first);
        final tabletDelegate =
            tabletGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(tabletDelegate.crossAxisCount, 4);
      },
    );

    testWidgets(
      'SignUpScreen hanya menampilkan Nama, Email, dan Password tanpa Umur/Jenis Kelamin serta bebas overflow di 320x640 font 1.25x',
      (WidgetTester tester) async {
        _setViewport(tester, const Size(320, 640));

        await tester.pumpWidget(
          const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.25),
              ),
              child: SignUpScreen(),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Nama Lengkap'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Konfirmasi Password'), findsOneWidget);
        expect(find.text('Umur'), findsNothing);
        expect(find.text('Jenis Kelamin'), findsNothing);
      },
    );
  });
}
