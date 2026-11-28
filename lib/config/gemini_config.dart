/// Jenis kesalahan yang dapat terjadi saat berkomunikasi dengan Gemini API.
enum GeminiErrorType {
  missingApiKey,
  rateLimited,
  modelUnavailable,
  safetyBlocked,
  timeout,
  network,
  invalidResponse,
  server,
}

/// Exception terstruktur untuk seluruh kegagalan panggilan Gemini API.
class GeminiApiException implements Exception {
  final GeminiErrorType type;
  final String message;
  final int? statusCode;

  const GeminiApiException(
    this.type,
    this.message, {
    this.statusCode,
  });

  @override
  String toString() => message;
}

/// Konfigurasi runtime Gemini API yang disuntikkan melalui `--dart-define`
/// atau `--dart-define-from-file=dart_defines.json` agar API key tidak pernah
/// tersimpan di dalam repositori Git.
class GeminiConfig {
  const GeminiConfig._();

  static const String apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const String primaryModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-flash-latest',
  );

  static const String fallbackModel = String.fromEnvironment(
    'GEMINI_FALLBACK_MODEL',
    defaultValue: 'gemini-flash-lite-latest',
  );

  static const String apiHost = 'generativelanguage.googleapis.com';
  static const Duration requestTimeout = Duration(seconds: 20);
  static const int maxOutputTokens = 1500;
  static const String defaultThinkingLevel = 'low';

  /// Mengecek apakah API key valid dan bukan placeholder dari file contoh.
  static bool isKeyConfigured([String? candidateKey]) {
    final trimmed = (candidateKey ?? apiKey).trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.toUpperCase().startsWith('ISI_API_KEY')) return false;
    return true;
  }

  static bool get isConfigured => isKeyConfigured(apiKey);

  static Uri generateContentUri(String model) {
    final normalized = model.trim().isEmpty ? primaryModel : model.trim();
    return Uri.https(apiHost, '/v1beta/models/$normalized:generateContent');
  }
}
