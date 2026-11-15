import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../data/mission_catalog.dart';
import '../models/mission_model.dart';
import 'user_provider.dart';

class MissionProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;

  MissionProvider({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  String? _uid;
  UserProvider? _userProvider;
  bool _isLoading = false;
  String? _claimingId;

  Map<String, int> _counters = {};
  Set<String> _claimedKeys = {};
  DateTime? _weeklyAnchor;
  DateTime? _monthlyAnchor;

  bool get isLoading => _isLoading;
  String? get claimingId => _claimingId;

  void bindDependencies(String? newUid, UserProvider userProvider) {
    _userProvider = userProvider;

    if (_uid != newUid) {
      _uid = newUid;
      _counters = {};
      _claimedKeys = {};
      _weeklyAnchor = null;
      _monthlyAnchor = null;

      if (newUid == null) {
        _isLoading = false;
        Future.microtask(notifyListeners);
        return;
      }

      _isLoading = true;
      Future.microtask(() {
        if (_uid == newUid) loadMissions();
      });
    }
  }

  DocumentReference _docRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('gamification')
        .doc('missions');
  }

  DateTime _todayMidnight([DateTime? ref]) {
    final d = ref ?? DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  bool _ensureValidAnchors() {
    final today = _todayMidnight();
    bool changed = false;

    if (_weeklyAnchor == null) {
      _weeklyAnchor = today;
      changed = true;
    } else {
      final elapsedDays = today.difference(_weeklyAnchor!).inDays;
      if (elapsedDays >= 7) {
        final cyclesPassed = elapsedDays ~/ 7;
        _weeklyAnchor = _weeklyAnchor!.add(Duration(days: cyclesPassed * 7));
        changed = true;
      }
    }

    if (_monthlyAnchor == null) {
      _monthlyAnchor = today;
      changed = true;
    } else {
      final elapsedDays = today.difference(_monthlyAnchor!).inDays;
      if (elapsedDays >= 30) {
        final cyclesPassed = elapsedDays ~/ 30;
        _monthlyAnchor = _monthlyAnchor!.add(Duration(days: cyclesPassed * 30));
        changed = true;
      }
    }

    return changed;
  }

  DateTime? nextResetAt(MissionPeriod period) {
    _ensureValidAnchors();
    final now = DateTime.now();

    switch (period) {
      case MissionPeriod.daily:
        return DateTime(now.year, now.month, now.day + 1);
      case MissionPeriod.weekly:
        return (_weeklyAnchor ?? _todayMidnight()).add(const Duration(days: 7));
      case MissionPeriod.monthly:
        return (_monthlyAnchor ?? _todayMidnight())
            .add(const Duration(days: 30));
      case MissionPeriod.oneTime:
        return null;
    }
  }

  String _periodKey(MissionPeriod period) {
    _ensureValidAnchors();
    final now = DateTime.now();

    switch (period) {
      case MissionPeriod.daily:
        return 'daily:${_formatDate(now)}';
      case MissionPeriod.weekly:
        return 'weekly:${_formatDate(_weeklyAnchor ?? _todayMidnight())}';
      case MissionPeriod.monthly:
        return 'monthly:${_formatDate(_monthlyAnchor ?? _todayMidnight())}';
      case MissionPeriod.oneTime:
        return 'oneTime';
    }
  }

  bool _pruneExpiredKeys() {
    final activePrefixes = {
      _periodKey(MissionPeriod.daily),
      _periodKey(MissionPeriod.weekly),
      _periodKey(MissionPeriod.monthly),
      _periodKey(MissionPeriod.oneTime),
    };

    bool isValidKey(String key) {
      if (key.startsWith('oneTime:')) return true;
      return activePrefixes.any((prefix) => key.startsWith('$prefix:'));
    }

    final oldCounterLen = _counters.length;
    final oldClaimedLen = _claimedKeys.length;

    _counters.removeWhere((k, _) => !isValidKey(k));
    _claimedKeys.removeWhere((k) => !isValidKey(k));

    return _counters.length != oldCounterLen ||
        _claimedKeys.length != oldClaimedLen;
  }

  String _counterKey(MissionPeriod period, MissionTrigger trigger) =>
      '${_periodKey(period)}:${trigger.name}';

  String _claimKey(MissionItem mission) =>
      '${_periodKey(mission.period)}:${mission.id}';

  int currentProgress(MissionItem mission) {
    final raw = _counters[_counterKey(mission.period, mission.trigger)] ?? 0;
    return raw > mission.targetCount ? mission.targetCount : raw;
  }

  MissionClaimStatus statusOf(MissionItem mission) {
    if (_claimedKeys.contains(_claimKey(mission))) {
      return MissionClaimStatus.claimed;
    }
    if (currentProgress(mission) >= mission.targetCount) {
      return MissionClaimStatus.claimable;
    }
    return MissionClaimStatus.inProgress;
  }

  int get claimableCount => MissionCatalog.all
      .where((m) => statusOf(m) == MissionClaimStatus.claimable)
      .length;

  Future<void> loadMissions() async {
    final targetUid = _uid;
    if (targetUid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final snap = await _docRef(targetUid).get();
      if (_uid != targetUid) return;

      final rawData = snap.data();
      final data = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};

      final rawWeekly = data['weeklyAnchor'] as String?;
      final rawMonthly = data['monthlyAnchor'] as String?;
      _weeklyAnchor = rawWeekly != null
          ? _todayMidnight(DateTime.tryParse(rawWeekly))
          : null;
      _monthlyAnchor = rawMonthly != null
          ? _todayMidnight(DateTime.tryParse(rawMonthly))
          : null;

      final rawCounters = data['counters'] is Map
          ? Map<String, dynamic>.from(data['counters'] as Map)
          : <String, dynamic>{};
      _counters = rawCounters.map((k, v) => MapEntry(k, (v as num).toInt()));
      _claimedKeys = Set<String>.from(data['claimedKeys'] ?? const []);

      final anchorUpdated = _ensureValidAnchors();
      final keysPruned = _pruneExpiredKeys();
      if (anchorUpdated || keysPruned) {
        await _persist();
      }
    } catch (e) {
      debugPrint('Gagal memuat misi: $e');
    } finally {
      if (_uid == targetUid) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _persist() async {
    final targetUid = _uid;
    if (targetUid == null) return;
    _ensureValidAnchors();
    try {
      await _docRef(targetUid).set({
        'weeklyAnchor': _formatDate(_weeklyAnchor!),
        'monthlyAnchor': _formatDate(_monthlyAnchor!),
        'counters': _counters,
        'claimedKeys': _claimedKeys.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Gagal menyimpan progres misi: $e');
    }
  }

  Future<void> recordTrigger(MissionTrigger trigger, {int amount = 1}) async {
    if (_uid == null || amount <= 0) return;

    _ensureValidAnchors();
    _pruneExpiredKeys();

    for (final period in MissionPeriod.values) {
      final key = _counterKey(period, trigger);
      _counters[key] = (_counters[key] ?? 0) + amount;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> grantDirectXp(int xp) async {
    if (_uid == null || xp <= 0 || _userProvider == null) return;
    await _userProvider!.addXp(xp);
  }

  Future<bool> claimMission(MissionItem mission) async {
    if (_uid == null || _claimingId != null) return false;
    if (statusOf(mission) != MissionClaimStatus.claimable) return false;

    _claimingId = mission.id;
    notifyListeners();

    try {
      _claimedKeys.add(_claimKey(mission));
      await _persist();
      if (_userProvider != null) {
        await _userProvider!.addXp(mission.xpReward);
      }
      return true;
    } catch (e) {
      _claimedKeys.remove(_claimKey(mission));
      rethrow;
    } finally {
      _claimingId = null;
      notifyListeners();
    }
  }
}
