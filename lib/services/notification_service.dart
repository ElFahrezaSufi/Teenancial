import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/recurring_model.dart';
import '../models/transaction_model.dart';
import '../repositories/recurring_repository.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_helper.dart';
import '../utils/loan_helper.dart';
import 'local_storage_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionRequested = false;

  List<TransactionModel> _cachedTransactions = const [];
  List<RecurringModel> _cachedRecurring = const [];
  bool _hasCompletedDailyMissionToday = false;

  static const String _channelId = 'teenancial_loan_reminders';
  static const String _channelName = 'Pengingat Keuangan & Misi Teenancial';
  static const String _channelDescription =
      'Notifikasi pencatatan transaksi, pengingat pinjaman/berulang, dan misi harian Feen.';

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    try {
      tz_data.initializeTimeZones();
      try {
        final timezoneInfo = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      }

      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );

      await _plugin.initialize(settings: initSettings);
      _initialized = true;
    } catch (e) {
      debugPrint('Gagal menginisialisasi NotificationService: $e');
    }
  }

  Future<void> requestPermissionIfNeeded() async {
    if (!_initialized || kIsWeb || _permissionRequested) return;
    _permissionRequested = true;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Gagal meminta izin notifikasi: $e');
    }
  }

  int _hashId(String key) {
    int hash = 0x811c9dc5;
    for (int i = 0; i < key.length; i++) {
      hash ^= key.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  int _dayBeforeId(String loanId) => _hashId('loan_h1_$loanId');
  int _dueDayId(String loanId) => _hashId('loan_h0_$loanId');
  int _instantId(String key) => _hashId('loan_instant_$key');
  int _txInstantId(String key) => _hashId('tx_instant_$key');
  int _recurringScheduledId(String recurringId) =>
      _hashId('rec_sched_$recurringId');
  int _recurringInstantId(String key) => _hashId('rec_instant_$key');
  int get _dailyMissionReminderId => _hashId('daily_mission_reminder_20h');
  int get _dailyMissionInstantId => _hashId('daily_mission_reminder_instant');

  Future<void> _dailyReminderQueue = Future.value();
  String? _inMemoryLastRemindedDate;
  String? _inMemoryArmedDate;

  static String _formatDateKey(DateTime dt) {
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$month-$day';
  }

  /// Menghitung jadwal alarm berulang pukul 20:00 (`DateTimeComponents.time`)
  /// serta apakah pengingat instan jendela 20:00–23:59 perlu ditampilkan saat
  /// aplikasi dibuka (maksimal 1x/hari bila belum ada misi harian selesai).
  @visibleForTesting
  static DailyMissionReminderPlan buildDailyMissionReminderPlan({
    required DateTime now,
    required bool hasCompletedAnyDailyToday,
    String? lastRemindedDate,
    String? armedDate,
    bool hasActiveDailyMissionNotification = false,
  }) {
    final todayStr = _formatDateKey(now);
    final eightPmToday = DateTime(now.year, now.month, now.day, 20);
    final isBeforeEightPm = eightPmToday.isAfter(now);

    if (hasCompletedAnyDailyToday) {
      return DailyMissionReminderPlan(
        scheduledDate: eightPmToday.add(const Duration(days: 1)),
        shouldShowInstantNow: false,
        lastRemindedDateToRecord: lastRemindedDate,
        shouldClearArmedDate: true,
      );
    }

    if (isBeforeEightPm) {
      return DailyMissionReminderPlan(
        scheduledDate: eightPmToday,
        shouldShowInstantNow: false,
        lastRemindedDateToRecord: lastRemindedDate,
        armedDateToRecord: todayStr,
        shouldClearArmedDate: false,
      );
    }

    final alreadyCoveredToday =
        lastRemindedDate == todayStr ||
        armedDate == todayStr ||
        hasActiveDailyMissionNotification;

    return DailyMissionReminderPlan(
      scheduledDate: eightPmToday.add(const Duration(days: 1)),
      shouldShowInstantNow: !alreadyCoveredToday,
      lastRemindedDateToRecord: todayStr,
      shouldClearArmedDate: true,
    );
  }

  /// Menampilkan notifikasi instan saat transaksi Pemasukan, Pengeluaran, atau Transfer berhasil disimpan.
  Future<void> showTransactionSavedNotification(TransactionModel tx) async {
    if (kIsWeb ||
        tx.isBalanceAdjustment ||
        !LocalStorageService.instance.dailyReminderEnabled) {
      return;
    }
    if (!_initialized) {
      await init();
    }
    if (!_initialized) return;

    try {
      await requestPermissionIfNeeded();

      final formattedAmount = Formatters.rupiah(tx.amount);
      final label = tx.title.trim().isNotEmpty ? tx.title.trim() : 'Transaksi';
      late final String title;
      late final String body;

      switch (tx.type) {
        case TransactionType.income:
          title = '💰 Pemasukan Tercatat!';
          body =
              'Pemasukan $formattedAmount ("$label") berhasil ditambahkan ke dompetmu.';
          break;
        case TransactionType.expense:
          title = '💸 Pengeluaran Tercatat';
          body =
              'Pengeluaran $formattedAmount untuk "$label" telah berhasil dicatat.';
          break;
        case TransactionType.transfer:
          final isSelfTransfer = tx.destinationDompetId != null &&
              tx.destinationDompetId!.isNotEmpty;
          if (isSelfTransfer) {
            title = '🔄 Transfer Antar Dompet Berhasil';
            body =
                'Dana sebesar $formattedAmount berhasil dipindahkan antar dompetmu.';
          } else {
            final target = (tx.counterpartyName != null &&
                    tx.counterpartyName!.trim().isNotEmpty)
                ? tx.counterpartyName!.trim()
                : label;
            title = '📤 Transfer Berhasil Dicatat';
            body =
                'Transfer $formattedAmount ke $target telah berhasil dicatat.';
          }
          break;
        case TransactionType.debt:
        case TransactionType.receivable:
          return;
      }

      final idKey = tx.id.isNotEmpty
          ? tx.id
          : '${tx.type.name}_${DateTime.now().millisecondsSinceEpoch}';

      await _plugin.show(
        id: _txInstantId(idKey),
        title: title,
        body: body,
        notificationDetails: _notificationDetails,
        payload: 'tx_${tx.type.name}',
      );
    } catch (e) {
      debugPrint('Gagal menampilkan notifikasi transaksi baru: $e');
    }
  }

  /// Menampilkan notifikasi instan saat cicilan atau pelunasan pinjaman/piutang berhasil dicatat.
  Future<void> showLoanPaymentNotification({
    required TransactionModel loan,
    required double paymentAmount,
    bool forceSettled = false,
  }) async {
    if (kIsWeb || !LocalStorageService.instance.dailyReminderEnabled) return;
    if (!_initialized) {
      await init();
    }
    if (!_initialized) return;

    try {
      await requestPermissionIfNeeded();

      final isDebt = loan.type == TransactionType.debt;
      final counterparty = LoanHelper.counterpartyName(loan);
      final remainingAfter = forceSettled
          ? 0.0
          : (loan.remainingAmount - paymentAmount).clamp(0.0, double.infinity);
      final isNowPaid = forceSettled || remainingAfter <= 0.0001;

      late final String title;
      late final String body;

      if (isNowPaid) {
        final formattedTotal = Formatters.rupiah(loan.amount);
        title = isDebt ? '🎉 Hutang Lunas!' : '🎉 Piutang Lunas!';
        body = isDebt
            ? 'Selamat! Hutang sebesar $formattedTotal kepada $counterparty telah lunas sepenuhnya.'
            : 'Piutang sebesar $formattedTotal dari $counterparty telah lunas sepenuhnya.';
      } else {
        final formattedPay = Formatters.rupiah(paymentAmount);
        final formattedRem = Formatters.rupiah(remainingAfter);
        title = isDebt
            ? '🧾 Cicilan Hutang Tercatat'
            : '🧾 Cicilan Piutang Tercatat';
        body = isDebt
            ? 'Cicilan $formattedPay kepada $counterparty berhasil dicatat. Sisa hutang: $formattedRem.'
            : 'Cicilan $formattedPay dari $counterparty berhasil dicatat. Sisa piutang: $formattedRem.';
      }

      final idKey =
          '${loan.id}_pay_${DateTime.now().millisecondsSinceEpoch}';

      await _plugin.show(
        id: _txInstantId(idKey),
        title: title,
        body: body,
        notificationDetails: _notificationDetails,
        payload: 'loan_payment_${loan.id}',
      );
    } catch (e) {
      debugPrint('Gagal menampilkan notifikasi cicilan pinjaman: $e');
    }
  }

  /// Menampilkan notifikasi instan saat pinjaman/piutang baru berhasil disimpan.
  Future<void> showLoanCreatedNotification(TransactionModel loan) async {
    if (kIsWeb || !LocalStorageService.instance.dailyReminderEnabled) return;
    if (!_initialized) {
      await init();
    }
    if (!_initialized) return;

    try {
      await requestPermissionIfNeeded();

      final due = loan.dueDate;
      final isDebt = loan.type == TransactionType.debt;
      final counterparty = LoanHelper.counterpartyName(loan);
      final formattedAmount = Formatters.rupiah(loan.remainingAmount);

      late final String title;
      late final String body;

      if (due == null) {
        title = isDebt
            ? '📌 Hutang Berhasil Dicatat'
            : '📌 Piutang Berhasil Dicatat';
        body = isDebt
            ? 'Hutang $formattedAmount kepada $counterparty telah berhasil dicatat.'
            : 'Piutang $formattedAmount dari $counterparty telah berhasil dicatat.';
      } else {
        final days = LoanHelper.daysUntilDue(due);
        final formattedDate = LoanHelper.formatDueDate(due);
        if (days < 0) {
          title = isDebt
              ? '⚠️ Hutang Melewati Batas Waktu!'
              : '⚠️ Piutang Melewati Batas Waktu!';
          body = isDebt
              ? 'Hutang $formattedAmount kepada $counterparty telah jatuh tempo pada $formattedDate.'
              : 'Piutang $formattedAmount dari $counterparty telah jatuh tempo pada $formattedDate.';
        } else if (days == 0) {
          title = isDebt
              ? '🔔 Hutang Jatuh Tempo Hari Ini!'
              : '🔔 Piutang Jatuh Tempo Hari Ini!';
          body = isDebt
              ? 'Jangan lupa melunasi hutang $formattedAmount kepada $counterparty hari ini ($formattedDate).'
              : 'Ingatkan $counterparty untuk piutang $formattedAmount yang jatuh tempo hari ini ($formattedDate).';
        } else if (days == 1) {
          title = isDebt
              ? '⏰ Pengingat Hutang Besok Jatuh Tempo'
              : '⏰ Pengingat Piutang Besok Jatuh Tempo';
          body = isDebt
              ? 'Pengingat aktif: siapkan $formattedAmount untuk $counterparty besok ($formattedDate).'
              : 'Pengingat aktif: piutang $formattedAmount dari $counterparty jatuh tempo besok ($formattedDate).';
        } else {
          title = isDebt
              ? '📌 Pengingat Hutang Diaktifkan'
              : '📌 Pengingat Piutang Diaktifkan';
          body = isDebt
              ? 'Kami akan mengingatkanmu sebelum batas waktu pelunasan $formattedAmount ke $counterparty ($formattedDate).'
              : 'Kami akan mengingatkanmu sebelum batas waktu penagihan $formattedAmount dari $counterparty ($formattedDate).';
        }
      }

      final idKey = loan.id.isNotEmpty
          ? loan.id
          : '${loan.title}_${DateTime.now().millisecondsSinceEpoch}';

      await _plugin.show(
        id: _instantId(idKey),
        title: title,
        body: body,
        notificationDetails: _notificationDetails,
        payload: loan.id,
      );
    } catch (e) {
      debugPrint('Gagal menampilkan notifikasi pinjaman baru: $e');
    }
  }

  /// Menampilkan notifikasi instan saat transaksi berulang berhasil dicatat otomatis
  /// (misalnya ketika aplikasi dibuka pada pukul 00:00 atau pagi hari) maupun ketika
  /// ada jadwal yang dilewati karena saldo dompet tidak mencukupi.
  Future<void> showRecurringCatchUpNotification(
    RecurringCatchUpResult result,
  ) async {
    if (kIsWeb ||
        !result.hasChanges ||
        !LocalStorageService.instance.dailyReminderEnabled) {
      return;
    }
    if (!_initialized) {
      await init();
    }
    if (!_initialized) return;

    try {
      await requestPermissionIfNeeded();

      if (result.generatedCount > 0) {
        final String title;
        final String body;
        if (result.generatedCount == 1 &&
            result.generatedTransactions.isNotEmpty) {
          final tx = result.generatedTransactions.first;
          title = '🔄 Transaksi Berulang Tercatat';
          body =
              '"${tx.title}" sebesar ${Formatters.rupiah(tx.amount)} telah dicatat otomatis.';
        } else {
          title = '🔄 ${result.generatedCount} Transaksi Berulang Tercatat';
          body =
              '${result.generatedCount} jadwal transaksi berulang yang jatuh tempo telah dicatat otomatis.';
        }

        await _plugin.show(
          id: _recurringInstantId('recorded_${DateTime.now().day}'),
          title: title,
          body: body,
          notificationDetails: _notificationDetails,
          payload: 'recurring_recorded',
        );
      }

      if (result.skippedCount > 0 && result.skippedReasons.isNotEmpty) {
        await _plugin.show(
          id: _recurringInstantId('skipped_${DateTime.now().day}'),
          title: '⚠️ Transaksi Berulang Dilewati',
          body: result.skippedReasons.first,
          notificationDetails: _notificationDetails,
          payload: 'recurring_skipped',
        );
      }
    } catch (e) {
      debugPrint('Gagal menampilkan notifikasi catch-up berulang: $e');
    }
  }

  Future<void> cancelLoanReminder(String loanId) async {
    if (!_initialized || kIsWeb || loanId.isEmpty) return;
    try {
      await _plugin.cancel(id: _dayBeforeId(loanId));
      await _plugin.cancel(id: _dueDayId(loanId));
      await _plugin.cancel(id: _instantId(loanId));
    } catch (e) {
      debugPrint('Gagal membatalkan pengingat pinjaman ($loanId): $e');
    }
  }

  Future<void> cancelRecurringReminder(String recurringId) async {
    if (!_initialized || kIsWeb || recurringId.isEmpty) return;
    try {
      await _plugin.cancel(id: _recurringScheduledId(recurringId));
    } catch (e) {
      debugPrint('Gagal membatalkan pengingat berulang ($recurringId): $e');
    }
  }

  String? _safelyReadString(String? Function() getter) {
    try {
      return getter();
    } catch (_) {
      return null;
    }
  }

  Future<void> _safelyRun(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }

  Future<void> _clearArmedDateSafely() async {
    _inMemoryArmedDate = null;
    await _safelyRun(
      () => LocalStorageService.instance.setDailyMissionArmedDate(null),
    );
  }

  Future<void> cancelAll() async {
    _cachedTransactions = const [];
    _cachedRecurring = const [];
    _hasCompletedDailyMissionToday = false;
    await _clearArmedDateSafely();
    if (!_initialized || kIsWeb) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Gagal membatalkan seluruh notifikasi: $e');
    }
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    await LocalStorageService.instance.setDailyReminderEnabled(enabled);
    if (!enabled) {
      await _clearArmedDateSafely();
      if (_initialized && !kIsWeb) {
        try {
          await _plugin.cancelAll();
        } catch (e) {
          debugPrint(
            'Gagal membatalkan notifikasi saat pengingat dimatikan: $e',
          );
        }
      }
      return;
    }
    await _rescheduleAllPending();
  }

  Future<void> syncDailyMissionReminder({
    required bool hasCompletedAnyDailyToday,
  }) async {
    _hasCompletedDailyMissionToday = hasCompletedAnyDailyToday;
    await _scheduleDailyMissionReminder();
  }

  Future<void> _scheduleDailyMissionReminder() {
    final next = _dailyReminderQueue.then(
      (_) => _runScheduleDailyMissionReminder(),
      onError: (_) => _runScheduleDailyMissionReminder(),
    );
    _dailyReminderQueue = next.catchError((_) {});
    return next;
  }

  Future<void> _runScheduleDailyMissionReminder() async {
    if (!_initialized || kIsWeb) return;
    try {
      final storage = LocalStorageService.instance;
      if (!storage.dailyReminderEnabled) {
        await _plugin.cancel(id: _dailyMissionReminderId);
        await _plugin.cancel(id: _dailyMissionInstantId);
        await _clearArmedDateSafely();
        return;
      }

      await requestPermissionIfNeeded();

      bool hasActiveDailyNotification = false;
      try {
        final active = await _plugin.getActiveNotifications();
        hasActiveDailyNotification = active.any(
          (n) =>
              n.id == _dailyMissionReminderId ||
              n.id == _dailyMissionInstantId,
        );
      } catch (_) {}

      final now = tz.TZDateTime.now(tz.local);
      final effectiveLastReminded =
          _inMemoryLastRemindedDate ??
          _safelyReadString(() => storage.dailyMissionLastRemindedDate);
      final effectiveArmedDate =
          _inMemoryArmedDate ??
          _safelyReadString(() => storage.dailyMissionArmedDate);

      final completedToday = _hasCompletedDailyMissionToday;
      final plan = buildDailyMissionReminderPlan(
        now: now,
        hasCompletedAnyDailyToday: completedToday,
        lastRemindedDate: effectiveLastReminded,
        armedDate: effectiveArmedDate,
        hasActiveDailyMissionNotification: hasActiveDailyNotification,
      );

      await _plugin.cancel(id: _dailyMissionReminderId);
      if (completedToday) {
        await _plugin.cancel(id: _dailyMissionInstantId);
      }

      if (plan.lastRemindedDateToRecord != null &&
          plan.lastRemindedDateToRecord != effectiveLastReminded) {
        _inMemoryLastRemindedDate = plan.lastRemindedDateToRecord;
        await _safelyRun(
          () => storage.setDailyMissionLastRemindedDate(
            plan.lastRemindedDateToRecord,
          ),
        );
      }

      if (plan.shouldClearArmedDate) {
        await _clearArmedDateSafely();
      } else if (plan.armedDateToRecord != null) {
        _inMemoryArmedDate = plan.armedDateToRecord;
        await _safelyRun(
          () => storage.setDailyMissionArmedDate(plan.armedDateToRecord),
        );
      }

      if (plan.shouldShowInstantNow) {
        await _plugin.show(
          id: _dailyMissionInstantId,
          title: '🔥 Jangan Lewatkan Misi Harianmu!',
          body:
              'Hari tinggal beberapa jam lagi! Yuk selesaikan misi harianmu bersama Feen dan klaim hadiah XP hari ini.',
          notificationDetails: _notificationDetails,
          payload: 'daily_mission_reminder',
        );
      }

      final scheduledEightPm = tz.TZDateTime(
        tz.local,
        plan.scheduledDate.year,
        plan.scheduledDate.month,
        plan.scheduledDate.day,
        plan.scheduledDate.hour,
        plan.scheduledDate.minute,
      );

      await _plugin.zonedSchedule(
        id: _dailyMissionReminderId,
        title: '🔥 Jangan Lewatkan Misi Harianmu!',
        body:
            'Hari tinggal 4 jam lagi! Yuk selesaikan misi harianmu bersama Feen dan klaim hadiah XP hari ini.',
        scheduledDate: scheduledEightPm,
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_mission_reminder',
      );
    } catch (e) {
      debugPrint('Gagal menjadwalkan pengingat misi harian: $e');
    }
  }

  Future<void> syncLoanReminders(List<TransactionModel> transactions) async {
    _cachedTransactions = List<TransactionModel>.unmodifiable(transactions);
    await _rescheduleAllPending();
  }

  Future<void> syncRecurringReminders(List<RecurringModel> recurringList) async {
    _cachedRecurring = List<RecurringModel>.unmodifiable(recurringList);
    await _rescheduleAllPending();
  }

  Future<void> _rescheduleAllPending() async {
    if (!_initialized || kIsWeb) return;

    try {
      await _plugin.cancelAllPendingNotifications();
      if (!LocalStorageService.instance.dailyReminderEnabled) return;

      await _scheduleDailyMissionReminder();

      final unpaidLoans = _cachedTransactions
          .where(
            (t) =>
                LoanHelper.isLoan(t) &&
                !t.isPaid &&
                t.remainingAmount > 0 &&
                t.dueDate != null &&
                t.id.isNotEmpty,
          )
          .toList();

      final activeRecurring = _cachedRecurring
          .where((r) => r.isActive && !r.isCompleted && r.id.isNotEmpty)
          .toList();

      if (unpaidLoans.isEmpty && activeRecurring.isEmpty) return;

      await requestPermissionIfNeeded();

      final now = tz.TZDateTime.now(tz.local);

      for (final loan in unpaidLoans) {
        final due = loan.dueDate!;
        final isDebt = loan.type == TransactionType.debt;
        final counterparty = LoanHelper.counterpartyName(loan);
        final formattedAmount = Formatters.rupiah(loan.remainingAmount);
        final formattedDate = LoanHelper.formatDueDate(due);

        // Pengingat H-1 pukul 09:00 waktu lokal
        final dueDayNineAm = tz.TZDateTime(
          tz.local,
          due.year,
          due.month,
          due.day,
          9,
        );
        final dayBeforeNineAm =
            dueDayNineAm.subtract(const Duration(days: 1));

        if (dayBeforeNineAm.isAfter(now)) {
          await _plugin.zonedSchedule(
            id: _dayBeforeId(loan.id),
            title: isDebt
                ? '⏰ Pengingat Hutang Besok Jatuh Tempo'
                : '⏰ Pengingat Piutang Besok Jatuh Tempo',
            body: isDebt
                ? 'Jangan lupa siapkan $formattedAmount untuk $counterparty besok ($formattedDate).'
                : 'Ingatkan $counterparty mengenai piutang $formattedAmount yang jatuh tempo besok ($formattedDate).',
            scheduledDate: dayBeforeNineAm,
            notificationDetails: _notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: loan.id,
          );
        }

        // Pengingat Hari-H pukul 09:00 waktu lokal
        if (dueDayNineAm.isAfter(now)) {
          await _plugin.zonedSchedule(
            id: _dueDayId(loan.id),
            title: isDebt
                ? '🔔 Hutang Jatuh Tempo Hari Ini!'
                : '🔔 Piutang Jatuh Tempo Hari Ini!',
            body: isDebt
                ? 'Waktunya melunasi hutang $formattedAmount kepada $counterparty hari ini.'
                : 'Piutang $formattedAmount dari $counterparty jatuh tempo hari ini.',
            scheduledDate: dueDayNineAm,
            notificationDetails: _notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: loan.id,
          );
        }
      }

      for (final rec in activeRecurring) {
        final next = rec.nextRunDate;
        final scheduledNineAm = tz.TZDateTime(
          tz.local,
          next.year,
          next.month,
          next.day,
          9,
        );

        if (scheduledNineAm.isAfter(now)) {
          final formattedAmount = Formatters.rupiah(rec.amount);
          final formattedDate = DateHelper.formatShort(next);
          await _plugin.zonedSchedule(
            id: _recurringScheduledId(rec.id),
            title: '🔄 Jadwal Transaksi Berulang Hari Ini',
            body:
                '"${rec.title}" ($formattedAmount) dijadwalkan pada $formattedDate. Buka Teenancial untuk mencatat otomatis.',
            scheduledDate: scheduledNineAm,
            notificationDetails: _notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: 'recurring_${rec.id}',
          );
        }
      }
    } catch (e) {
      debugPrint('Gagal menyinkronkan pengingat notifikasi: $e');
    }
  }
}

/// Hasil perhitungan rencana penjadwalan alarm harian 20:00 dan pengingat
/// instan pada jendela 20:00–23:59 untuk misi harian.
class DailyMissionReminderPlan {
  final DateTime scheduledDate;
  final bool shouldShowInstantNow;
  final String? lastRemindedDateToRecord;
  final String? armedDateToRecord;
  final bool shouldClearArmedDate;

  const DailyMissionReminderPlan({
    required this.scheduledDate,
    required this.shouldShowInstantNow,
    this.lastRemindedDateToRecord,
    this.armedDateToRecord,
    this.shouldClearArmedDate = false,
  });
}
