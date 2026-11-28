import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/gemini_config.dart';
import '../models/feen_chat_model.dart';

/// Layanan REST client untuk Gemini Developer API (`generateContent`).
///
/// Mendukung injeksi [http.Client] untuk unit test serta fallback otomatis
/// ke model cadangan saat model utama mengalami rate-limit (`429`) atau tidak
/// tersedia (`404`/`503`).
class GeminiService {
  final http.Client _client;
  final bool _ownsClient;
  final String _apiKey;
  final String _primaryModel;
  final String _fallbackModel;
  final Duration _timeout;

  GeminiService({
    http.Client? client,
    String? apiKey,
    String? primaryModel,
    String? fallbackModel,
    Duration? timeout,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _apiKey = apiKey ?? GeminiConfig.apiKey,
        _primaryModel = (primaryModel ?? GeminiConfig.primaryModel).trim(),
        _fallbackModel = (fallbackModel ?? GeminiConfig.fallbackModel).trim(),
        _timeout = timeout ?? GeminiConfig.requestTimeout;

  bool get isConfigured => GeminiConfig.isKeyConfigured(_apiKey);

  /// Mengirim percakapan multi-turn ke Gemini API dan mengembalikan teks balasan.
  ///
  /// [history] hanya berisi pesan-pesan SEBELUM [userMessage] agar pesan terbaru
  /// tidak terkirim ganda.
  Future<String> generateReply({
    required String systemPrompt,
    required List<FeenChatMessage> history,
    required String userMessage,
  }) async {
    if (!isConfigured) {
      throw const GeminiApiException(
        GeminiErrorType.missingApiKey,
        'API key Tanya Feen belum dikonfigurasi. Tambahkan GEMINI_API_KEY di file dart_defines.json lalu jalankan ulang aplikasi.',
      );
    }

    final trimmedPrompt = userMessage.trim();
    if (trimmedPrompt.isEmpty) {
      throw const GeminiApiException(
        GeminiErrorType.invalidResponse,
        'Pesan tidak boleh kosong.',
      );
    }

    final payload = _buildPayload(
      systemPrompt: systemPrompt,
      history: history,
      userMessage: trimmedPrompt,
    );

    final List<String> modelChain = [
      if (_primaryModel.isNotEmpty) _primaryModel,
      if (_fallbackModel.isNotEmpty && _fallbackModel != _primaryModel)
        _fallbackModel,
    ];

    GeminiApiException? lastRetryableError;

    for (int i = 0; i < modelChain.length; i++) {
      final model = modelChain[i];
      final bool hasNextModel = i + 1 < modelChain.length;

      try {
        return await _callModel(model: model, payload: payload);
      } on GeminiApiException catch (e) {
        final canFallback = hasNextModel &&
            (e.type == GeminiErrorType.rateLimited ||
                e.type == GeminiErrorType.modelUnavailable ||
                e.type == GeminiErrorType.server);
        if (canFallback) {
          lastRetryableError = e;
          continue;
        }
        rethrow;
      }
    }

    throw lastRetryableError ??
        const GeminiApiException(
          GeminiErrorType.server,
          'Layanan Feen sedang sibuk. Silakan coba lagi sebentar lagi.',
        );
  }

  Map<String, dynamic> _buildPayload({
    required String systemPrompt,
    required List<FeenChatMessage> history,
    required String userMessage,
  }) {
    final List<Map<String, dynamic>> contents = [
      for (final msg in history)
        if (msg.text.trim().isNotEmpty)
          {
            'role': msg.isUser ? 'user' : 'model',
            'parts': [
              {'text': msg.text.trim()},
            ],
          },
      {
        'role': 'user',
        'parts': [
          {'text': userMessage},
        ],
      },
    ];

    return {
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.6,
        'topP': 0.9,
        'maxOutputTokens': 700,
      },
    };
  }

  Future<String> _callModel({
    required String model,
    required Map<String, dynamic> payload,
  }) async {
    final uri = GeminiConfig.generateContentUri(model);

    late http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'x-goog-api-key': _apiKey.trim(),
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const GeminiApiException(
        GeminiErrorType.network,
        'Feen terlalu lama merespons. Periksa koneksi internetmu lalu coba lagi.',
      );
    } on SocketException {
      throw const GeminiApiException(
        GeminiErrorType.network,
        'Tidak dapat terhubung ke layanan Feen. Periksa koneksi internetmu.',
      );
    } on http.ClientException {
      throw const GeminiApiException(
        GeminiErrorType.network,
        'Koneksi ke layanan Feen terputus. Silakan coba lagi.',
      );
    }

    if (response.statusCode == 200) {
      return _extractReplyText(response.body);
    }

    throw _mapHttpError(response.statusCode, response.body);
  }

  String _extractReplyText(String body) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw const GeminiApiException(
        GeminiErrorType.invalidResponse,
        'Feen mengirim respons yang tidak terbaca. Coba kirim ulang pertanyaanmu.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const GeminiApiException(
        GeminiErrorType.invalidResponse,
        'Format respons Feen tidak valid.',
      );
    }

    final promptFeedback = decoded['promptFeedback'];
    if (promptFeedback is Map<String, dynamic> &&
        promptFeedback['blockReason'] != null) {
      throw const GeminiApiException(
        GeminiErrorType.safetyBlocked,
        'Maaf, aku tidak bisa menanggapi pesan tersebut. Yuk tanya hal lain seputar keuangan atau menabung!',
      );
    }

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const GeminiApiException(
        GeminiErrorType.invalidResponse,
        'Feen belum bisa memberikan jawaban saat ini. Coba ulangi pertanyaanmu ya.',
      );
    }

    final first = candidates.first;
    if (first is! Map<String, dynamic>) {
      throw const GeminiApiException(
        GeminiErrorType.invalidResponse,
        'Format kandidat balasan Feen tidak valid.',
      );
    }

    final finishReason = (first['finishReason'] as String?)?.toUpperCase();
    if (finishReason == 'SAFETY' || finishReason == 'RECITATION') {
      throw const GeminiApiException(
        GeminiErrorType.safetyBlocked,
        'Maaf, aku tidak bisa menanggapi topik tersebut. Yuk bahas hal lain soal keuangan atau target menabungmu!',
      );
    }

    final content = first['content'];
    if (content is Map<String, dynamic>) {
      final parts = content['parts'];
      if (parts is List) {
        final buffer = StringBuffer();
        for (final part in parts) {
          if (part is Map<String, dynamic> && part['text'] is String) {
            buffer.write(part['text'] as String);
          }
        }
        final result = buffer.toString().trim();
        if (result.isNotEmpty) {
          return result;
        }
      }
    }

    throw const GeminiApiException(
      GeminiErrorType.invalidResponse,
      'Jawaban Feen kosong. Silakan coba lagi.',
    );
  }

  GeminiApiException _mapHttpError(int statusCode, String body) {
    if (statusCode == 429) {
      return GeminiApiException(
        GeminiErrorType.rateLimited,
        'Kuota chat gratis Feen sedang penuh sebentar. Tunggu beberapa saat lalu coba lagi ya.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 401 || statusCode == 403) {
      return GeminiApiException(
        GeminiErrorType.missingApiKey,
        'API key Tanya Feen tidak valid atau belum diizinkan. Periksa file dart_defines.json kamu.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 404) {
      return GeminiApiException(
        GeminiErrorType.modelUnavailable,
        'Model AI yang dipilih sedang tidak tersedia. Periksa pengaturan GEMINI_MODEL.',
        statusCode: statusCode,
      );
    }
    if (statusCode >= 500) {
      return GeminiApiException(
        GeminiErrorType.server,
        'Server AI sedang sibuk. Silakan coba lagi beberapa saat lagi.',
        statusCode: statusCode,
      );
    }

    return GeminiApiException(
      GeminiErrorType.invalidResponse,
      'Permintaan ke Feen gagal diproses (kode $statusCode). Silakan coba lagi.',
      statusCode: statusCode,
    );
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
