import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../data/feen_catalog.dart';
import '../data/feen_knowledge_base.dart';
import '../models/feen_chat_model.dart';
import '../providers/belajar_provider.dart';
import '../providers/category_provider.dart';
import '../providers/dompet_provider.dart';
import '../providers/feen_chat_provider.dart';
import '../providers/mission_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/target_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../utils/feen_context_builder.dart';
import '../widgets/feen/feen_avatar.dart';
import '../widgets/feen/feen_markdown_text.dart';
import '../widgets/feen/feen_personalization_sheet.dart';
import '../widgets/feen/feen_session_sheet.dart';

class TanyaFeenScreen extends StatefulWidget {
  final String? initialPrompt;
  final bool startNewSession;

  const TanyaFeenScreen({
    super.key,
    this.initialPrompt,
    this.startNewSession = false,
  });

  @override
  State<TanyaFeenScreen> createState() => _TanyaFeenScreenState();
}

class _TanyaFeenScreenState extends State<TanyaFeenScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _didInit = false;
  bool _dismissedPersonalizationBanner = false;
  int _lastObservedMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _chatController.addListener(_onInputChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeScreen());
  }

  @override
  void dispose() {
    _chatController.removeListener(_onInputChanged);
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeScreen() async {
    if (!mounted || _didInit) return;
    _didInit = true;

    final chatProvider = context.read<FeenChatProvider>();
    final hasInitialPrompt =
        widget.initialPrompt != null && widget.initialPrompt!.trim().isNotEmpty;

    if (widget.startNewSession || hasInitialPrompt) {
      chatProvider.startNewSession();
    } else if (chatProvider.sessions.isEmpty && !chatProvider.isLoadingSessions) {
      await chatProvider.loadSessions();
    }

    if (hasInitialPrompt && mounted) {
      await _handleSend(customPrompt: widget.initialPrompt!.trim());
    }
  }

  FeenLiveSnapshot _buildLiveSnapshot() {
    final userProvider = context.read<UserProvider>();
    final dompetProvider = context.read<DompetProvider>();
    final txProvider = context.read<TransactionProvider>();
    final targetProvider = context.read<TargetProvider>();
    final belajarProvider = context.read<BelajarProvider>();
    final missionProvider = context.read<MissionProvider>();
    final recurringProvider = Provider.of<RecurringProvider?>(
      context,
      listen: false,
    );
    final categoryProvider = Provider.of<CategoryProvider?>(
      context,
      listen: false,
    );

    return FeenLiveSnapshot.fromProviders(
      userProvider: userProvider,
      dompetProvider: dompetProvider,
      transactionProvider: txProvider,
      targetProvider: targetProvider,
      belajarProvider: belajarProvider,
      missionProvider: missionProvider,
      recurringProvider: recurringProvider,
      categoryProvider: categoryProvider,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _handleSend({String? customPrompt}) async {
    final chatProvider = context.read<FeenChatProvider>();
    if (chatProvider.isSending) return;

    final text = (customPrompt ?? _chatController.text).trim();
    if (text.isEmpty) return;

    final isFromField = customPrompt == null;
    final previousFieldText = _chatController.text;
    if (isFromField) {
      _chatController.clear();
    }

    _scrollToBottom();
    final ok = await chatProvider.sendMessage(
      text: text,
      snapshot: _buildLiveSnapshot(),
    );

    if (!mounted) return;
    // Jika ditahan oleh guard validasi/offline sebelum masuk proses kirim
    // (pendingFailedPrompt == null), kembalikan ketikan agar user tidak kehilangan teks.
    if (!ok && isFromField && chatProvider.pendingFailedPrompt == null) {
      _chatController.text = previousFieldText;
      _chatController.selection = TextSelection.collapsed(
        offset: previousFieldText.length,
      );
    }
    _scrollToBottom();
  }

  Future<void> _handleRetry() async {
    final chatProvider = context.read<FeenChatProvider>();
    if (chatProvider.isSending) return;
    _scrollToBottom();
    await chatProvider.retryLastMessage(_buildLiveSnapshot());
    if (mounted) _scrollToBottom();
  }

  void _navigateToRoute(String route) {
    const shellRoutes = {
      AppRoutes.home,
      AppRoutes.dompet,
      AppRoutes.riwayat,
      AppRoutes.profile,
    };
    if (shellRoutes.contains(route)) {
      context.go(route);
    } else {
      context.push(route);
    }
  }

  void _showSessionSheet() {
    final parentMessenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Consumer2<FeenChatProvider, UserProvider>(
        builder: (_, chat, user, __) => FeenSessionSheet(
          sessions: chat.sessions,
          activeSessionId: chat.activeSessionId,
          userLevel: user.level,
          feenEquipped: user.feenEquipped,
          onStartNewSession: () => chat.startNewSession(),
          onSelectSession: (session) => chat.selectSession(session.id),
          onDeleteSession: (session) => chat.deleteSession(session.id),
          onAllSessionsDeleted: () {
            parentMessenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Riwayat obrolan berhasil dihapus.'),
                  backgroundColor: primaryGreen,
                ),
              );
          },
        ),
      ),
    );
  }

  Future<void> _showPersonalizationSheet() async {
    final user = context.read<UserProvider>();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FeenPersonalizationSheet(
        initialOccupation: user.occupationStatus,
        initialTone: user.feenTone,
        userLevel: user.level,
        feenEquipped: user.feenEquipped,
        onSave: (occupation, tone) => user.updatePersonalization(
          occupationStatus: occupation,
          feenTone: tone,
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Preferensi personalisasi Feen berhasil disimpan!'),
            backgroundColor: primaryGreen,
          ),
        );
    }
  }

  void _showFeenMenu() {
    final user = context.read<UserProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.only(top: 2),
          decoration: const BoxDecoration(
            color: primaryGreen,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 1, left: 1, right: 1),
            child: Container(
              decoration: const BoxDecoration(
                color: appBarBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
              ),
              child: SafeArea(
                top: false,
                child: Material(
                  color: Colors.transparent,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
                          child: Row(
                            children: [
                              FeenAvatar(
                                level: user.level,
                                equipped: user.feenEquipped,
                                size: 44,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Mau buka halaman apa?',
                                  style: TextStyle(
                                    color: primaryGreen,
                                    fontSize: 17,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(
                          color: primaryGreen,
                          height: 1,
                          thickness: 1,
                        ),
                        _buildMenuItem(
                          icon: Icons.history_rounded,
                          title: 'Riwayat',
                          subtitle: 'Semua transaksi dan arus kas kamu',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _navigateToRoute(AppRoutes.riwayat);
                          },
                        ),
                        const Divider(
                          color: primaryGreen,
                          height: 1,
                          thickness: 1,
                        ),
                        _buildMenuItem(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'Dompet',
                          subtitle: 'Saldo tunai, rekening, dan kartu',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _navigateToRoute(AppRoutes.dompet);
                          },
                        ),
                        const Divider(
                          color: primaryGreen,
                          height: 1,
                          thickness: 1,
                        ),
                        _buildMenuItem(
                          icon: Icons.track_changes_rounded,
                          title: 'Target Menabung',
                          subtitle: 'Progres tabungan dan tenggat impian',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _navigateToRoute(AppRoutes.targetMenabung);
                          },
                        ),
                        const Divider(
                          color: primaryGreen,
                          height: 1,
                          thickness: 1,
                        ),
                        _buildMenuItem(
                          icon: Icons.pie_chart_outline_rounded,
                          title: 'Laporan Keuangan',
                          subtitle: 'Grafik kategori, tren 6 bulan, dan wawasan',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _navigateToRoute(AppRoutes.laporan);
                          },
                        ),
                        const Divider(
                          color: primaryGreen,
                          height: 1,
                          thickness: 1,
                        ),
                        _buildMenuItem(
                          icon: Icons.menu_book_rounded,
                          title: 'Ruang Belajar',
                          subtitle: 'Materi literasi keuangan dan kuis XP',
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _navigateToRoute(AppRoutes.ruangBelajar);
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF7FFE7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primaryGreen, width: 1),
        ),
        child: Icon(icon, color: primaryGreen),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: primaryGreen,
          fontSize: 15,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: primaryGreen.withValues(alpha: 0.78),
          fontSize: 12,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: primaryGreen,
        size: 15,
      ),
      onTap: onTap,
    );
  }

  Widget _buildUserBubble(FeenChatMessage message) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: message.isPending
                ? primaryGreen.withValues(alpha: 0.8)
                : primaryGreen,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            message.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeenBubble(
    UserProvider user, {
    required String text,
    FeenPose pose = FeenPose.normal,
    List<String> suggestedRoutes = const [],
    bool showCopyButton = true,
  }) {
    final shortcuts =
        FeenKnowledgeBase.shortcutActionsFromRoutes(suggestedRoutes);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FeenAvatar(
          level: user.level,
          pose: pose,
          equipped: user.feenEquipped,
          size: 42,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border.all(color: primaryGreen, width: 1.5),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FeenMarkdownText(
                      text: text,
                      baseStyle: const TextStyle(
                        color: primaryGreen,
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                      ),
                    ),
                    if (showCopyButton) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () async {
                            await Clipboard.setData(
                              ClipboardData(
                                text: FeenMarkdownText.toPlainText(text),
                              ),
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text('Jawaban Feen disalin.'),
                                  backgroundColor: primaryGreen,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 13,
                                  color: primaryGreen.withValues(alpha: 0.65),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Salin',
                                  style: TextStyle(
                                    color: primaryGreen.withValues(alpha: 0.65),
                                    fontSize: 11,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (shortcuts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final action in shortcuts)
                      InkWell(
                        borderRadius: BorderRadius.circular(100),
                        onTap: () => _navigateToRoute(action.route),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: primaryGreen.withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  action.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: primaryGreen,
                                    fontSize: 11,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 13,
                                color: primaryGreen,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypingBubble(UserProvider user) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FeenAvatar(
          level: user.level,
          pose: FeenPose.learning,
          equipped: user.feenEquipped,
          size: 42,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border.all(color: primaryGreen, width: 1.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FeenTypingDots(),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Feen sedang berpikir...',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 13,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionChips(List<String> suggestions, bool isSending) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in suggestions)
          InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: isSending ? null : () => _handleSend(customPrompt: label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: primaryGreen, width: 1),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: primaryGreen,
                  fontSize: 12,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildApiMissingBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: orangeText.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: orangeText.withValues(alpha: 0.6)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.key_off_rounded, color: orangeText, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'API key Gemini belum dipasang. Salin dart_defines.example.json menjadi dart_defines.json, isi GEMINI_API_KEY, lalu jalankan dengan --dart-define-from-file=dart_defines.json.',
              style: TextStyle(
                color: primaryGreen,
                fontSize: 11,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizationBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryGreen.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, color: primaryGreen, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Atur status & gaya bahasa Feen biar saran makin cocok.',
              style: TextStyle(
                color: primaryGreen,
                fontSize: 11,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          TextButton(
            onPressed: _showPersonalizationSheet,
            style: TextButton.styleFrom(
              foregroundColor: primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Atur',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: () => setState(() => _dismissedPersonalizationBanner = true),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: primaryGreen.withValues(alpha: 0.65),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(FeenChatProvider chatProvider) {
    final hasRetry = chatProvider.pendingFailedPrompt != null;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  chatProvider.errorMessage ?? 'Gagal menghubungi Feen.',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(100),
                onTap: chatProvider.clearError,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
          if (hasRetry) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: chatProvider.isSending ? null : _handleRetry,
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text(
                  'Coba Lagi',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final chat = context.watch<FeenChatProvider>();
    final dompet = context.watch<DompetProvider>();
    final tx = context.watch<TransactionProvider>();
    final target = context.watch<TargetProvider>();
    final belajar = context.watch<BelajarProvider>();
    final mission = context.watch<MissionProvider>();
    final recurring = Provider.of<RecurringProvider?>(context);
    final category = Provider.of<CategoryProvider?>(context);

    final liveSnapshot = FeenLiveSnapshot.fromProviders(
      userProvider: user,
      dompetProvider: dompet,
      transactionProvider: tx,
      targetProvider: target,
      belajarProvider: belajar,
      missionProvider: mission,
      recurringProvider: recurring,
      categoryProvider: category,
    );
    final smartSuggestions =
        FeenContextBuilder.buildSmartSuggestions(liveSnapshot);

    final totalCount = chat.messages.length + (chat.isSending ? 1 : 0);
    if (totalCount != _lastObservedMessageCount) {
      _lastObservedMessageCount = totalCount;
      _scrollToBottom();
    }

    final inputLen = _chatController.text.trim().length;
    final canSend = !chat.isSending && inputLen > 0;
    final isInitialLoading = (chat.isLoadingSessions || chat.isLoadingMessages) &&
        chat.messages.isEmpty;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            color: appBarBg,
            border: Border(
              bottom: BorderSide(color: primaryGreen, width: 1.5),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: IconButton(
                    tooltip: 'Kembali',
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: primaryGreen,
                      size: 20,
                    ),
                    onPressed: () => context.pop(),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FeenAvatar(
                            level: user.level,
                            equipped: user.feenEquipped,
                            size: 36,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Tanya Feen',
                            maxLines: 1,
                            style: TextStyle(
                              color: primaryGreen,
                              fontSize: 19,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Riwayat Obrolan',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.history_rounded,
                    color: primaryGreen,
                    size: 24,
                  ),
                  onPressed: _showSessionSheet,
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opsi Tanya Feen',
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: primaryGreen,
                    size: 24,
                  ),
                  color: appBarBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: primaryGreen, width: 1),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'new':
                        chat.startNewSession();
                        break;
                      case 'personalize':
                        _showPersonalizationSheet();
                        break;
                      case 'wardrobe':
                        context.push(AppRoutes.feenWardrobe);
                        break;
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(
                      value: 'new',
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_comment_outlined,
                            color: primaryGreen,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Obrolan Baru',
                            style: TextStyle(
                              color: primaryGreen,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'personalize',
                      child: Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            color: primaryGreen,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Personalisasi Feen',
                            style: TextStyle(
                              color: primaryGreen,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'wardrobe',
                      child: Row(
                        children: [
                          Icon(
                            Icons.checkroom_rounded,
                            color: primaryGreen,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Lemari Feen',
                            style: TextStyle(
                              color: primaryGreen,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: scaffoldBg,
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                'assets/images/bg_curve.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          Column(
            children: [
              if (!chat.isApiConfigured) _buildApiMissingBanner(),
              if (user.occupationStatus == null &&
                  !_dismissedPersonalizationBanner)
                _buildPersonalizationBanner(),
              Expanded(
                child: isInitialLoading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: primaryGreen),
                            SizedBox(height: 12),
                            Text(
                              'Memuat riwayat obrolan...',
                              style: TextStyle(
                                color: primaryGreen,
                                fontSize: 13,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                        children: [
                          if (chat.messages.isEmpty) ...[
                            _buildFeenBubble(
                              user,
                              text:
                                  'Hai **${user.displayName}**! Aku Feen, teman keuanganmu. '
                                  'Mau bahas saldo, evaluasi pengeluaran, strategi target menabung, atau materi belajar hari ini?',
                              showCopyButton: false,
                            ),
                            const SizedBox(height: 14),
                            Padding(
                              padding: const EdgeInsets.only(left: 50),
                              child: _buildSuggestionChips(
                                smartSuggestions,
                                chat.isSending,
                              ),
                            ),
                          ] else ...[
                            for (int i = 0; i < chat.messages.length; i++) ...[
                              if (chat.messages[i].isUser)
                                _buildUserBubble(chat.messages[i])
                              else
                                _buildFeenBubble(
                                  user,
                                  text: chat.messages[i].text,
                                  pose: chat.messages[i].pose,
                                  suggestedRoutes:
                                      chat.messages[i].suggestedRoutes,
                                ),
                              if (i < chat.messages.length - 1)
                                const SizedBox(height: 14),
                            ],
                          ],
                          if (chat.isSending) ...[
                            const SizedBox(height: 14),
                            _buildTypingBubble(user),
                          ],
                          if (chat.errorMessage != null)
                            _buildErrorBanner(chat),
                        ],
                      ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: appBarBg,
                  border: Border(
                    top: BorderSide(color: primaryGreen, width: 1.5),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_chatController.text.length > 400)
                        Padding(
                          padding: const EdgeInsets.only(right: 12, bottom: 4),
                          child: Text(
                            '${_chatController.text.length}/${FeenChatProvider.maxInputLength}',
                            style: TextStyle(
                              color: _chatController.text.length >=
                                      FeenChatProvider.maxInputLength
                                  ? Colors.redAccent
                                  : primaryGreen.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FFE7),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: primaryGreen, width: 1.2),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: 'Pintasan Halaman',
                              icon: const Icon(
                                Icons.grid_view_rounded,
                                color: primaryGreen,
                              ),
                              onPressed: _showFeenMenu,
                            ),
                            Expanded(
                              child: TextField(
                                controller: _chatController,
                                enabled: !chat.isSending,
                                minLines: 1,
                                maxLines: 4,
                                maxLength: FeenChatProvider.maxInputLength,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _handleSend(),
                                style: const TextStyle(
                                  color: primaryGreen,
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: 'Tanya Feen soal keuanganmu...',
                                  hintStyle: TextStyle(
                                    color: primaryGreen.withValues(alpha: 0.5),
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: CircleAvatar(
                                backgroundColor: canSend
                                    ? primaryGreen
                                    : primaryGreen.withValues(alpha: 0.35),
                                child: chat.isSending
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : IconButton(
                                        tooltip: 'Kirim pesan',
                                        icon: const Icon(
                                          Icons.send_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        onPressed:
                                            canSend ? () => _handleSend() : null,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeenTypingDots extends StatefulWidget {
  const _FeenTypingDots();

  @override
  State<_FeenTypingDots> createState() => _FeenTypingDotsState();
}

class _FeenTypingDotsState extends State<_FeenTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(3, (index) {
            final phase = (_controller.value * 3 - index) % 3;
            final active = phase >= 0 && phase < 1;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: primaryGreen.withValues(alpha: active ? 0.95 : 0.3),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
