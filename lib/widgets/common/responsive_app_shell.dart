import 'package:material_ui/material_ui.dart';
import '../../theme/app_colors.dart';

/// Pembungkus responsif tingkat aplikasi untuk seluruh halaman Teenancial.
///
/// - Menjaga skala font aksesibilitas pada rentang aman (`0.85x` sampai `1.25x`)
///   agar teks tetap terbaca baik tanpa memecahkan tata letak kartu/tombol.
/// - Pada ponsel (`lebar <= 600 dp`), tidak mengubah dimensi tampilan sama
///   sekali sehingga desain tetap identik 100%.
/// - Pada tablet, foldable terbuka, atau jendela lebar (`lebar > 600 dp`),
///   memusatkan tampilan di dalam bingkai proporsional (`maxWidth: 540 dp`)
///   agar elemen tidak melar berlebihan.
class ResponsiveAppShell extends StatelessWidget {
  static const double tabletBreakpoint = 600.0;
  static const double maxContentWidth = 540.0;
  static const double minTextScaleFactor = 0.85;
  static const double maxTextScaleFactor = 1.25;

  final Widget child;

  const ResponsiveAppShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final clampedTextScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: minTextScaleFactor,
      maxScaleFactor: maxTextScaleFactor,
    );

    if (mediaQuery.size.width <= tabletBreakpoint) {
      return MediaQuery(
        data: mediaQuery.copyWith(textScaler: clampedTextScaler),
        child: child,
      );
    }

    final constrainedMediaQuery = mediaQuery.copyWith(
      size: Size(maxContentWidth, mediaQuery.size.height),
      textScaler: clampedTextScaler,
    );

    return ColoredBox(
      color: scaffoldBg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scaffoldBg,
              border: Border.symmetric(
                vertical: BorderSide(
                  color: primaryGreen.withValues(alpha: 0.14),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryGreen.withValues(alpha: 0.08),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRect(
              child: MediaQuery(
                data: constrainedMediaQuery,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
