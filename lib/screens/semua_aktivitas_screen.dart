import 'package:flutter/material.dart';
import '../data/transaction_model.dart';
import '../theme/app_colors.dart';
import '../widgets/transaction/transaction_group.dart';

class SemuaAktivitasScreen extends StatelessWidget {
  final List<TransactionGroupData> groups;
  final String Function(double) formatCurrency;
  final Function(TransactionModel) onEdit;
  final Function(String) onDelete;

  const SemuaAktivitasScreen({
    super.key,
    required this.groups,
    required this.formatCurrency,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            color: appBarBg,
            border: Border(
              bottom: BorderSide(color: primaryGreen, width: 1.5),
            ),
          ),
          child: SafeArea(
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Center(
                  child: Text(
                    'Semua Aktivitas',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 25,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: primaryGreen, size: 20),
                    onPressed: () => Navigator.pop(context, true), // signal refresh
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.4,
            child: Image.asset(
              'assets/images/bg_curve.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...groups.map(
                    (group) => TransactionGroupList(
                      group: group,
                      formatCurrency: formatCurrency,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
