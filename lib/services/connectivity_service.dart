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
/// terdeteksi sebagai mode offline, serta memulihkan status online otomatis
/// apabila DNS/jaringan sempat terlambat siap saat cold-start.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  static const Duration defaultProbeTimeout = Duration(seconds: 4);
  static const Duration fallbackProbeTimeout = Duration(seconds: 2);
  static const List<Duration> recoveryBackoffDelays = [
    Duration(seconds: 3),
    Duration(seconds: 6),
    Duration(seconds: 12),
    Duration(seconds: 20),
  ];

  bool _initialized = false;
  bool _isOffline = false;
  bool _isChecking = false;
  bool _isUsingCachedData = false;
  bool _hasActiveInterface = true;
  bool _autoRecoveryEnabled = false;
  bool _isAppForeground = true;

  Connectivity? _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Future<bool> Function()? _reachabilityProbeOverride;
  Timer? _recoveryTimer;
  int _recoveryAttempt = 0;
  List<Duration> _recoveryDelays = recoveryBackoffDelays;

  bool get isOffline => _isOffline;
  bool get isOnline => !_isOffline;
  bool get isChecking => _isChecking;
  bool get isUsingCachedData => _isUsingCachedData;
  bool get hasPendingRecoveryRetry => _recoveryTimer?.isActive ?? false;

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
    bool autoRecovery = true,
    List<Duration>? recoveryDelays,
  }) async {
    if (_initialized) return;
    _initialized = true;
    _autoRecoveryEnabled = autoRecovery;
    _reachabilityProbeOverride = reachabilityProbe;
    if (recoveryDelays != null && recoveryDelays.isNotEmpty) {
      _recoveryDelays = recoveryDelays;
    }

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
    final active = hasActiveInterface(results);
    _hasActiveInterface = active;

    if (!active) {
      _cancelRecoveryRetry();
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

    if (await _lookupHost('firestore.googleapis.com', defaultProbeTimeout)) {
      return true;
    }
    // Fallback satu kali ke host DNS publik untuk mengantisipasi DNS cold-start
    // pada emulator Android atau router yang baru bangun dari sleep.
    return _lookupHost('dns.google', fallbackProbeTimeout);
  }

  Future<bool> _lookupHost(String host, Duration timeout) async {
    try {
      final addresses = await InternetAddress.lookup(host).timeout(timeout);
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

    if (!offline || !_hasActiveInterface) {
      _cancelRecoveryRetry();
    } else {
      _scheduleRecoveryRetry();
    }

    if (notify && changed) {
      notifyListeners();
    }
  }

  void _scheduleRecoveryRetry() {
    if (!_autoRecoveryEnabled ||
        !_isAppForeground ||
        !_isOffline ||
        !_hasActiveInterface) {
      return;
    }
    if (_recoveryTimer?.isActive ?? false) return;

    final int index = _recoveryAttempt.clamp(0, _recoveryDelays.length - 1);
    final Duration delay = _recoveryDelays[index];
    _recoveryAttempt++;

    _recoveryTimer = Timer(delay, () {
      _recoveryTimer = null;
      if (!_isOffline ||
          !_isAppForeground ||
          !_autoRecoveryEnabled ||
          !_hasActiveInterface) {
        return;
      }
      unawaited(refreshStatus(silent: true));
    });
  }

  void _cancelRecoveryRetry() {
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _recoveryAttempt = 0;
  }

  /// Memberi tahu service status foreground/background aplikasi agar timer
  /// auto-recovery dijeda saat di background dan langsung mengecek ulang
  /// ketika aplikasi kembali aktif.
  void setAppForeground(bool isForeground) {
    if (_isAppForeground == isForeground) return;
    _isAppForeground = isForeground;

    if (!isForeground) {
      _cancelRecoveryRetry();
      return;
    }

    if (_isOffline && _autoRecoveryEnabled) {
      _recoveryAttempt = 0;
      unawaited(refreshStatus(silent: true));
    }
  }

  /// Memeriksa ulang status jaringan secara manual (dipanggil dari tombol "Cek"
  /// di banner offline atau pull-to-refresh) maupun secara senyap (`silent: true`)
  /// oleh auto-recovery. Mengembalikan `true` jika online.
  Future<bool> refreshStatus({bool silent = false}) async {
    if (_isChecking) return isOnline;

    final bool prevOffline = _isOffline;
    final bool prevCached = _isUsingCachedData;

    _isChecking = true;
    if (!silent) {
      notifyListeners();
    }

    try {
      bool interfaceAvailable = true;
      if (_connectivity != null || _reachabilityProbeOverride == null) {
        try {
          final conn = _connectivity ?? Connectivity();
          final results = await conn.checkConnectivity();
          interfaceAvailable = hasActiveInterface(results);
        } catch (_) {
          // Pada unit test tanpa channel OS, lanjutkan langsung ke probe.
          interfaceAvailable = true;
        }
      }

      _hasActiveInterface = interfaceAvailable;
      if (!interfaceAvailable) {
        _applyStatus(offline: true, notify: false);
      } else {
        final reachable = await _probeInternet();
        _applyStatus(offline: !reachable, notify: false);
      }
    } finally {
      _isChecking = false;
      final bool statusChanged =
          prevOffline != _isOffline || prevCached != _isUsingCachedData;
      if (!silent || statusChanged) {
        notifyListeners();
      }
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
    _cancelRecoveryRetry();
    if (_isOffline || _isUsingCachedData) {
      _isOffline = false;
      _isUsingCachedData = false;
      notifyListeners();
    }
  }

  /// Menandai perangkat sedang offline ketika request server gagal/timeout.
  void markOfflineFromError() {
    final bool changed = !_isOffline || !_isUsingCachedData;
    _isOffline = true;
    _isUsingCachedData = true;
    if (_hasActiveInterface) {
      _scheduleRecoveryRetry();
    }
    if (changed) {
      notifyListeners();
    }
  }

  @visibleForTesting
  void setTestState({
    bool? isOffline,
    bool? isUsingCachedData,
    bool? hasActiveInterface,
    bool? autoRecoveryEnabled,
    List<Duration>? recoveryDelays,
    Future<bool> Function()? reachabilityProbe,
  }) {
    if (hasActiveInterface != null) _hasActiveInterface = hasActiveInterface;
    if (autoRecoveryEnabled != null) {
      _autoRecoveryEnabled = autoRecoveryEnabled;
      if (!autoRecoveryEnabled) _cancelRecoveryRetry();
    }
    if (recoveryDelays != null && recoveryDelays.isNotEmpty) {
      _recoveryDelays = recoveryDelays;
    }
    if (isOffline != null) _isOffline = isOffline;
    if (isUsingCachedData != null) _isUsingCachedData = isUsingCachedData;
    if (reachabilityProbe != null) {
      _reachabilityProbeOverride = reachabilityProbe;
    }
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting() {
    _cancelRecoveryRetry();
    unawaited(_subscription?.cancel());
    _subscription = null;
    _connectivity = null;
    _reachabilityProbeOverride = null;
    _initialized = false;
    _isOffline = false;
    _isChecking = false;
    _isUsingCachedData = false;
    _hasActiveInterface = true;
    _autoRecoveryEnabled = false;
    _isAppForeground = true;
    _recoveryDelays = recoveryBackoffDelays;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelRecoveryRetry();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
