import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../data/mission_catalog.dart';
import '../models/mission_model.dart';
import '../services/connectivity_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import 'user_provider.dart';

class MissionProvider extends ChangeNotifier {
  final FirebaseFirestore? _firestore;
  final Future<Map<String, dynamic>?> Function(String uid)? _loadDocOverride;
  final Future<void> Function(String uid, Map<String, dynamic> data)?
      _saveDocOverride;

  MissionProvider({
    FirebaseFirestore? firestore,
    Future<Map<String, dynamic>?> Function(String uid)? onLoad,
    Future<void> Function(String uid, Map<String, dynamic> data)? onSave,
  })  : _firestore = firestore,
        _loadDocOverride = onLoad,
        _saveDocOverride = onSave;

  String? _uid;
  UserProvider? _userProvider;
  bool _isLoading = false;
  String? _claimingId;

  Map<String, int> _counters = {};
  Set<String> _claimedKeys = {};
  DateTime? _weeklyAnchor;
  DateTime? _monthlyAnchor;
  int? _verifiedModulesCount;
  int? _verifiedQuizzesCount;

  int _streakCount = 0;
  DateTime? _lastStreakDate;
  int? _brokenStreakCount;

  bool get isLoading => _isLoading;
  String? get claimingId => _claimingId;
  int get streakCount => _streakCount;
  int? get brokenStreakCount => _brokenStreakCount;

  void dismissBrokenStreakNotice() {
    _brokenStreakCount = null;
    notifyListeners();
  }

  bool get isStreakActiveToday {
    if (_lastStreakDate == null || _streakCount <= 0) return false;
    return _todayMidnight().difference(_todayMidnight(_lastStreakDate)).inDays ==
        0;
  }

  int get streakBonusPercent {
    if (_streakCount >= 100) return 50;
    if (_streakCount >= 20) return 30;
    if (_streakCount >= 10) return 20;
    if (_streakCount >= 5) return 10;
    return 0;
  }

  int effectiveXpReward(MissionItem mission) {
    final bonus = streakBonusPercent;
    if (bonus <= 0) return mission.xpReward;
    return (mission.xpReward * (100 + bonus) / 100).round();
  }

  bool get hasCompletedAnyDailyToday {
    final dailyMissions = MissionCatalog.byPeriod(MissionPeriod.daily);
    return dailyMissions.any(
      (m) => statusOf(m) != MissionClaimStatus.inProgress,
    );
  }

  void bindDependencies(String? newUid, UserProvider userProvider) {
    _userProvider = userProvider;

    if (_uid != newUid) {
      _uid = newUid;
      _counters = {};
      _claimedKeys = {};
      _weeklyAnchor = null;
      _monthlyAnchor = null;
      _verifiedModulesCount = null;
      _verifiedQuizzesCount = null;
      _streakCount = 0;
      _lastStreakDate = null;
      _brokenStreakCount = null;

      if (newUid == null) {
        _isLoading = false;
        Future.microtask(notifyListeners);
        return;
      }

      _isLoading = true;
      Future.microtask(() {
        if (_uid == newUid) loadMissions();
      });
      return;
    }

    if (!_isLoading && _uid != null && _syncOneTimeFromProfile()) {
      _persist();
      Future.microtask(notifyListeners);
    }
  }

  DocumentReference<Map<String, dynamic>> _docRef(String uid) {
    final db = _firestore ?? FirebaseFirestore.instance;
    return db
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
  bool _refreshStreakState() {
    final today = _todayMidnight();
    bool changed = false;

    if (_lastStreakDate != null) {
      final last = _todayMidnight(_lastStreakDate);
      final diffDays = today.difference(last).inDays;
      if (diffDays > 1 && _streakCount > 0) {
        _brokenStreakCount = _streakCount;
        _streakCount = 0;
        changed = true;
      }
    }

    if (hasCompletedAnyDailyToday) {
      if (_lastStreakDate == null) {
        _streakCount = 1;
        _lastStreakDate = today;
        changed = true;
      } else {
        final last = _todayMidnight(_lastStreakDate);
        final diffDays = today.difference(last).inDays;
        if (diffDays == 1) {
          _streakCount += 1;
          _lastStreakDate = today;
          changed = true;
        } else if (diffDays > 1 || _streakCount == 0) {
          _streakCount = 1;
          _lastStreakDate = today;
          changed = true;
        }
      }
    }

    return changed;
  }

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

  int? _effectiveCompletedModulesCount() {
    if (_verifiedModulesCount != null) return _verifiedModulesCount;
    final profile = _userProvider?.profile;
    if (profile != null && profile.uid == _uid) {
      return profile.completedModules.length;
    }
    return null;
  }

  int? _effectiveCompletedQuizzesCount() {
    if (_verifiedQuizzesCount != null) return _verifiedQuizzesCount;
    final profile = _userProvider?.profile;
    if (profile != null && profile.uid == _uid) {
      return profile.completedQuizzes.length;
    }
    return null;
  }

  bool _syncOneTimeFromProfile() {
    final modulesCount = _effectiveCompletedModulesCount();
    final quizzesCount = _effectiveCompletedQuizzesCount();
    if (modulesCount == null || quizzesCount == null) return false;
    return _applyOneTimeLearningCounts(modulesCount, quizzesCount);
  }

  bool _applyOneTimeLearningCounts(int modulesCount, int quizzesCount) {
    bool changed = false;
    final moduleKey = _counterKey(
      MissionPeriod.oneTime,
      MissionTrigger.completeModule,
    );
    final quizKey = _counterKey(
      MissionPeriod.oneTime,
      MissionTrigger.passQuiz,
    );

    if (_counters[moduleKey] != modulesCount) {
      _counters[moduleKey] = modulesCount;
      changed = true;
    }

    if (_counters[quizKey] != quizzesCount) {
      _counters[quizKey] = quizzesCount;
      changed = true;
    }

    for (final mission in MissionCatalog.byPeriod(MissionPeriod.oneTime)) {
      late final int validProgress;
      if (mission.trigger == MissionTrigger.completeModule) {
        validProgress = modulesCount;
      } else if (mission.trigger == MissionTrigger.passQuiz) {
        validProgress = quizzesCount;
      } else {
        validProgress =
            _counters[_counterKey(mission.period, mission.trigger)] ?? 0;
      }

      if (validProgress < mission.targetCount &&
          _claimedKeys.remove(_claimKey(mission))) {
        changed = true;
      }
    }

    return changed;
  }

  Future<void> syncOneTimeLearningProgress({
    required int completedModulesCount,
    required int completedQuizzesCount,
  }) async {
    _verifiedModulesCount = completedModulesCount;
    _verifiedQuizzesCount = completedQuizzesCount;
    if (_uid == null || _isLoading) return;
    if (_applyOneTimeLearningCounts(
      completedModulesCount,
      completedQuizzesCount,
    )) {
      notifyListeners();
      await _persist();
    }
  }

  int currentProgress(MissionItem mission) {
    int raw = _counters[_counterKey(mission.period, mission.trigger)] ?? 0;
    if (mission.period == MissionPeriod.oneTime) {
      if (mission.trigger == MissionTrigger.completeModule) {
        final effective = _effectiveCompletedModulesCount();
        if (effective != null) raw = effective;
      } else if (mission.trigger == MissionTrigger.passQuiz) {
        final effective = _effectiveCompletedQuizzesCount();
        if (effective != null) raw = effective;
      }
    }
    return raw > mission.targetCount ? mission.targetCount : raw;
  }

  MissionClaimStatus statusOf(MissionItem mission) {
    final progress = currentProgress(mission);
    if (_claimedKeys.contains(_claimKey(mission)) &&
        progress >= mission.targetCount) {
      return MissionClaimStatus.claimed;
    }
    if (progress >= mission.targetCount) {
      return MissionClaimStatus.claimable;
    }
    return MissionClaimStatus.inProgress;
  }

  int get claimableCount => MissionCatalog.all
      .where((m) => statusOf(m) == MissionClaimStatus.claimable)
      .length;

  int get claimableTotalXp => MissionCatalog.all
      .where((m) => statusOf(m) == MissionClaimStatus.claimable)
      .fold(0, (total, m) => total + effectiveXpReward(m));


  Future<void> loadMissions() async {
    final targetUid = _uid;
    if (targetUid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      Object? rawData;
      if (_loadDocOverride != null) {
        rawData = await _loadDocOverride(targetUid);
      } else if (_firestore != null) {
        final snap = await _docRef(targetUid).get();
        rawData = snap.data();
      } else {
        try {
          final snap = await FirestoreService.instance
              .getDocumentSnapshot(_docRef(targetUid));
          rawData = snap.data();
        } on OfflineException {
          rawData = null;
        }
      }
      if (_uid != targetUid) return;

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
      _streakCount = (data['streakCount'] as num?)?.toInt() ?? 0;
      final rawLastStreak = data['lastStreakDate'] as String?;
      _lastStreakDate = rawLastStreak != null
          ? _todayMidnight(DateTime.tryParse(rawLastStreak))
          : null;

      _counters = rawCounters.map((k, v) => MapEntry(k, (v as num).toInt()));
      _claimedKeys = Set<String>.from(data['claimedKeys'] ?? const []);

      final anchorUpdated = _ensureValidAnchors();
      final keysPruned = _pruneExpiredKeys();
      final profileSynced = _syncOneTimeFromProfile();
      final streakUpdated = _refreshStreakState();
      if (anchorUpdated || keysPruned || profileSynced || streakUpdated) {
        await _persist();
      }
      unawaited(
        NotificationService.instance.syncDailyMissionReminder(
          hasCompletedAnyDailyToday: hasCompletedAnyDailyToday,
        ),
      );
    } catch (e) {
      debugPrint('Gagal memuat misi: $e');
    } finally {
      if (_uid == targetUid) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _persist({bool rethrowOnError = false}) async {
    final targetUid = _uid;
    if (targetUid == null) return;
    _ensureValidAnchors();
    try {
      final payload = <String, dynamic>{
        'weeklyAnchor': _formatDate(_weeklyAnchor!),
        'monthlyAnchor': _formatDate(_monthlyAnchor!),
        'streakCount': _streakCount,
        'lastStreakDate':
            _lastStreakDate != null ? _formatDate(_lastStreakDate!) : null,
        'counters': Map<String, int>.from(_counters),
        'claimedKeys': _claimedKeys.toList(),
      };
      if (_saveDocOverride != null) {
        await _saveDocOverride(targetUid, payload);
      } else {
        if (_firestore == null) {
          FirestoreService.instance.ensureOnline(
            actionLabel: 'menyimpan progres misi',
          );
        }
        payload['updatedAt'] = FieldValue.serverTimestamp();
        await _docRef(targetUid).set(payload);
      }
    } catch (e) {
      if (rethrowOnError) rethrow;
      debugPrint('Gagal menyimpan progres misi: $e');
    }
  }

  Future<void> recordTrigger(MissionTrigger trigger, {int amount = 1}) async {
    if (_uid == null || amount <= 0) return;

    _ensureValidAnchors();
    _pruneExpiredKeys();

    for (final period in MissionPeriod.values) {
      if (period == MissionPeriod.oneTime &&
          ((trigger == MissionTrigger.completeModule &&
                  _effectiveCompletedModulesCount() != null) ||
              (trigger == MissionTrigger.passQuiz &&
                  _effectiveCompletedQuizzesCount() != null))) {
        continue;
      }
      final key = _counterKey(period, trigger);
      _counters[key] = (_counters[key] ?? 0) + amount;
    }
    _refreshStreakState();
    notifyListeners();
    unawaited(
      NotificationService.instance.syncDailyMissionReminder(
        hasCompletedAnyDailyToday: hasCompletedAnyDailyToday,
      ),
    );
    await _persist();
  }

  Future<void> grantDirectXp(int xp) async {
    if (_uid == null || xp <= 0 || _userProvider == null) return;
    await _userProvider!.addXp(xp);
  }

  Future<int> claimMission(MissionItem mission) async {
    if (_uid == null || _claimingId != null) return 0;
    if (statusOf(mission) != MissionClaimStatus.claimable) return 0;

    if (_saveDocOverride == null && _firestore == null) {
      FirestoreService.instance.ensureOnline(
        actionLabel: 'mengklaim hadiah XP',
      );
    }

    _claimingId = mission.id;
    notifyListeners();

    final rewardXp = effectiveXpReward(mission);
    try {
      _claimedKeys.add(_claimKey(mission));
      await _persist(rethrowOnError: true);
      if (_userProvider != null) {
        final gained = await _userProvider!.addXp(rewardXp);
        if (gained == null) {
          throw const OfflineException(
            'Gagal mengklaim hadiah XP. Periksa koneksi internetmu lalu coba lagi.',
          );
        }
      }
      unawaited(
        NotificationService.instance.syncDailyMissionReminder(
          hasCompletedAnyDailyToday: hasCompletedAnyDailyToday,
        ),
      );
      return rewardXp;
    } catch (e) {
      _claimedKeys.remove(_claimKey(mission));
      rethrow;
    } finally {
      _claimingId = null;
      notifyListeners();
    }
  }

  Future<int> claimAllMissions() async {
    if (_uid == null || _claimingId != null) return 0;
    final claimables = MissionCatalog.all
        .where((m) => statusOf(m) == MissionClaimStatus.claimable)
        .toList();
    if (claimables.isEmpty) return 0;

    if (_saveDocOverride == null && _firestore == null) {
      FirestoreService.instance.ensureOnline(
        actionLabel: 'mengklaim semua hadiah XP',
      );
    }

    _claimingId = 'ALL';
    notifyListeners();

    final addedKeys = <String>[];
    int totalXp = 0;
    for (final m in claimables) {
      final k = _claimKey(m);
      _claimedKeys.add(k);
      addedKeys.add(k);
      totalXp += effectiveXpReward(m);
    }

    try {
      await _persist(rethrowOnError: true);
      if (_userProvider != null) {
        final gained = await _userProvider!.addXp(totalXp);
        if (gained == null) {
          throw const OfflineException(
            'Gagal mengklaim hadiah XP. Periksa koneksi internetmu lalu coba lagi.',
          );
        }
      }
      unawaited(
        NotificationService.instance.syncDailyMissionReminder(
          hasCompletedAnyDailyToday: hasCompletedAnyDailyToday,
        ),
      );
      return totalXp;
    } catch (e) {
      for (final k in addedKeys) {
        _claimedKeys.remove(k);
      }
      rethrow;
    } finally {
      _claimingId = null;
      notifyListeners();
    }
  }

}
