import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/transaction_model.dart';
import '../utils/loan_helper.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionRequested = false;

  static const String _channelId = 'teenancial_loan_reminders';
  static const String _channelName = 'Pengingat Pinjaman & Piutang';
  static const String _channelDescription =
      'Notifikasi pengingat batas waktu pembayaran hutang dan penagihan piutang.';

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

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

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
      final formattedAmount = _formatCurrency(loan.amount);
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

  Future<void> cancelAll() async {
    if (!_initialized || kIsWeb) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Gagal membatalkan seluruh notifikasi: $e');
    }
  }

  Future<void> syncLoanReminders(List<TransactionModel> transactions) async {
    if (!_initialized || kIsWeb) return;

    try {
      await _plugin.cancelAllPendingNotifications();

      final unpaidLoans = transactions.where(
        (t) =>
            LoanHelper.isLoan(t) &&
            !t.isPaid &&
            t.dueDate != null &&
            t.id.isNotEmpty,
      );

      if (unpaidLoans.isEmpty) return;

      await requestPermissionIfNeeded();

      final now = tz.TZDateTime.now(tz.local);

      for (final loan in unpaidLoans) {
        final due = loan.dueDate!;
        final isDebt = loan.type == TransactionType.debt;
        final counterparty = LoanHelper.counterpartyName(loan);
        final formattedAmount = _formatCurrency(loan.amount);
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
    } catch (e) {
      debugPrint('Gagal menyinkronkan pengingat pinjaman: $e');
    }
  }
}
