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

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionRequested = false;

  List<TransactionModel> _cachedTransactions = const [];
  List<RecurringModel> _cachedRecurring = const [];

  static const String _channelId = 'teenancial_loan_reminders';
  static const String _channelName = 'Pengingat Pinjaman & Transaksi Berulang';
  static const String _channelDescription =
      'Notifikasi pengingat batas waktu pinjaman/piutang dan jadwal transaksi berulang.';

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
  int _recurringScheduledId(String recurringId) =>
      _hashId('rec_sched_$recurringId');
  int _recurringInstantId(String key) => _hashId('rec_instant_$key');

  /// Menampilkan notifikasi instan saat pinjaman/piutang baru berhasil disimpan.
  Future<void> showLoanCreatedNotification(TransactionModel loan) async {
    if (kIsWeb) return;
    if (!_initialized) {
      await init();
    }
    if (!_initialized || loan.dueDate == null) return;

    try {
      await requestPermissionIfNeeded();

      final due = loan.dueDate!;
      final days = LoanHelper.daysUntilDue(due);
      final isDebt = loan.type == TransactionType.debt;
      final counterparty = LoanHelper.counterpartyName(loan);
      final formattedAmount = Formatters.rupiah(loan.remainingAmount);
      final formattedDate = LoanHelper.formatDueDate(due);

      late final String title;
      late final String body;

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

      final idKey = loan.id.isNotEmpty
          ? loan.id
          : '${loan.title}_${due.millisecondsSinceEpoch}';

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
    if (kIsWeb || !result.hasChanges) return;
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

  Future<void> cancelAll() async {
    _cachedTransactions = const [];
    _cachedRecurring = const [];
    if (!_initialized || kIsWeb) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Gagal membatalkan seluruh notifikasi: $e');
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
