import 'package:material_ui/material_ui.dart';
import '../../services/connectivity_service.dart';
import '../../theme/app_colors.dart';

/// Strip indikator global yang muncul di bagian atas layar saat perangkat
/// sedang dalam mode offline (Dukungan Offline Tingkatan A).
class OfflineBanner extends StatelessWidget {
  final bool visible;
  final ConnectivityService? connectivity;

  const OfflineBanner({
    super.key,
    this.visible = true,
    this.connectivity,
  });

  @override
  Widget build(BuildContext context) {
    final service = connectivity ?? ConnectivityService.instance;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final bool shouldShow = visible && service.isOffline;

        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: shouldShow
              ? Material(
                  color: const Color(0xFFFFF6DC),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF6DC),
                      border: Border(
                        bottom: BorderSide(
                          color: primaryGreen.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.wifi_off_rounded,
                              color: orangeText,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Mode Offline: data dari cache. Ubah/simpan data butuh internet.',
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontSize: 11.5,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 28,
                              child: OutlinedButton(
                                onPressed: service.isChecking
                                    ? null
                                    : () => service.refreshStatus(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primaryGreen,
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: primaryGreen,
                                    width: 1,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  minimumSize: const Size(48, 28),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                ),
                                child: service.isChecking
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: primaryGreen,
                                        ),
                                      )
                                    : const Text(
                                        'Cek',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}
