import 'package:flutter_test/flutter_test.dart';
import 'package:teenancial/models/transaction_model.dart';
import 'package:teenancial/utils/loan_helper.dart';

void main() {
  group('LoanHelper', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    TransactionModel buildLoan({
      TransactionType type = TransactionType.debt,
      String title = 'Hutang dari Budi',
      String? counterpartyName,
      DateTime? dueDate,
      bool isPaid = false,
    }) {
      return TransactionModel(
        id: 'loan_1',
        title: title,
        amount: 50000,
        date: today,
        categoryId: 'c10',
        type: type,
        dompetId: 'd1',
        counterpartyName: counterpartyName,
        dueDate: dueDate,
        isPaid: isPaid,
      );
    }

    test('isLoan hanya bernilai true untuk debt dan receivable', () {
      expect(LoanHelper.isLoan(buildLoan(type: TransactionType.debt)), isTrue);
      expect(
        LoanHelper.isLoan(buildLoan(type: TransactionType.receivable)),
        isTrue,
      );
      expect(
        LoanHelper.isLoan(buildLoan(type: TransactionType.expense)),
        isFalse,
      );
    });

    test('counterpartyName memprioritaskan contactName -> counterpartyName -> parsing title', () {
      final txWithField = buildLoan(
        title: 'Pinjam Uang Buku',
        counterpartyName: 'Siti',
      );
      expect(
        LoanHelper.counterpartyName(txWithField, contactName: 'Siti Kontak'),
        'Siti Kontak',
      );
      expect(LoanHelper.counterpartyName(txWithField), 'Siti');

      final legacyDebt = buildLoan(
        title: 'Hutang dari Andi Wijaya',
        counterpartyName: null,
      );
      expect(LoanHelper.counterpartyName(legacyDebt), 'Andi Wijaya');

      final legacyReceivable = buildLoan(
        type: TransactionType.receivable,
        title: 'Piutang ke Rina',
        counterpartyName: null,
      );
      expect(LoanHelper.counterpartyName(legacyReceivable), 'Rina');
    });

    test('daysUntilDue dan describe menghitung status jatuh tempo dengan benar', () {
      final overdueLoan = buildLoan(
        dueDate: today.subtract(const Duration(days: 2)),
      );
      expect(LoanHelper.daysUntilDue(overdueLoan.dueDate!), -2);
      final overdueInfo = LoanHelper.describe(overdueLoan);
      expect(overdueInfo, isNotNull);
      expect(overdueInfo!.isOverdue, isTrue);
      expect(overdueInfo.label, 'Terlambat 2 hari');

      final dueTodayLoan = buildLoan(dueDate: today);
      expect(LoanHelper.describe(dueTodayLoan)?.label, 'Jatuh tempo hari ini');

      final paidLoan = buildLoan(
        dueDate: today.subtract(const Duration(days: 5)),
        isPaid: true,
      );
      expect(LoanHelper.describe(paidLoan)?.label, 'Lunas');
      expect(LoanHelper.describe(paidLoan)?.isOverdue, isFalse);
    });

    test(
      'paymentBadgeLabel dan paymentHistoryLabel membedakan Bayar Penuh (1x lunas) vs cicilan bertahap',
      () {
        final unpaid = buildLoan(isPaid: false);
        expect(LoanHelper.isDirectFullSettlement(unpaid), isFalse);
        expect(LoanHelper.paymentBadgeLabel(unpaid), isNull);

        final partial = unpaid.withPayment(
          LoanPayment(id: 'p1', amount: 20000, date: today, dompetId: 'd1'),
        );
        expect(LoanHelper.isDirectFullSettlement(partial), isFalse);
        expect(LoanHelper.paymentBadgeLabel(partial), '1x cicilan');
        expect(LoanHelper.paymentHistoryLabel(partial), 'Riwayat Cicilan (1)');

        final paidInTwo = partial.withPayment(
          LoanPayment(id: 'p2', amount: 30000, date: today, dompetId: 'd1'),
        );
        expect(paidInTwo.isPaid, isTrue);
        expect(LoanHelper.isDirectFullSettlement(paidInTwo), isFalse);
        expect(LoanHelper.paymentBadgeLabel(paidInTwo), '2x cicilan');
        expect(
          LoanHelper.paymentHistoryLabel(paidInTwo),
          'Riwayat Cicilan (2)',
        );

        final directFull = unpaid.withPayment(
          LoanPayment(id: 'p_full', amount: 50000, date: today, dompetId: 'd1'),
        );
        expect(directFull.isPaid, isTrue);
        expect(LoanHelper.isDirectFullSettlement(directFull), isTrue);
        expect(LoanHelper.paymentBadgeLabel(directFull), 'Bayar Penuh');
        expect(LoanHelper.paymentHistoryLabel(directFull), 'Detail Pelunasan');

        final legacyPaid = buildLoan(isPaid: true);
        expect(LoanHelper.isDirectFullSettlement(legacyPaid), isTrue);
        expect(LoanHelper.paymentBadgeLabel(legacyPaid), 'Bayar Penuh');
        expect(LoanHelper.paymentHistoryLabel(legacyPaid), 'Detail Pelunasan');
      },
    );
  });
}
