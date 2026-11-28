import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../../models/feen_chat_model.dart';
import '../../theme/app_colors.dart';
import '../../utils/confirm_dialog.dart';
import '../../utils/date_helper.dart';
import '../../utils/error_mapper.dart';
import '../common/loading_overlay.dart';
import 'feen_avatar.dart';

/// Bottom sheet daftar riwayat sesi percakapan Tanya Feen lintas perangkat.
///
/// Dirender di dalam `Consumer<FeenChatProvider>` agar setiap penghapusan sesi
/// langsung memperbarui daftar dan badge `Aktif` secara real-time, dengan
/// feedback konfirmasi inline yang selalu terlihat di dalam sheet.
class FeenSessionSheet extends StatefulWidget {
  final List<FeenChatSession> sessions;
  final String? activeSessionId;
  final int userLevel;
  final Map<String, String> feenEquipped;
  final VoidCallback onStartNewSession;
  final ValueChanged<FeenChatSession> onSelectSession;
  final Future<void> Function(FeenChatSession session) onDeleteSession;
  final VoidCallback? onAllSessionsDeleted;

  const FeenSessionSheet({
    super.key,
    required this.sessions,
    required this.activeSessionId,
    required this.userLevel,
    required this.feenEquipped,
    required this.onStartNewSession,
    required this.onSelectSession,
    required this.onDeleteSession,
    this.onAllSessionsDeleted,
  });

  @override
  State<FeenSessionSheet> createState() => _FeenSessionSheetState();
}

class _FeenSessionSheetState extends State<FeenSessionSheet> {
  String? _feedbackMessage;
  bool _feedbackIsError = false;
  Timer? _feedbackTimer;

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _showInlineFeedback(String message, {bool isError = false}) {
    _feedbackTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _feedbackMessage = message;
      _feedbackIsError = isError;
    });
    _feedbackTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _feedbackMessage = null);
      }
    });
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    FeenChatSession session,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus Riwayat Obrolan?',
      message:
          'Obrolan "${session.title}" beserta seluruh pesannya akan dihapus permanen dari akunmu.',
      confirmLabel: 'Hapus',
    );
    if (!confirmed || !context.mounted) return;

    final bool wasLastSession = widget.sessions.length <= 1;

    try {
      await runWithLoadingDialog(
        context,
        message: 'Menghapus riwayat obrolan...',
        action: () => widget.onDeleteSession(session),
      );
      if (!context.mounted) return;

      if (wasLastSession || widget.sessions.isEmpty) {
        Navigator.pop(context);
        widget.onAllSessionsDeleted?.call();
      } else {
        _showInlineFeedback('Riwayat obrolan berhasil dihapus.');
      }
    } catch (e) {
      if (!context.mounted) return;
      _showInlineFeedback(
        'Gagal menghapus obrolan: ${ErrorMapper.message(e)}',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    final sessions = widget.sessions;
    final activeSessionId = widget.activeSessionId;

    return Container(
      margin: const EdgeInsets.only(top: 2),
      decoration: const BoxDecoration(
        color: primaryGreen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 1.5, left: 1.5, right: 1.5),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: const BoxDecoration(
            color: appBarBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.5)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: primaryGreen.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                  child: Row(
                    children: [
                      FeenAvatar(
                        level: widget.userLevel,
                        equipped: widget.feenEquipped,
                        size: 38,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Riwayat Obrolan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: primaryGreen,
                            fontSize: 17,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onStartNewSession();
                        },
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text(
                          'Baru',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: primaryGreen, height: 1, thickness: 1),
                if (_feedbackMessage != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _feedbackIsError
                          ? Colors.redAccent.withValues(alpha: 0.12)
                          : primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _feedbackIsError
                            ? Colors.redAccent.withValues(alpha: 0.5)
                            : primaryGreen.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _feedbackIsError
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 18,
                          color: _feedbackIsError
                              ? Colors.redAccent
                              : primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _feedbackMessage!,
                            style: TextStyle(
                              color: _feedbackIsError
                                  ? Colors.redAccent
                                  : primaryGreen,
                              fontSize: 12,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(100),
                          onTap: () {
                            _feedbackTimer?.cancel();
                            setState(() => _feedbackMessage = null);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: (_feedbackIsError
                                      ? Colors.redAccent
                                      : primaryGreen)
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 40,
                          color: primaryGreen.withValues(alpha: 0.45),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Belum ada riwayat obrolan tersimpan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: primaryGreen,
                            fontSize: 14,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mulai kirim pertanyaan ke Feen dan riwayatmu otomatis tersinkron ke akunmu.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: primaryGreen.withValues(alpha: 0.72),
                            fontSize: 12,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      itemCount: sessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final isActive = session.id == activeSessionId;
                        final dateStr = DateHelper.formatShort(session.updatedAt);

                        return Material(
                          color: isActive ? cardBg : scaffoldBg,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onSelectSession(session);
                            },
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isActive
                                      ? primaryGreen
                                      : primaryGreen.withValues(alpha: 0.25),
                                  width: isActive ? 1.8 : 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                session.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: primaryGreen,
                                                  fontSize: 14,
                                                  fontFamily: 'Inter',
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            if (isActive) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: primaryGreen,
                                                  borderRadius:
                                                      BorderRadius.circular(100),
                                                ),
                                                child: const Text(
                                                  'Aktif',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontFamily: 'Inter',
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (session
                                            .lastMessagePreview.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            session.lastMessagePreview,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: primaryGreen.withValues(
                                                alpha: 0.72,
                                              ),
                                              fontSize: 12,
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w500,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Text(
                                          '$dateStr, ${session.messageCount} pesan',
                                          style: TextStyle(
                                            color: primaryGreen.withValues(
                                              alpha: 0.6,
                                            ),
                                            fontSize: 11,
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Hapus obrolan',
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _confirmAndDelete(context, session),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
