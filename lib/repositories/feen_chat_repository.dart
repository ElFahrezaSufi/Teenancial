import '../data/feen_catalog.dart';
import '../models/feen_chat_model.dart';
import '../services/firestore_service.dart';

/// Hasil penyimpanan atomik 1 pasang giliran percakapan (user + Feen).
class SavedChatTurn {
  final FeenChatSession session;
  final FeenChatMessage userMessage;
  final FeenChatMessage modelMessage;

  const SavedChatTurn({
    required this.session,
    required this.userMessage,
    required this.modelMessage,
  });
}

/// Repository Firestore untuk sesi & pesan percakapan Tanya Feen.
///
/// Seluruh pembacaan memakai [FirestoreService.getQuerySnapshot] agar otomatis
/// fallback ke cache lokal saat offline, sedangkan operasi tulis dijaga oleh
/// [FirestoreService.ensureOnline].
class FeenChatRepository {
  final FirestoreService _firestoreService;

  FeenChatRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService.instance;

  Future<List<FeenChatSession>> getSessions(String uid) async {
    final snapshot = await _firestoreService.getQuerySnapshot(
      _firestoreService
          .chatSessionsCol(uid)
          .orderBy('updatedAt', descending: true),
    );
    return snapshot.docs
        .map((doc) => FeenChatSession.fromMap(doc.data(), docId: doc.id))
        .toList();
  }

  Future<List<FeenChatMessage>> getMessages(
    String uid,
    String sessionId,
  ) async {
    final snapshot = await _firestoreService.getQuerySnapshot(
      _firestoreService
          .chatMessagesCol(uid, sessionId)
          .orderBy('createdAt', descending: false),
    );
    return snapshot.docs
        .map((doc) => FeenChatMessage.fromMap(doc.data(), docId: doc.id))
        .toList();
  }

  /// Menyimpan pesan pengguna, balasan Feen, dan pembaruan metadata sesi
  /// secara atomik dalam satu `WriteBatch` Firestore.
  Future<SavedChatTurn> saveTurnAtomic({
    required String uid,
    FeenChatSession? existingSession,
    required String userText,
    required String modelText,
    required FeenPose pose,
    required List<String> suggestedRoutes,
    DateTime? now,
  }) async {
    _firestoreService.ensureOnline(
      actionLabel: 'menyimpan riwayat percakapan Tanya Feen',
    );

    final timestamp = now ?? DateTime.now();
    final modelTimestamp = timestamp.add(const Duration(milliseconds: 1));

    final sessionRef = existingSession != null
        ? _firestoreService.chatSessionsCol(uid).doc(existingSession.id)
        : _firestoreService.chatSessionsCol(uid).doc();
    final messagesCol = _firestoreService.chatMessagesCol(uid, sessionRef.id);
    final userMsgRef = messagesCol.doc();
    final modelMsgRef = messagesCol.doc();

    final userMessage = FeenChatMessage(
      id: userMsgRef.id,
      role: FeenMessageRole.user,
      text: userText,
      createdAt: timestamp,
    );

    final modelMessage = FeenChatMessage(
      id: modelMsgRef.id,
      role: FeenMessageRole.model,
      text: modelText,
      createdAt: modelTimestamp,
      pose: pose,
      suggestedRoutes: suggestedRoutes,
    );

    final session = existingSession != null
        ? existingSession.copyWith(
            lastMessagePreview: FeenChatSession.buildPreview(modelText),
            messageCount: existingSession.messageCount + 2,
            updatedAt: modelTimestamp,
          )
        : FeenChatSession(
            id: sessionRef.id,
            title: FeenChatSession.buildTitleFromPrompt(userText),
            lastMessagePreview: FeenChatSession.buildPreview(modelText),
            messageCount: 2,
            createdAt: timestamp,
            updatedAt: modelTimestamp,
          );

    final batch = _firestoreService.batch();
    batch.set(sessionRef, session.toMap());
    batch.set(userMsgRef, userMessage.toMap());
    batch.set(modelMsgRef, modelMessage.toMap());
    await batch.commit();

    return SavedChatTurn(
      session: session,
      userMessage: userMessage,
      modelMessage: modelMessage,
    );
  }

  /// Menghapus satu sesi obrolan beserta seluruh dokumen pada subcollection
  /// `messages` di bawahnya secara bertahap.
  Future<void> deleteSession(String uid, String sessionId) async {
    _firestoreService.ensureOnline(actionLabel: 'menghapus riwayat obrolan');

    final messagesCol = _firestoreService.chatMessagesCol(uid, sessionId);
    final msgSnap = await messagesCol.get();
    const chunkSize = 400;
    for (int i = 0; i < msgSnap.docs.length; i += chunkSize) {
      final end = (i + chunkSize < msgSnap.docs.length)
          ? i + chunkSize
          : msgSnap.docs.length;
      final batch = _firestoreService.batch();
      for (final doc in msgSnap.docs.sublist(i, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await _firestoreService.chatSessionsCol(uid).doc(sessionId).delete();
  }
}
