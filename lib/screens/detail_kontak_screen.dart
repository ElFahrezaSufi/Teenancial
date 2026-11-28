import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../models/contact_model.dart';
import '../models/transaction_model.dart';
import '../providers/contact_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_colors.dart';
import '../utils/contact_analytics.dart';
import '../utils/currency_formatter.dart';
import '../utils/loan_helper.dart';
import '../utils/transaction_actions.dart';
import '../widgets/common/async_state_view.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/common/custom_filter_chip.dart';
import '../widgets/transaction/transaction_group.dart';
import 'kontak_screen.dart';
import 'riwayat_screen.dart';

class DetailKontakScreen extends StatefulWidget {
  final String contactId;
  final ContactModel? initialContact;

  const DetailKontakScreen({
    super.key,
    required this.contactId,
    this.initialContact,
  });

  @override
  State<DetailKontakScreen> createState() => _DetailKontakScreenState();
}

class _DetailKontakScreenState extends State<DetailKontakScreen> {
  TransactionType? _selectedTypeFilter;

  Future<void> _handleRefresh() async {
    final contactProvider = context.read<ContactProvider>();
    final txProvider = context.read<TransactionProvider>();
    await Future.wait([
      contactProvider.loadContacts(silent: true),
      txProvider.loadTransactions(silent: true),
    ]);
  }

  Future<void> _handleEdit(ContactModel contact) async {
    final saved = await KontakScreen.showContactFormSheet(
      context,
      contactToEdit: contact,
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Kontak "${saved.name}" berhasil diperbarui.'),
            backgroundColor: primaryGreen,
          ),
        );
    }
  }

  Future<void> _handleDelete(
    ContactModel contact,
    int linkedTransactionCount,
  ) async {
    final deleted = await KontakScreen.confirmAndDeleteContact(
      context,
      contact: contact,
      linkedTransactionCount: linkedTransactionCount,
    );
    if (deleted && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactProvider = context.watch<ContactProvider>();
    final txProvider = context.watch<TransactionProvider>();

    final ContactModel? contact =
        contactProvider.getContactById(widget.contactId) ??
            widget.initialContact;

    if (contact == null) {
      return const Scaffold(
        backgroundColor: scaffoldBg,
        appBar: CustomAppBar(title: 'Detail Kontak'),
        body: EmptyStateView(
          icon: Icons.person_off_outlined,
          title: 'Kontak tidak ditemukan',
          subtitle: 'Kontak ini mungkin sudah dihapus dari daftar.',
        ),
      );
    }

    final allTransactions = txProvider.transactions;
    final summary = ContactAnalytics.summarize(contact, allTransactions);
    final filteredTransactions = ContactAnalytics.transactionsForContact(
      contact,
      allTransactions,
      typeFilter: _selectedTypeFilter,
    );
    final groups = RiwayatScreen.buildAllGroups(filteredTransactions);
    final avatarColor = KontakScreen.avatarColorFor(contact.name);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: CustomAppBar(
        title: 'Detail Kontak',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit Kontak',
              icon: const Icon(
                Icons.edit_outlined,
                color: primaryGreen,
                size: 21,
              ),
              onPressed: () => _handleEdit(contact),
            ),
            IconButton(
              tooltip: 'Hapus Kontak',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 21,
              ),
              onPressed: () => _handleDelete(contact, summary.transactionCount),
            ),
            const SizedBox(width: 4),
          ],
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
            child: RefreshIndicator(
              color: primaryGreen,
              backgroundColor: scaffoldBg,
              onRefresh: _handleRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Header Profil Kontak + Aksi Cepat
                    CustomCard(
                      backgroundColor: cardBg,
                      borderRadius: 20,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: avatarColor.withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: avatarColor.withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    contact.initials,
                                    style: TextStyle(
                                      color: avatarColor,
                                      fontFamily: 'Inter',
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contact.name,
                                      style: const TextStyle(
                                        color: primaryGreen,
                                        fontFamily: 'Inter',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (contact.note != null &&
                                        contact.note!.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        contact.note!,
                                        style: TextStyle(
                                          color: primaryGreen.withValues(
                                            alpha: 0.78,
                                          ),
                                          fontFamily: 'Inter',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ] else ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '${summary.transactionCount} transaksi tercatat',
                                        style: TextStyle(
                                          color: primaryGreen.withValues(
                                            alpha: 0.7,
                                          ),
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  key: const Key('contact_quick_transfer_btn'),
                                  onPressed: () => context.push(
                                    AppRoutes.transfer,
                                    extra: contact.name,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryGreen,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 11,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.swap_horiz_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Transfer',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  key: const Key('contact_quick_loan_btn'),
                                  onPressed: () => context.push(
                                    AppRoutes.pinjaman,
                                    extra: contact.name,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: primaryGreen,
                                    backgroundColor: inputBg,
                                    side: const BorderSide(
                                      color: primaryGreen,
                                      width: 1.5,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 11,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.handshake_outlined,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Catat Pinjaman',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Ringkasan Keuangan Bersama Kontak
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryMetricTile(
                            label: 'Total Transfer',
                            amount: summary.totalTransferOut,
                            valueColor: primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SummaryMetricTile(
                            label: 'Hutang Aktif',
                            amount: summary.activeDebtRemaining,
                            valueColor: summary.activeDebtRemaining > 0
                                ? LoanHelper.overdueColor
                                : primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SummaryMetricTile(
                            label: 'Piutang Aktif',
                            amount: summary.activeReceivableRemaining,
                            valueColor: summary.activeReceivableRemaining > 0
                                ? orangeText
                                : primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 3. Judul & Chip Filter Riwayat
                    const Text(
                      'Riwayat Bersama Kontak',
                      style: TextStyle(
                        color: primaryGreen,
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          CustomFilterChip(
                            label: 'Semua',
                            selected: _selectedTypeFilter == null,
                            onTap: () =>
                                setState(() => _selectedTypeFilter = null),
                          ),
                          const SizedBox(width: 8),
                          CustomFilterChip(
                            label: 'Transfer',
                            selected:
                                _selectedTypeFilter == TransactionType.transfer,
                            onTap: () => setState(
                              () =>
                                  _selectedTypeFilter = TransactionType.transfer,
                            ),
                          ),
                          const SizedBox(width: 8),
                          CustomFilterChip(
                            label: 'Hutang',
                            selected:
                                _selectedTypeFilter == TransactionType.debt,
                            onTap: () => setState(
                              () => _selectedTypeFilter = TransactionType.debt,
                            ),
                          ),
                          const SizedBox(width: 8),
                          CustomFilterChip(
                            label: 'Piutang',
                            selected: _selectedTypeFilter ==
                                TransactionType.receivable,
                            onTap: () => setState(
                              () => _selectedTypeFilter =
                                  TransactionType.receivable,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. Daftar Transaksi Terkait
                    if (groups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: EmptyStateView(
                          icon: Icons.receipt_long_outlined,
                          title: _selectedTypeFilter == null
                              ? 'Belum ada riwayat transaksi'
                              : 'Tidak ada transaksi untuk filter ini',
                          subtitle: _selectedTypeFilter == null
                              ? 'Catat transfer atau pinjaman dengan ${contact.name} menggunakan tombol di atas.'
                              : 'Coba pilih tab filter lain untuk melihat seluruh aktivitas bersama ${contact.name}.',
                        ),
                      )
                    else
                      ...groups.map(
                        (group) => TransactionGroupList(
                          group: group,
                          formatCurrency: Formatters.rupiah,
                          onEdit: (item) =>
                              TransactionActions.edit(context, item),
                          onDelete: (id) =>
                              TransactionActions.delete(context, id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetricTile extends StatelessWidget {
  final String label;
  final double amount;
  final Color valueColor;

  const _SummaryMetricTile({
    required this.label,
    required this.amount,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      backgroundColor: inputBg,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: primaryGreen.withValues(alpha: 0.72),
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.rupiah(amount),
              maxLines: 1,
              style: TextStyle(
                color: valueColor,
                fontFamily: 'Inter',
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
