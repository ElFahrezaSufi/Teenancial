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
  });
}
