import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/category_catalog.dart';
import '../utils/recurrence_rule.dart';
import 'transaction_model.dart';

export '../utils/recurrence_rule.dart';

class RecurringModel {
  final String id;
  final String title;
  final double amount;
  final String notes;
  final String categoryId;
  final TransactionType type; // income, expense, transfer
  final String dompetId;
  final String? destinationDompetId;
  final String? contactId;
  final String? counterpartyName;
  final RecurrenceFrequency frequency;
  final int intervalCount;
  final DateTime startDate;
  final DateTime nextRunDate;
  final DateTime? endDate;
  final DateTime? lastRunDate;
  final bool isActive;
  final int generatedCount;
  final int skippedCount;
  final String? lastSkipReason;
  final DateTime? createdAt;

  const RecurringModel({
    required this.id,
    required this.title,
    required this.amount,
    this.notes = '',
    required this.categoryId,
    required this.type,
    required this.dompetId,
    this.destinationDompetId,
    this.contactId,
    this.counterpartyName,
    required this.frequency,
    this.intervalCount = 1,
    required this.startDate,
    required this.nextRunDate,
    this.endDate,
    this.lastRunDate,
    this.isActive = true,
    this.generatedCount = 0,
    this.skippedCount = 0,
    this.lastSkipReason,
    this.createdAt,
  });

  bool get isInternalTransfer =>
      type == TransactionType.transfer &&
      destinationDompetId != null &&
      destinationDompetId!.trim().isNotEmpty;

  bool get isCompleted =>
      endDate != null &&
      RecurrenceRule.dateOnly(nextRunDate)
          .isAfter(RecurrenceRule.dateOnly(endDate!));

  String get scheduleLabel => RecurrenceRule.describe(frequency, intervalCount);

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'notes': notes,
      'categoryId': categoryId,
      'type': type.name,
      'dompetId': dompetId,
      'destinationDompetId': destinationDompetId,
      'contactId': contactId,
      'counterpartyName': counterpartyName,
      'frequency': frequency.name,
      'intervalCount': intervalCount < 1 ? 1 : intervalCount,
      'startDate': Timestamp.fromDate(RecurrenceRule.dateOnly(startDate)),
      'nextRunDate': Timestamp.fromDate(RecurrenceRule.dateOnly(nextRunDate)),
      'endDate': endDate != null
          ? Timestamp.fromDate(RecurrenceRule.dateOnly(endDate!))
          : null,
      'lastRunDate':
          lastRunDate != null ? Timestamp.fromDate(lastRunDate!) : null,
      'isActive': isActive,
      'generatedCount': generatedCount,
      'skippedCount': skippedCount,
      'lastSkipReason': lastSkipReason,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }

  factory RecurringModel.fromMap(
    Map<String, dynamic> map, {
    String? docId,
  }) {
    final typeStr = (map['type'] as String?) ?? TransactionType.expense.name;
    final parsedType = TransactionType.values.firstWhere(
      (e) =>
          e.name == typeStr &&
          (e == TransactionType.income ||
              e == TransactionType.expense ||
              e == TransactionType.transfer),
      orElse: () => TransactionType.expense,
    );

    final freqStr =
        (map['frequency'] as String?) ?? RecurrenceFrequency.monthly.name;
    final parsedFreq = RecurrenceFrequency.values.firstWhere(
      (e) => e.name == freqStr,
      orElse: () => RecurrenceFrequency.monthly,
    );

    final rawCategoryId = (map['categoryId'] as String?)?.trim() ?? '';
    final now = DateTime.now();
    final parsedStart =
        _parseDateTime(map['startDate']) ?? RecurrenceRule.dateOnly(now);
    final parsedNext = _parseDateTime(map['nextRunDate']) ?? parsedStart;
    final rawInterval = (map['intervalCount'] as num?)?.toInt() ?? 1;

    return RecurringModel(
      id: docId ?? (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      notes: (map['notes'] as String?) ?? '',
      categoryId: rawCategoryId.isNotEmpty
          ? rawCategoryId
          : CategoryCatalog.defaultCategoryIdForType(parsedType),
      type: parsedType,
      dompetId: (map['dompetId'] as String?) ?? '',
      destinationDompetId: map['destinationDompetId'] as String?,
      contactId: map['contactId'] as String?,
      counterpartyName: map['counterpartyName'] as String?,
      frequency: parsedFreq,
      intervalCount: rawInterval < 1 ? 1 : rawInterval,
      startDate: RecurrenceRule.dateOnly(parsedStart),
      nextRunDate: RecurrenceRule.dateOnly(parsedNext),
      endDate: _parseDateTime(map['endDate']),
      lastRunDate: _parseDateTime(map['lastRunDate']),
      isActive: map['isActive'] != false,
      generatedCount: (map['generatedCount'] as num?)?.toInt() ?? 0,
      skippedCount: (map['skippedCount'] as num?)?.toInt() ?? 0,
      lastSkipReason: map['lastSkipReason'] as String?,
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  RecurringModel copyWith({
    String? id,
    String? title,
    double? amount,
    String? notes,
    String? categoryId,
    TransactionType? type,
    String? dompetId,
    String? destinationDompetId,
    bool clearDestinationDompetId = false,
    String? contactId,
    bool clearContactId = false,
    String? counterpartyName,
    bool clearCounterpartyName = false,
    RecurrenceFrequency? frequency,
    int? intervalCount,
    DateTime? startDate,
    DateTime? nextRunDate,
    DateTime? endDate,
    bool clearEndDate = false,
    DateTime? lastRunDate,
    bool clearLastRunDate = false,
    bool? isActive,
    int? generatedCount,
    int? skippedCount,
    String? lastSkipReason,
    bool clearLastSkipReason = false,
    DateTime? createdAt,
  }) {
    return RecurringModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      dompetId: dompetId ?? this.dompetId,
      destinationDompetId: clearDestinationDompetId
          ? null
          : (destinationDompetId ?? this.destinationDompetId),
      contactId: clearContactId ? null : (contactId ?? this.contactId),
      counterpartyName: clearCounterpartyName
          ? null
          : (counterpartyName ?? this.counterpartyName),
      frequency: frequency ?? this.frequency,
      intervalCount: intervalCount ?? this.intervalCount,
      startDate: startDate ?? this.startDate,
      nextRunDate: nextRunDate ?? this.nextRunDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      lastRunDate: clearLastRunDate ? null : (lastRunDate ?? this.lastRunDate),
      isActive: isActive ?? this.isActive,
      generatedCount: generatedCount ?? this.generatedCount,
      skippedCount: skippedCount ?? this.skippedCount,
      lastSkipReason: clearLastSkipReason
          ? null
          : (lastSkipReason ?? this.lastSkipReason),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
