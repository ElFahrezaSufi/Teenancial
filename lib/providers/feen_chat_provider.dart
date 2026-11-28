import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/feen_knowledge_base.dart';
import '../models/feen_chat_model.dart';
import '../repositories/feen_chat_repository.dart';
import '../services/connectivity_service.dart';
import '../services/gemini_service.dart';
import '../utils/error_mapper.dart';
import '../utils/feen_context_builder.dart';

/// Mengelola sesi percakapan multi-sesi Tanya Feen, sinkronisasi Firestore,
/// jendela konteks 12 pesan terakhir, cooldown kirim, serta pemulihan error.
class FeenChatProvider extends ChangeNotifier {
  static const int maxHistoryMessagesForPrompt = 12;
  static const int maxInputLength = 500;
  static const Duration sendCooldown = Duration(seconds: 2);

  final FeenChatRepository _repository;
  final GeminiService _geminiService;
  final ConnectivityService _connectivity;
  final DateTime Function() _now;

  FeenChatProvider({
    FeenChatRepository? repository,
    GeminiService? geminiService,
    ConnectivityService? connectivity,
    DateTime Function()? clock,
  })  : _repository = repository ?? FeenChatRepository(),
        _geminiService = geminiService ?? GeminiService(),
        _connectivity = connectivity ?? ConnectivityService.instance,
        _now = clock ?? DateTime.now;

  String? _uid;
  List<FeenChatSession> _sessions = const [];
  String? _activeSessionId;
  List<FeenChatMessage> _messages = const [];

  bool _isLoadingSessions = false;
  bool _isLoadingMessages = false;
  bool _isSending = false;
  bool _isDeletingSession = false;
  bool _isNewDraftMode = false;

  String? _errorMessage;
  String? _pendingFailedPrompt;
  DateTime? _lastSendAt;

  List<FeenChatSession> get sessions => List<FeenChatSession>.unmodifiable(_sessions);
  String? get activeSessionId => _activeSessionId;
  List<FeenChatMessage> get messages => List<FeenChatMessage>.unmodifiable(_messages);

  FeenChatSession? get activeSession {
    final id = _activeSessionId;
    if (id == null) return null;
    for (final s in _sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  bool get isLoadingSessions => _isLoadingSessions;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isSending => _isSending;
  bool get isDeletingSession => _isDeletingSession;
  bool get isApiConfigured => _geminiService.isConfigured;
  String? get errorMessage => _errorMessage;
  String? get pendingFailedPrompt => _pendingFailedPrompt;

  void updateUser(String? newUid) {
    if (_uid == newUid) return;
    _uid = newUid;
    _sessions = const [];
    _activeSessionId = null;
    _messages = const [];
    _isLoadingSessions = false;
    _isLoadingMessages = false;
    _isSending = false;
    _isDeletingSession = false;
    _isNewDraftMode = false;
    _errorMessage = null;
    _pendingFailedPrompt = null;
    _lastSendAt = null;

    if (newUid == null) {
      Future.microtask(notifyListeners);
      return;
    }

    _isLoadingSessions = true;
    Future.microtask(() {
      if (_uid == newUid) {
        loadSessions();
      }
    });
  }

  Future<void> loadSessions({bool silent = false}) async {
    final targetUid = _uid;
    if (targetUid == null) return;

    if (!silent) {
      _isLoadingSessions = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final fetched = await _repository.getSessions(targetUid);
      if (_uid != targetUid) return;
      _sessions = fetched;

      final activeStillExists = _activeSessionId != null &&
          fetched.any((s) => s.id == _activeSessionId);

      if (!activeStillExists && !_isNewDraftMode) {
        if (fetched.isNotEmpty) {
          _activeSessionId = fetched.first.id;
          _isLoadingSessions = false;
          notifyListeners();
          await _loadMessagesForActiveSession(targetUid, fetched.first.id, silent: silent);
          return;
        } else {
          _activeSessionId = null;
          _messages = const [];
        }
      } else if (activeStillExists && !silent && _messages.isEmpty) {
        final activeId = _activeSessionId!;
        _isLoadingSessions = false;
        notifyListeners();
        await _loadMessagesForActiveSession(targetUid, activeId, silent: false);
        return;
      }

      _errorMessage = null;
    } catch (e) {
      if (_uid != targetUid) return;
      if (!silent) {
        _errorMessage = ErrorMapper.message(e);
      }
    } finally {
      if (_uid == targetUid) {
        _isLoadingSessions = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadMessagesForActiveSession(
    String targetUid,
    String sessionId, {
    bool silent = false,
  }) async {
    if (!silent) {
      _isLoadingMessages = true;
      notifyListeners();
    }

    try {
      final fetched = await _repository.getMessages(targetUid, sessionId);
      if (_uid != targetUid || _activeSessionId != sessionId) return;
      _messages = fetched;
      _errorMessage = null;
    } catch (e) {
      if (_uid != targetUid || _activeSessionId != sessionId) return;
      if (!silent) {
        _errorMessage = ErrorMapper.message(e);
      }
    } finally {
      if (_uid == targetUid && _activeSessionId == sessionId) {
        _isLoadingMessages = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectSession(String sessionId) async {
    final targetUid = _uid;
    if (targetUid == null || _isSending) return;
    if (_activeSessionId == sessionId && !_isNewDraftMode && _messages.isNotEmpty) {
      return;
    }

    _isNewDraftMode = false;
    _activeSessionId = sessionId;
    _messages = const [];
    _errorMessage = null;
    _pendingFailedPrompt = null;
    notifyListeners();

    await _loadMessagesForActiveSession(targetUid, sessionId);
  }

  void startNewSession() {
    if (_isSending) return;
    _isNewDraftMode = true;
    _activeSessionId = null;
    _messages = const [];
    _errorMessage = null;
    _pendingFailedPrompt = null;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null && _pendingFailedPrompt == null) return;
    _errorMessage = null;
    _pendingFailedPrompt = null;
    notifyListeners();
  }

  /// Mengirim pesan ke Gemini API dengan konteks live terbaru dan menyimpan
  /// pasangan pesan ke Firestore secara atomik.
  Future<bool> sendMessage({
    required String text,
    required FeenLiveSnapshot snapshot,
    bool bypassCooldown = false,
  }) async {
    final targetUid = _uid;
    if (targetUid == null) {
      _errorMessage = 'Sesi pengguna tidak ditemukan. Silakan masuk kembali.';
      notifyListeners();
      return false;
    }
    if (_isSending) return false;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    if (trimmed.length > maxInputLength) {
      _errorMessage =
          'Pesan terlalu panjang (maksimal $maxInputLength karakter). Ringkas sedikit lalu coba kirim lagi ya.';
      notifyListeners();
      return false;
    }

    if (_connectivity.isOffline) {
      _errorMessage =
          'Tidak ada koneksi internet. Hubungkan ke internet untuk mengobrol dengan Feen.';
      notifyListeners();
      return false;
    }

    if (!_geminiService.isConfigured) {
      _errorMessage =
          'API key Tanya Feen belum dikonfigurasi. Tambahkan GEMINI_API_KEY di file dart_defines.json lalu jalankan ulang aplikasi.';
      notifyListeners();
      return false;
    }

    final now = _now();
    if (!bypassCooldown && _lastSendAt != null) {
      final elapsed = now.difference(_lastSendAt!);
      if (elapsed < sendCooldown) {
        _errorMessage =
            'Tunggu sebentar sebelum mengirim pesan berikutnya ya.';
        notifyListeners();
        return false;
      }
    }

    // Ambil jendela 12 pesan terakhir SEBELUM pesan baru agar tidak terduplikasi.
    final committedMessages =
        _messages.where((m) => !m.isPending).toList(growable: false);
    final historyWindow = committedMessages.length > maxHistoryMessagesForPrompt
        ? committedMessages.sublist(
            committedMessages.length - maxHistoryMessagesForPrompt,
          )
        : committedMessages;

    final optimisticId = 'pending_${now.microsecondsSinceEpoch}';
    final optimisticUserMsg = FeenChatMessage(
      id: optimisticId,
      role: FeenMessageRole.user,
      text: trimmed,
      createdAt: now,
      isPending: true,
    );

    final sessionBeforeSend = activeSession;

    _isSending = true;
    _errorMessage = null;
    _pendingFailedPrompt = null;
    _lastSendAt = now;
    _messages = [...committedMessages, optimisticUserMsg];
    notifyListeners();

    try {
      final liveContext = FeenContextBuilder.buildContextBlock(snapshot);
      final systemPrompt = FeenKnowledgeBase.buildSystemPrompt(
        tone: snapshot.feenTone,
        occupationStatus: snapshot.occupationStatus,
        liveContextBlock: liveContext,
      );

      final replyText = await _geminiService.generateReply(
        systemPrompt: systemPrompt,
        history: historyWindow,
        userMessage: trimmed,
      );

      if (_uid != targetUid) return false;

      final pose = FeenKnowledgeBase.inferPose(trimmed, replyText);
      final routes = FeenKnowledgeBase.resolveSuggestedRoutes(
        trimmed,
        replyText,
      );

      try {
        final saved = await _repository.saveTurnAtomic(
          uid: targetUid,
          existingSession: sessionBeforeSend,
          userText: trimmed,
          modelText: replyText,
          pose: pose,
          suggestedRoutes: routes,
          now: now,
        );

        if (_uid != targetUid) return false;

        _activeSessionId = saved.session.id;
        _isNewDraftMode = false;
        _messages = [
          ...committedMessages,
          saved.userMessage,
          saved.modelMessage,
        ];
        _sessions = [
          saved.session,
          ..._sessions.where((s) => s.id != saved.session.id),
        ];
        _errorMessage = null;
      } catch (saveErr) {
        // Balasan Gemini sudah diterima; tetap tampilkan di layar walau gagal
        // tersimpan ke Firestore agar pengguna tidak kehilangan jawaban.
        if (_uid != targetUid) return false;
        final fallbackUser = optimisticUserMsg.copyWith(isPending: false);
        final fallbackModel = FeenChatMessage(
          id: 'local_${now.microsecondsSinceEpoch}',
          role: FeenMessageRole.model,
          text: replyText,
          createdAt: now.add(const Duration(milliseconds: 1)),
          pose: pose,
          suggestedRoutes: routes,
        );
        _messages = [...committedMessages, fallbackUser, fallbackModel];
        _errorMessage =
            'Jawaban diterima, namun belum tersimpan ke cloud: ${ErrorMapper.message(saveErr)}';
      }

      return true;
    } catch (e) {
      if (_uid != targetUid) return false;
      _messages = committedMessages;
      _pendingFailedPrompt = trimmed;
      _errorMessage = ErrorMapper.message(e);
      return false;
    } finally {
      if (_uid == targetUid) {
        _isSending = false;
        notifyListeners();
      }
    }
  }

  Future<bool> retryLastMessage(FeenLiveSnapshot snapshot) async {
    final prompt = _pendingFailedPrompt;
    if (prompt == null || prompt.trim().isEmpty) return false;
    return sendMessage(
      text: prompt,
      snapshot: snapshot,
      bypassCooldown: true,
    );
  }

  Future<void> deleteSession(String sessionId) async {
    final targetUid = _uid;
    if (targetUid == null || _isDeletingSession) return;

    _isDeletingSession = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteSession(targetUid, sessionId);
      if (_uid != targetUid) return;

      _sessions = _sessions.where((s) => s.id != sessionId).toList();

      if (_activeSessionId == sessionId) {
        if (_sessions.isNotEmpty) {
          final nextId = _sessions.first.id;
          _activeSessionId = nextId;
          _isNewDraftMode = false;
          _messages = const [];
          _isDeletingSession = false;
          notifyListeners();
          await _loadMessagesForActiveSession(targetUid, nextId);
          return;
        } else {
          _activeSessionId = null;
          _isNewDraftMode = true;
          _messages = const [];
        }
      }
    } catch (e) {
      if (_uid == targetUid) {
        _errorMessage = ErrorMapper.message(e);
      }
      rethrow;
    } finally {
      if (_uid == targetUid) {
        _isDeletingSession = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _geminiService.dispose();
    super.dispose();
  }
}
