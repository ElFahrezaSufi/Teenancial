import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teenancial/data/feen_catalog.dart';
import 'package:teenancial/models/feen_chat_model.dart';
import 'package:teenancial/providers/feen_chat_provider.dart';
import 'package:teenancial/repositories/feen_chat_repository.dart';
import 'package:teenancial/services/connectivity_service.dart';
import 'package:teenancial/services/gemini_service.dart';
import 'package:teenancial/utils/feen_context_builder.dart';

class _InMemoryFeenChatRepository extends FeenChatRepository {
  final Map<String, FeenChatSession> sessionsById = {};
  final Map<String, List<FeenChatMessage>> messagesBySession = {};
  int _counter = 0;

  @override
  Future<List<FeenChatSession>> getSessions(String uid) async {
    final list = sessionsById.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<List<FeenChatMessage>> getMessages(
    String uid,
    String sessionId,
  ) async {
    return List<FeenChatMessage>.from(messagesBySession[sessionId] ?? const []);
  }

  @override
  Future<SavedChatTurn> saveTurnAtomic({
    required String uid,
    FeenChatSession? existingSession,
    required String userText,
    required String modelText,
    required FeenPose pose,
    required List<String> suggestedRoutes,
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    final modelTs = ts.add(const Duration(milliseconds: 1));
    final sessionId = existingSession?.id ?? 'session_${++_counter}';
    final userMsg = FeenChatMessage(
      id: 'msg_${++_counter}',
      role: FeenMessageRole.user,
      text: userText,
      createdAt: ts,
    );
    final modelMsg = FeenChatMessage(
      id: 'msg_${++_counter}',
      role: FeenMessageRole.model,
      text: modelText,
      createdAt: modelTs,
      pose: pose,
      suggestedRoutes: suggestedRoutes,
    );
    final session = existingSession != null
        ? existingSession.copyWith(
            lastMessagePreview: FeenChatSession.buildPreview(modelText),
            messageCount: existingSession.messageCount + 2,
            updatedAt: modelTs,
          )
        : FeenChatSession(
            id: sessionId,
            title: FeenChatSession.buildTitleFromPrompt(userText),
            lastMessagePreview: FeenChatSession.buildPreview(modelText),
            messageCount: 2,
            createdAt: ts,
            updatedAt: modelTs,
          );

    sessionsById[sessionId] = session;
    messagesBySession.putIfAbsent(sessionId, () => []).addAll([userMsg, modelMsg]);

    return SavedChatTurn(
      session: session,
      userMessage: userMsg,
      modelMessage: modelMsg,
    );
  }

  @override
  Future<void> deleteSession(String uid, String sessionId) async {
    sessionsById.remove(sessionId);
    messagesBySession.remove(sessionId);
  }
}

void main() {
  tearDown(() {
    ConnectivityService.instance.markOnlineFromServer();
  });

  group('FeenChatProvider', () {
    test(
      'membuat sesi atomik, menjaga sliding window maks 12 pesan riwayat, dan mendukung multi-sesi + hapus sesi',
      () async {
        final repo = _InMemoryFeenChatRepository();
        final List<int> capturedContentCounts = [];
        DateTime fakeNow = DateTime(2026, 11, 20, 10, 0, 0);

        final mockClient = MockClient((request) async {
          final decoded = jsonDecode(request.body) as Map<String, dynamic>;
          final contents = decoded['contents'] as List;
          capturedContentCounts.add(contents.length);
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Siap! Cek juga Laporan Keuangan kamu ya.'},
                    ],
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });

        final provider = FeenChatProvider(
          repository: repo,
          geminiService: GeminiService(
            client: mockClient,
            apiKey: 'AIzaTestValidKey',
          ),
          clock: () => fakeNow,
        );
        provider.updateUser('u1');
        await Future<void>.delayed(Duration.zero);

        final snapshot = FeenLiveSnapshot(displayName: 'Dina', now: fakeNow);

        // Kirim 8 pasang berturut-turut (maju 5 detik per pesan agar lolos cooldown)
        for (int i = 1; i <= 8; i++) {
          fakeNow = fakeNow.add(const Duration(seconds: 5));
          final ok = await provider.sendMessage(
            text: 'Pertanyaan ke-$i tentang target menabung',
            snapshot: snapshot,
          );
          expect(ok, isTrue);
        }

        // UI tetap menampilkan 16 pesan (8 pasang)
        expect(provider.messages.length, 16);
        expect(provider.sessions.length, 1);
        expect(provider.sessions.first.messageCount, 16);

        // Payload ke-8 harus dibatasi: 12 pesan riwayat terakhir + 1 pesan baru = 13
        expect(capturedContentCounts.last, 13);

        // Mulai sesi baru -> buat sesi ke-2
        final firstSessionId = provider.activeSessionId!;
        provider.startNewSession();
        expect(provider.activeSessionId, isNull);
        expect(provider.messages, isEmpty);

        fakeNow = fakeNow.add(const Duration(seconds: 5));
        final okSecond = await provider.sendMessage(
          text: 'Apa itu dana darurat?',
          snapshot: snapshot,
        );
        expect(okSecond, isTrue);
        expect(provider.sessions.length, 2);
        final secondSessionId = provider.activeSessionId!;
        expect(secondSessionId, isNot(firstSessionId));

        // Hapus sesi ke-2 (yang sedang aktif) -> otomatis kembali ke sesi pertama
        await provider.deleteSession(secondSessionId);
        expect(provider.sessions.length, 1);
        expect(provider.activeSessionId, firstSessionId);
        expect(provider.messages.length, 16);

        provider.dispose();
      },
    );

    test(
      'menahan kirim saat offline dan cooldown, serta retryLastMessage pulih setelah error server',
      () async {
        final repo = _InMemoryFeenChatRepository();
        DateTime fakeNow = DateTime(2026, 11, 20, 12, 0, 0);
        int callCount = 0;

        final mockClient = MockClient((_) async {
          callCount++;
          if (callCount == 1) {
            return http.Response('{}', 503);
          }
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Berhasil setelah coba lagi!'},
                    ],
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });

        final provider = FeenChatProvider(
          repository: repo,
          geminiService: GeminiService(
            client: mockClient,
            apiKey: 'AIzaTestValidKey',
            fallbackModel: '',
          ),
          clock: () => fakeNow,
        );
        provider.updateUser('u1');
        await Future<void>.delayed(Duration.zero);

        final snapshot = FeenLiveSnapshot(displayName: 'Raka', now: fakeNow);

        // 1. Offline -> tertahan tanpa memanggil Gemini
        ConnectivityService.instance.markOfflineFromError();
        final offlineOk = await provider.sendMessage(
          text: 'Halo Feen',
          snapshot: snapshot,
        );
        expect(offlineOk, isFalse);
        expect(callCount, 0);
        expect(provider.errorMessage, contains('koneksi internet'));
        expect(provider.pendingFailedPrompt, isNull);

        // 2. Online -> panggilan pertama gagal 503 -> menyimpan pendingFailedPrompt
        ConnectivityService.instance.markOnlineFromServer();
        final firstAttempt = await provider.sendMessage(
          text: 'Tips hemat dong',
          snapshot: snapshot,
        );
        expect(firstAttempt, isFalse);
        expect(callCount, 1);
        expect(provider.pendingFailedPrompt, 'Tips hemat dong');
        expect(provider.messages, isEmpty);

        // 3. retryLastMessage langsung bypass cooldown dan berhasil
        final retryOk = await provider.retryLastMessage(snapshot);
        expect(retryOk, isTrue);
        expect(callCount, 2);
        expect(provider.pendingFailedPrompt, isNull);
        expect(provider.messages.length, 2);
        expect(provider.messages.last.text, 'Berhasil setelah coba lagi!');

        // 4. Kirim lagi di detik yang sama -> ditahan cooldown 2 detik
        final spamOk = await provider.sendMessage(
          text: 'Kirim cepat',
          snapshot: snapshot,
        );
        expect(spamOk, isFalse);
        expect(provider.errorMessage, contains('Tunggu sebentar'));

        provider.dispose();
      },
    );

    test(
      'simulasi sinkronisasi antar perangkat: chat tersimpan di Perangkat 1 otomatis termuat utuh saat Perangkat 2 login akun yang sama',
      () async {
        final sharedCloudRepo = _InMemoryFeenChatRepository();
        final fakeNow = DateTime(2026, 11, 28, 14, 0, 0);

        MockClient buildOkClient() => MockClient((_) async {
              return http.Response(
                jsonEncode({
                  'candidates': [
                    {
                      'content': {
                        'parts': [
                          {'text': 'Halo! Saldomu aman dan terkendali.'},
                        ],
                      },
                    },
                  ],
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            });

        // Perangkat 1: login dan kirim 1 pesan ke Tanya Feen
        final device1 = FeenChatProvider(
          repository: sharedCloudRepo,
          geminiService: GeminiService(
            client: buildOkClient(),
            apiKey: 'AQ.TestValidKey',
          ),
          clock: () => fakeNow,
        );
        device1.updateUser('u_sync');
        await Future<void>.delayed(Duration.zero);

        final sent = await device1.sendMessage(
          text: 'Cek kondisi keuanganku hari ini dong',
          snapshot: FeenLiveSnapshot(displayName: 'Budi', now: fakeNow),
        );
        expect(sent, isTrue);
        expect(device1.sessions.length, 1);
        expect(device1.messages.length, 2);
        final savedSessionId = device1.activeSessionId!;

        // Perangkat 2: instance provider baru (memori kosong) login akun yang sama
        final device2 = FeenChatProvider(
          repository: sharedCloudRepo,
          geminiService: GeminiService(
            client: buildOkClient(),
            apiKey: 'AQ.TestValidKey',
          ),
          clock: () => fakeNow.add(const Duration(minutes: 2)),
        );
        device2.updateUser('u_sync');
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(device2.sessions.length, 1);
        expect(device2.activeSessionId, savedSessionId);
        expect(device2.messages.length, 2);
        expect(device2.messages.first.text, 'Cek kondisi keuanganku hari ini dong');
        expect(device2.messages.last.text, 'Halo! Saldomu aman dan terkendali.');

        device1.dispose();
        device2.dispose();
      },
    );
  });
}
