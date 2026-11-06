import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../widgets/transaction/transaction_form_screen.dart';

class PengeluaranScreen extends StatelessWidget {
  final TransactionModel? transactionToEdit;

  const PengeluaranScreen({super.key, this.transactionToEdit});

  @override
  Widget build(BuildContext context) {
    return TransactionFormScreen(
      type: TransactionType.expense,
      transactionToEdit: transactionToEdit,
    );
  }
}
