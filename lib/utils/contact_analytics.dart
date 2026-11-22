import '../models/contact_model.dart';
import '../models/transaction_model.dart';

/// Ringkasan statistik keuangan dan riwayat transaksi bersama satu kontak.
class ContactSummary {
  final ContactModel contact;
  final List<TransactionModel> transactions;
  final double totalTransferOut;
  final double activeDebtRemaining;
  final double activeReceivableRemaining;
  final int activeDebtCount;
  final int activeReceivableCount;

  const ContactSummary({
    required this.contact,
    required this.transactions,
    required this.totalTransferOut,
    required this.activeDebtRemaining,
    required this.activeReceivableRemaining,
    required this.activeDebtCount,
    required this.activeReceivableCount,
  });

  int get transactionCount => transactions.length;
  bool get hasActiveLoans => activeDebtCount > 0 || activeReceivableCount > 0;
}

/// Utilitas murni untuk memetakan transaksi (transfer keluar, hutang, piutang)
/// ke kontak terkait dan menghitung ringkasan keuangan per kontak.
class ContactAnalytics {
  ContactAnalytics._();

  static bool _isExternalTransfer(TransactionModel tx) {
    return tx.type == TransactionType.transfer &&
        (tx.destinationDompetId == null ||
            tx.destinationDompetId!.trim().isEmpty);
  }

  static bool _isContactEligible(TransactionModel tx) {
    if (tx.isBalanceAdjustment) return false;
    return _isExternalTransfer(tx) ||
        tx.type == TransactionType.debt ||
        tx.type == TransactionType.receivable;
  }

  /// Mengekstrak nama pihak lawan transaksi dari `counterpartyName` atau pola
  /// judul baku ("Transfer ke X", "Hutang dari X", "Piutang ke X").
  static String? resolveCounterpartyName(TransactionModel tx) {
    if (!_isContactEligible(tx)) return null;

    final explicit = tx.counterpartyName?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    final title = tx.title.trim();
    const prefixes = [
      'Transfer ke ',
      'Hutang dari ',
      'Piutang ke ',
    ];
    for (final prefix in prefixes) {
      if (title.toLowerCase().startsWith(prefix.toLowerCase())) {
        final extracted = title.substring(prefix.length).trim();
        if (extracted.isNotEmpty) return extracted;
      }
    }
    return null;
  }

  /// Menentukan apakah suatu transaksi terkait dengan [contact].
  /// Memprioritaskan kecocokan `contactId`, lalu fallback ke nama lawan
  /// transaksi secara case-insensitive bila `contactId` belum tersimpan.
  static bool isTransactionForContact(
    TransactionModel tx,
    ContactModel contact,
  ) {
    if (!_isContactEligible(tx)) return false;

    final txContactId = tx.contactId?.trim();
    if (txContactId != null && txContactId.isNotEmpty) {
      return txContactId == contact.id;
    }

    final contactName = contact.name.trim().toLowerCase();
    if (contactName.isEmpty) return false;
    final resolved = resolveCounterpartyName(tx);
    return resolved != null && resolved.toLowerCase() == contactName;
  }

  static List<TransactionModel> transactionsForContact(
    ContactModel contact,
    Iterable<TransactionModel> allTransactions, {
    TransactionType? typeFilter,
  }) {
    final matched = allTransactions.where((tx) {
      if (!isTransactionForContact(tx, contact)) return false;
      if (typeFilter != null && tx.type != typeFilter) return false;
      return true;
    }).toList();
    matched.sort((a, b) => b.date.compareTo(a.date));
    return matched;
  }

  static ContactSummary summarize(
    ContactModel contact,
    Iterable<TransactionModel> allTransactions,
  ) {
    final matched = transactionsForContact(contact, allTransactions);
    double totalTransferOut = 0.0;
    double activeDebtRemaining = 0.0;
    double activeReceivableRemaining = 0.0;
    int activeDebtCount = 0;
    int activeReceivableCount = 0;

    for (final tx in matched) {
      if (_isExternalTransfer(tx)) {
        totalTransferOut += tx.amount;
      } else if (tx.type == TransactionType.debt && !tx.isPaid) {
        activeDebtCount++;
        activeDebtRemaining += tx.remainingAmount;
      } else if (tx.type == TransactionType.receivable && !tx.isPaid) {
        activeReceivableCount++;
        activeReceivableRemaining += tx.remainingAmount;
      }
    }

    return ContactSummary(
      contact: contact,
      transactions: matched,
      totalTransferOut: totalTransferOut,
      activeDebtRemaining: activeDebtRemaining,
      activeReceivableRemaining: activeReceivableRemaining,
      activeDebtCount: activeDebtCount,
      activeReceivableCount: activeReceivableCount,
    );
  }

  static Map<String, ContactSummary> summarizeAll(
    Iterable<ContactModel> contacts,
    Iterable<TransactionModel> allTransactions,
  ) {
    return {
      for (final c in contacts) c.id: summarize(c, allTransactions),
    };
  }
}
