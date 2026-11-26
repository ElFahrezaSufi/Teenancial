import 'package:material_ui/material_ui.dart';
import '../../theme/app_colors.dart';

/// Overlay loading bergaya Teenancial untuk membungkus halaman stateful saat
/// proses penulisan/penghapusan ke Firestore sedang berjalan, sekaligus
/// mencegah double-tap dan tombol back prematur.
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String message;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    this.message = 'Memproses...',
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isLoading,
      child: Stack(
        children: [
          child,
          if (isLoading)
            Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.28),
                  child: Center(
                    child: _LoadingDialogCard(message: message),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Menjalankan [action] asinkron sambil menampilkan dialog loading non-dismissible
/// yang aman terhadap `Navigator` (menggunakan `DialogRoute` + `removeRoute`
/// agar tidak pernah menutup rute halaman lain secara tidak sengaja).
Future<T> runWithLoadingDialog<T>(
  BuildContext context, {
  required Future<T> Function() action,
  String message = 'Memproses...',
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: _LoadingDialogCard(message: message),
        ),
      ),
    ),
  );

  navigator.push(route);
  try {
    return await action();
  } finally {
    if (route.isActive && navigator.mounted) {
      navigator.removeRoute(route);
    }
  }
}

class _LoadingDialogCard extends StatelessWidget {
  final String message;

  const _LoadingDialogCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryGreen, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: primaryGreen,
              strokeWidth: 2.6,
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                color: primaryGreen,
                fontSize: 13.5,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
