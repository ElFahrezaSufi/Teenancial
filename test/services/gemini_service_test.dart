import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teenancial/config/gemini_config.dart';
import 'package:teenancial/models/feen_chat_model.dart';
import 'package:teenancial/services/gemini_service.dart';

void main() {
  group('GeminiService', () {
    test(
      'mengirim x-goog-api-key di header, menyertakan systemInstruction + riwayat, dan mem-parsing balasan',
      () async {
        late http.Request capturedRequest;
        final mockClient = MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Halo! Total saldomu saat ini **Rp 500.000**.'},
                    ],
                  },
                  'finishReason': 'STOP',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });

        final service = GeminiService(
          client: mockClient,
          apiKey: 'AIzaTestKeyValid123',
          primaryModel: 'gemini-flash-latest',
          fallbackModel: 'gemini-2.5-flash-lite',
        );

        final history = [
          FeenChatMessage(
            id: 'm1',
            role: FeenMessageRole.user,
            text: 'Halo Feen',
            createdAt: DateTime(2026, 11, 20, 10, 0),
          ),
          FeenChatMessage(
            id: 'm2',
            role: FeenMessageRole.model,
            text: 'Hai! Ada yang bisa kubantu?',
            createdAt: DateTime(2026, 11, 20, 10, 1),
          ),
        ];

        final reply = await service.generateReply(
          systemPrompt: 'Kamu adalah Feen.',
          history: history,
          userMessage: 'Berapa total saldoku?',
        );

        expect(reply, 'Halo! Total saldomu saat ini **Rp 500.000**.');
        expect(capturedRequest.url.path, contains('gemini-flash-latest:generateContent'));
        expect(capturedRequest.url.queryParameters.containsKey('key'), isFalse);
        expect(capturedRequest.headers['x-goog-api-key'], 'AIzaTestKeyValid123');

        final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
        expect(
          (body['systemInstruction'] as Map)['parts'][0]['text'],
          'Kamu adalah Feen.',
        );
        final contents = body['contents'] as List;
        expect(contents.length, 3);
        expect(contents[0]['role'], 'user');
        expect(contents[1]['role'], 'model');
        expect(contents[2]['parts'][0]['text'], 'Berapa total saldoku?');
      },
    );

    test(
      'otomatis fallback ke model cadangan saat model utama menerima HTTP 429 atau 404',
      () async {
        final List<String> calledPaths = [];
        final mockClient = MockClient((request) async {
          calledPaths.add(request.url.path);
          if (calledPaths.length == 1) {
            return http.Response('{"error":{"code":429}}', 429);
          }
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Berhasil lewat model cadangan!'},
                    ],
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });

        final service = GeminiService(
          client: mockClient,
          apiKey: 'AIzaTestKeyValid123',
          primaryModel: 'gemini-flash-latest',
          fallbackModel: 'gemini-2.5-flash-lite',
        );

        final reply = await service.generateReply(
          systemPrompt: 'System',
          history: const [],
          userMessage: 'Tips hemat dong',
        );

        expect(reply, 'Berhasil lewat model cadangan!');
        expect(calledPaths.length, 2);
        expect(calledPaths[0], contains('gemini-flash-latest'));
        expect(calledPaths[1], contains('gemini-2.5-flash-lite'));
      },
    );

    test('melempar missingApiKey saat API key kosong atau placeholder', () async {
      final mockClient = MockClient((_) async => http.Response('{}', 200));

      final emptyService = GeminiService(client: mockClient, apiKey: '');
      expect(emptyService.isConfigured, isFalse);
      await expectLater(
        () => emptyService.generateReply(
          systemPrompt: 'System',
          history: const [],
          userMessage: 'Halo',
        ),
        throwsA(
          isA<GeminiApiException>().having(
            (e) => e.type,
            'type',
            GeminiErrorType.missingApiKey,
          ),
        ),
      );

      final placeholderService = GeminiService(
        client: mockClient,
        apiKey: 'ISI_API_KEY_GOOGLE_AI_STUDIO_DI_SINI',
      );
      expect(placeholderService.isConfigured, isFalse);
    });

    test('melempar safetyBlocked ketika respons diblokir oleh filter keamanan', () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'promptFeedback': {'blockReason': 'SAFETY'},
          }),
          200,
        ),
      );

      final service = GeminiService(
        client: mockClient,
        apiKey: 'AIzaTestKeyValid123',
      );

      await expectLater(
        () => service.generateReply(
          systemPrompt: 'System',
          history: const [],
          userMessage: 'Pesan tidak aman',
        ),
        throwsA(
          isA<GeminiApiException>().having(
            (e) => e.type,
            'type',
            GeminiErrorType.safetyBlocked,
          ),
        ),
      );
    });

    test('melempar rateLimited bila model utama dan cadangan sama-sama 429', () async {
      final mockClient = MockClient((_) async => http.Response('{}', 429));
      final service = GeminiService(
        client: mockClient,
        apiKey: 'AIzaTestKeyValid123',
        primaryModel: 'gemini-flash-latest',
        fallbackModel: 'gemini-2.5-flash-lite',
      );

      await expectLater(
        () => service.generateReply(
          systemPrompt: 'System',
          history: const [],
          userMessage: 'Halo',
        ),
        throwsA(
          isA<GeminiApiException>().having(
            (e) => e.type,
            'type',
            GeminiErrorType.rateLimited,
          ),
        ),
      );
    });
  });
}
