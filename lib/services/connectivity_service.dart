import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Dilempar ketika pengguna menjalankan operasi tulis/online saat perangkat
/// sedang tidak terhubung ke internet (Dukungan Offline Tingkatan A).
class OfflineException implements Exception {
  final String message;

  const OfflineException([
    this.message =
        'Tidak ada koneksi internet. Hubungkan ke internet untuk melanjutkan.',
  ]);

  @override
  String toString() => message;
}

/// Memantau status konektivitas perangkat secara real-time sekaligus melakukan
/// verifikasi ringan jangkauan internet agar Wi-Fi tanpa koneksi internet tetap
/// terdeteksi sebagai mode offline.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  bool _initialized = false;
  bool _isOffline = false;
  bool _isChecking = false;
  bool _isUsingCachedData = false;

  Connectivity? _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Future<bool> Function()? _reachabilityProbeOverride;

  bool get isOffline => _isOffline;
  bool get isOnline => !_isOffline;
  bool get isChecking => _isChecking;
  bool get isUsingCachedData => _isUsingCachedData;

  /// Bernilai `true` apabila OS melaporkan minimal satu antarmuka jaringan aktif
  /// selain `ConnectivityResult.none`.
  static bool hasActiveInterface(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Menginisialisasi pemantauan jaringan OS. Aman dipanggil berulang kali
  /// maupun pada lingkungan unit/widget test tanpa platform channel.
  Future<void> init({
    Connectivity? connectivity,
    Future<bool> Function()? reachabilityProbe,
  }) async {
    if (_initialized) return;
    _initialized = true;
    _reachabilityProbeOverride = reachabilityProbe;

    try {
      final conn = connectivity ?? Connectivity();
      _connectivity = conn;

      final initialResults = await conn.checkConnectivity();
      await _evaluateConnectivity(initialResults);

      _subscription = conn.onConnectivityChanged.listen((results) {
        unawaited(_evaluateConnectivity(results));
      });
    } catch (e) {
      debugPrint('Gagal menginisialisasi ConnectivityService: $e');
    }
  }

  Future<void> _evaluateConnectivity(List<ConnectivityResult> results) async {
    if (!hasActiveInterface(results)) {
      _applyStatus(offline: true);
      return;
    }

    final reachable = await _probeInternet();
    _applyStatus(offline: !reachable);
  }

  Future<bool> _probeInternet() async {
    if (_reachabilityProbeOverride != null) {
      try {
        return await _reachabilityProbeOverride!();
      } catch (_) {
        return false;
      }
    }
    if (kIsWeb) return true;

    try {
      final addresses = await InternetAddress.lookup(
        'firestore.googleapis.com',
      ).timeout(const Duration(seconds: 2));
      return addresses.isNotEmpty && addresses.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _applyStatus({required bool offline, bool notify = true}) {
    final bool nextCached = offline ? _isUsingCachedData : false;
    final bool changed =
        _isOffline != offline || _isUsingCachedData != nextCached;
    _isOffline = offline;
    _isUsingCachedData = nextCached;
    if (notify && changed) {
      notifyListeners();
    }
  }

  /// Memeriksa ulang status jaringan secara manual (dipanggil dari tombol "Cek"
  /// di banner offline atau pull-to-refresh). Mengembalikan `true` jika online.
  Future<bool> refreshStatus() async {
    if (_isChecking) return isOnline;

    _isChecking = true;
    notifyListeners();

    try {
      bool interfaceAvailable = true;
      try {
        final conn = _connectivity ?? Connectivity();
        final results = await conn.checkConnectivity();
        interfaceAvailable = hasActiveInterface(results);
      } catch (_) {
        // Pada unit test tanpa channel OS, lanjutkan langsung ke probe.
        interfaceAvailable = true;
      }

      if (!interfaceAvailable) {
        _applyStatus(offline: true, notify: false);
      } else {
        final reachable = await _probeInternet();
        _applyStatus(offline: !reachable, notify: false);
      }
    } finally {
      _isChecking = false;
      notifyListeners();
    }

    return isOnline;
  }

  /// Menandai bahwa data yang sedang ditampilkan berasal dari cache Firestore.
  void markUsingCachedData() {
    if (!_isUsingCachedData) {
      _isUsingCachedData = true;
      notifyListeners();
    }
  }

  /// Menandai koneksi terkonfirmasi online setelah pembacaan server berhasil.
  void markOnlineFromServer() {
    if (_isOffline || _isUsingCachedData) {
      _isOffline = false;
      _isUsingCachedData = false;
      notifyListeners();
    }
  }

  /// Menandai perangkat sedang offline ketika request server gagal/timeout.
  void markOfflineFromError() {
    if (!_isOffline || !_isUsingCachedData) {
      _isOffline = true;
      _isUsingCachedData = true;
      notifyListeners();
    }
  }

  @visibleForTesting
  void setTestState({
    bool? isOffline,
    bool? isUsingCachedData,
    Future<bool> Function()? reachabilityProbe,
  }) {
    if (isOffline != null) _isOffline = isOffline;
    if (isUsingCachedData != null) _isUsingCachedData = isUsingCachedData;
    if (reachabilityProbe != null) {
      _reachabilityProbeOverride = reachabilityProbe;
    }
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _connectivity = null;
    _reachabilityProbeOverride = null;
    _initialized = false;
    _isOffline = false;
    _isChecking = false;
    _isUsingCachedData = false;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
