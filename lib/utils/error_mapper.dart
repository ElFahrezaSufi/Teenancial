import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/connectivity_service.dart';

class ErrorMapper {
  const ErrorMapper._();

  /// Mengubah objek error / exception menjadi pesan Bahasa Indonesia yang
  /// bersih dan ramah pengguna (tanpa prefix `Exception:` atau detail teknis).
  static String message(
    Object error, {
    String fallback = 'Terjadi kesalahan. Silakan coba lagi.',
  }) {
    if (error is OfflineException) {
      return error.message;
    }
    if (error is TimeoutException) {
      return 'Koneksi internet lambat atau terputus. Silakan periksa jaringan Anda dan coba lagi.';
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'Email tidak ditemukan. Silakan periksa kembali email Anda.';
        case 'wrong-password':
          return 'Password yang dimasukkan salah.';
        case 'invalid-credential':
          return 'Email belum terdaftar atau password salah.';
        case 'invalid-email':
          return 'Format email tidak valid.';
        case 'email-already-in-use':
          return 'Email ini sudah terdaftar. Silakan langsung Masuk dengan Email/Password atau Google.';
        case 'weak-password':
          return 'Password terlalu lemah (minimal 8 karakter).';
        case 'too-many-requests':
          return 'Terlalu banyak percobaan. Silakan coba lagi beberapa saat lagi.';
        case 'network-request-failed':
          return 'Koneksi internet bermasalah. Silakan periksa jaringan Anda.';
        case 'user-mismatch':
          return 'Akun Google yang dipilih tidak cocok dengan akun yang sedang login. Pilih akun yang sama untuk melanjutkan.';
        case 'requires-recent-login':
          return 'Demi keamanan, silakan verifikasi ulang akun atau masuk kembali terlebih dahulu.';
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
          return 'Verifikasi akun dibatalkan oleh pengguna.';
        default:
          return error.message?.trim().isNotEmpty == true
              ? error.message!.trim()
              : fallback;
      }
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Anda tidak memiliki izin untuk mengakses data ini.';
        case 'unavailable':
        case 'deadline-exceeded':
          return 'Layanan sedang sibuk atau koneksi lambat. Silakan coba lagi.';
        case 'not-found':
          return 'Data yang diminta tidak ditemukan.';
        default:
          return error.message?.trim().isNotEmpty == true
              ? error.message!.trim()
              : fallback;
      }
    }

    final raw = error
        .toString()
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .trim();

    if (raw.isEmpty) return fallback;

    final lower = raw.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('clientexception') ||
        lower.contains('network is unreachable') ||
        lower.contains('timeoutexception')) {
      return 'Koneksi internet bermasalah. Silakan periksa jaringan Anda.';
    }

    return raw;
  }
}
