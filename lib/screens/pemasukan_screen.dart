import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../widgets/transaction/transaction_form_screen.dart';

class PemasukanScreen extends StatelessWidget {
  final TransactionModel? transactionToEdit;

  const PemasukanScreen({super.key, this.transactionToEdit});

  @override
  Widget build(BuildContext context) {
    return TransactionFormScreen(
      type: TransactionType.income,
      transactionToEdit: transactionToEdit,
    );
  }
}
