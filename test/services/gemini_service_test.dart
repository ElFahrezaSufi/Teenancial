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

        final genConfig = body['generationConfig'] as Map<String, dynamic>;
        expect(genConfig['maxOutputTokens'], GeminiConfig.maxOutputTokens);
        expect(
          (genConfig['thinkingConfig'] as Map)['thinkingLevel'],
          GeminiConfig.defaultThinkingLevel,
        );
      },
    );

    test(
      'mengabaikan part penalaran internal (thought: true) saat mengekstrak balasan',
      () async {
        final mockClient = MockClient((_) async {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'thought': true,
                        'text': 'Langkah berpikir internal yang tidak boleh tampil.',
                      },
                      {'text': 'Pengeluaran terbesarmu bulan ini adalah Makan.'},
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
        );

        final reply = await service.generateReply(
          systemPrompt: 'System',
          history: const [],
          userMessage: 'Evaluasi pengeluaranku bulan ini',
        );

        expect(reply, 'Pengeluaran terbesarmu bulan ini adalah Makan.');
      },
    );

    test(
      'otomatis fallback ke model cadangan saat model utama mengalami timeout',
      () async {
        final List<String> calledPaths = [];
        final mockClient = MockClient((request) async {
          calledPaths.add(request.url.path);
          if (calledPaths.length == 1) {
            await Future<void>.delayed(const Duration(milliseconds: 120));
            return http.Response('{}', 200);
          }
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Balasan cepat dari flash-lite!'},
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
          fallbackModel: 'gemini-flash-lite-latest',
          timeout: const Duration(milliseconds: 40),
        );

        final reply = await service.generateReply(
          systemPrompt: 'System',
          history: const [],
          userMessage: 'Evaluasi pengeluaranku bulan ini',
        );

        expect(reply, 'Balasan cepat dari flash-lite!');
        expect(calledPaths.length, 2);
        expect(calledPaths[0], contains('gemini-flash-latest'));
        expect(calledPaths[1], contains('gemini-flash-lite-latest'));
      },
    );

    test(
      'melempar GeminiErrorType.timeout bila model utama dan cadangan sama-sama timeout',
      () async {
        final mockClient = MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          return http.Response('{}', 200);
        });

        final service = GeminiService(
          client: mockClient,
          apiKey: 'AIzaTestKeyValid123',
          primaryModel: 'gemini-flash-latest',
          fallbackModel: 'gemini-flash-lite-latest',
          timeout: const Duration(milliseconds: 30),
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
              GeminiErrorType.timeout,
            ),
          ),
        );
      },
    );

    test(
      'otomatis mengulang 1 kali tanpa thinkingConfig bila model menolak dengan HTTP 400',
      () async {
        final List<Map<String, dynamic>> sentBodies = [];
        final List<String> calledPaths = [];

        final mockClient = MockClient((request) async {
          calledPaths.add(request.url.path);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          sentBodies.add(body);

          final genConfig = body['generationConfig'] as Map<String, dynamic>;
          if (genConfig.containsKey('thinkingConfig')) {
            return http.Response(
              '{"error":{"code":400,"message":"Unknown name thinkingLevel"}}',
              400,
            );
          }

          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Berhasil setelah ulang tanpa thinkingConfig!'},
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
          fallbackModel: 'gemini-flash-lite-latest',
        );

        final reply = await service.generateReply(
          systemPrompt: 'System',
          history: const [],
          userMessage: 'Tips hemat dong',
        );

        expect(reply, 'Berhasil setelah ulang tanpa thinkingConfig!');
        expect(calledPaths.length, 2);
        expect(calledPaths[0], contains('gemini-flash-latest'));
        expect(calledPaths[1], contains('gemini-flash-latest'));
        expect(
          (sentBodies[0]['generationConfig'] as Map).containsKey('thinkingConfig'),
          isTrue,
        );
        expect(
          (sentBodies[1]['generationConfig'] as Map).containsKey('thinkingConfig'),
          isFalse,
        );
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
