import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../models/contact_model.dart';
import '../providers/contact_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_colors.dart';
import '../utils/confirm_dialog.dart';
import '../utils/contact_analytics.dart';
import '../utils/currency_formatter.dart';
import '../utils/error_mapper.dart';
import '../utils/loan_helper.dart';
import '../widgets/common/async_state_view.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/common/primary_button.dart';
import '../widgets/common/skeleton.dart';

class KontakScreen extends StatefulWidget {
  const KontakScreen({super.key});

  /// Palet warna pastel harmonis untuk avatar inisial kontak.
  static const List<Color> avatarPalette = [
    Color(0xFF5D7628),
    Color(0xFF3E7C67),
    Color(0xFFD67E47),
    Color(0xFF5C7FA8),
    Color(0xFF8B6A9C),
    Color(0xFFB3862D),
  ];

  static Color avatarColorFor(String name) {
    final trimmed = name.trim().toLowerCase();
    if (trimmed.isEmpty) return avatarPalette.first;
    int hash = 0;
    for (int i = 0; i < trimmed.length; i++) {
      hash = (hash * 31 + trimmed.codeUnitAt(i)) & 0x7fffffff;
    }
    return avatarPalette[hash % avatarPalette.length];
  }

  /// Menampilkan bottom sheet untuk menambah atau mengubah kontak.
  /// Mengembalikan [ContactModel] hasil simpan, atau `null` jika dibatalkan.
  static Future<ContactModel?> showContactFormSheet(
    BuildContext context, {
    ContactModel? contactToEdit,
  }) {
    return showModalBottomSheet<ContactModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ContactFormSheet(contactToEdit: contactToEdit),
    );
  }

  /// Menampilkan konfirmasi lalu menghapus kontak secara aman (riwayat
  /// transaksi dan saldo dompet tetap dipertahankan utuh).
  static Future<bool> confirmAndDeleteContact(
    BuildContext context, {
    required ContactModel contact,
    required int linkedTransactionCount,
  }) async {
    final message = linkedTransactionCount > 0
        ? 'Kontak "${contact.name}" memiliki $linkedTransactionCount riwayat transaksi terkait. Menghapus kontak hanya menghapus dari daftar kontak. Seluruh riwayat transaksi dan saldo dompet tetap aman tersimpan.'
        : 'Yakin ingin menghapus "${contact.name}" dari daftar kontak?';

    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus Kontak',
      message: message,
      confirmColor: Colors.redAccent,
    );
    if (!confirmed || !context.mounted) return false;

    final contactProvider = context.read<ContactProvider>();
    final txProvider = Provider.of<TransactionProvider?>(
      context,
      listen: false,
    );
    final recProvider = Provider.of<RecurringProvider?>(
      context,
      listen: false,
    );

    try {
      await contactProvider.deleteContact(contact.id);
      if (txProvider != null) {
        await txProvider.loadTransactions(silent: true);
      }
      if (recProvider != null) {
        await recProvider.loadRecurring(silent: true);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Kontak "${contact.name}" berhasil dihapus.'),
              backgroundColor: primaryGreen,
            ),
          );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(ErrorMapper.message(e)),
              backgroundColor: Colors.red,
            ),
          );
      }
      return false;
    }
  }

  @override
  State<KontakScreen> createState() => _KontakScreenState();
}

class _KontakScreenState extends State<KontakScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final contactProvider = context.read<ContactProvider>();
      if (contactProvider.contacts.isEmpty && !contactProvider.isLoading) {
        contactProvider.loadContacts();
      }
      final txProvider = Provider.of<TransactionProvider?>(
        context,
        listen: false,
      );
      if (txProvider != null &&
          txProvider.transactions.isEmpty &&
          !txProvider.isLoading) {
        txProvider.loadTransactions(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    final contactProvider = context.read<ContactProvider>();
    final txProvider = Provider.of<TransactionProvider?>(
      context,
      listen: false,
    );
    await Future.wait([
      contactProvider.loadContacts(silent: true),
      if (txProvider != null) txProvider.loadTransactions(silent: true),
    ]);
  }

  Future<void> _handleAddOrEdit({ContactModel? contactToEdit}) async {
    final saved = await KontakScreen.showContactFormSheet(
      context,
      contactToEdit: contactToEdit,
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              contactToEdit != null
                  ? 'Kontak "${saved.name}" berhasil diperbarui.'
                  : 'Kontak "${saved.name}" berhasil ditambahkan.',
            ),
            backgroundColor: primaryGreen,
          ),
        );
    }
  }

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Skeleton(width: double.infinity, height: 48),
          SizedBox(height: 16),
          Skeleton(width: double.infinity, height: 82),
          SizedBox(height: 12),
          Skeleton(width: double.infinity, height: 82),
          SizedBox(height: 12),
          Skeleton(width: double.infinity, height: 82),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactProvider = context.watch<ContactProvider>();
    final txProvider = Provider.of<TransactionProvider?>(context);
    final allContacts = contactProvider.contacts;
    final allTransactions = txProvider?.transactions ?? const [];
    final summaries = ContactAnalytics.summarizeAll(
      allContacts,
      allTransactions,
    );

    final query = _searchQuery.trim().toLowerCase();
    final filteredContacts = query.isEmpty
        ? allContacts
        : allContacts.where((c) {
            final matchName = c.name.toLowerCase().contains(query);
            final matchNote =
                (c.note ?? '').toLowerCase().contains(query);
            return matchName || matchNote;
          }).toList();

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: CustomAppBar(
        title: 'Daftar Kontak',
        trailing: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            tooltip: 'Tambah Kontak',
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              color: primaryGreen,
              size: 22,
            ),
            onPressed: () => _handleAddOrEdit(),
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
            child: contactProvider.isLoading && allContacts.isEmpty
                ? _buildLoading()
                : contactProvider.errorMessage != null && allContacts.isEmpty
                    ? ErrorStateView(
                        errorMessage: contactProvider.errorMessage!,
                        onRetry: () => contactProvider.loadContacts(),
                      )
                    : allContacts.isEmpty
                        ? EmptyStateView(
                            icon: Icons.contacts_outlined,
                            title: 'Belum ada kontak tersimpan',
                            subtitle:
                                'Simpan nama teman saat mencatat transfer atau pinjaman, atau tambahkan kontak pertamamu di sini.',
                            actionLabel: 'Tambah Kontak',
                            onAction: () => _handleAddOrEdit(),
                          )
                        : Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 14, 20, 8),
                                child: TextField(
                                  key: const Key('kontak_search_field'),
                                  controller: _searchController,
                                  onChanged: (val) =>
                                      setState(() => _searchQuery = val),
                                  style: const TextStyle(
                                    color: primaryGreen,
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Cari nama atau catatan kontak...',
                                    hintStyle: TextStyle(
                                      color: primaryGreen.withValues(alpha: 0.5),
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: primaryGreen,
                                      size: 20,
                                    ),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              color: primaryGreen,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() => _searchQuery = '');
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: inputBg,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: primaryGreen,
                                        width: 1.5,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color:
                                            primaryGreen.withValues(alpha: 0.45),
                                        width: 1.5,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: primaryGreen,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 2, 24, 8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    query.isEmpty
                                        ? '${allContacts.length} kontak tersimpan'
                                        : 'Menampilkan ${filteredContacts.length} dari ${allContacts.length} kontak',
                                    style: TextStyle(
                                      color:
                                          primaryGreen.withValues(alpha: 0.72),
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: filteredContacts.isEmpty
                                    ? EmptyStateView(
                                        icon: Icons.search_off_rounded,
                                        title: 'Kontak tidak ditemukan',
                                        subtitle:
                                            'Tidak ada kontak yang cocok dengan kata kunci "$_searchQuery".',
                                        actionLabel: 'Reset Pencarian',
                                        onAction: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : RefreshIndicator(
                                        color: primaryGreen,
                                        backgroundColor: scaffoldBg,
                                        onRefresh: _handleRefresh,
                                        child: ListView.separated(
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          padding: const EdgeInsets.fromLTRB(
                                            20,
                                            4,
                                            20,
                                            24,
                                          ),
                                          itemCount: filteredContacts.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 10),
                                          itemBuilder: (context, index) {
                                            final contact =
                                                filteredContacts[index];
                                            final summary = summaries[
                                                    contact.id] ??
                                                ContactAnalytics.summarize(
                                                  contact,
                                                  allTransactions,
                                                );
                                            return _ContactListCard(
                                              contact: contact,
                                              summary: summary,
                                              onTap: () => context.push(
                                                AppRoutes.detailKontak,
                                                extra: contact.id,
                                              ),
                                              onEdit: () => _handleAddOrEdit(
                                                contactToEdit: contact,
                                              ),
                                              onDelete: () => KontakScreen
                                                  .confirmAndDeleteContact(
                                                context,
                                                contact: contact,
                                                linkedTransactionCount:
                                                    summary.transactionCount,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

class _ContactListCard extends StatelessWidget {
  final ContactModel contact;
  final ContactSummary summary;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactListCard({
    required this.contact,
    required this.summary,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final avatarColor = KontakScreen.avatarColorFor(contact.name);

    return GestureDetector(
      onTap: onTap,
      child: CustomCard(
        backgroundColor: cardBg,
        borderRadius: 18,
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: avatarColor.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(
                  color: avatarColor.withValues(alpha: 0.45),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  contact.initials,
                  style: TextStyle(
                    color: avatarColor,
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: primaryGreen,
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (contact.note != null && contact.note!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      contact.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryGreen.withValues(alpha: 0.72),
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _StatusPill(
                        label: summary.transactionCount > 0
                            ? '${summary.transactionCount} transaksi'
                            : 'Belum ada transaksi',
                        color: primaryGreen,
                        softBackground: true,
                      ),
                      if (summary.activeDebtRemaining > 0)
                        _StatusPill(
                          label:
                              'Hutang ${Formatters.rupiah(summary.activeDebtRemaining)}',
                          color: LoanHelper.overdueColor,
                        ),
                      if (summary.activeReceivableRemaining > 0)
                        _StatusPill(
                          label:
                              'Piutang ${Formatters.rupiah(summary.activeReceivableRemaining)}',
                          color: orangeText,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                color: primaryGreen,
                size: 20,
              ),
              color: appBarBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, color: primaryGreen, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Edit Kontak',
                        style: TextStyle(
                          color: primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Hapus Kontak',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool softBackground;

  const _StatusPill({
    required this.label,
    required this.color,
    this.softBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: softBackground ? 0.1 : 0.14),
        borderRadius: BorderRadius.circular(100),
        border: softBackground
            ? null
            : Border.all(color: color.withValues(alpha: 0.45), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: 'Inter',
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ContactFormSheet extends StatefulWidget {
  final ContactModel? contactToEdit;

  const _ContactFormSheet({this.contactToEdit});

  @override
  State<_ContactFormSheet> createState() => _ContactFormSheetState();
}

class _ContactFormSheetState extends State<_ContactFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;

  bool _isSaving = false;
  String? _inlineError;

  bool get _isEdit => widget.contactToEdit != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.contactToEdit?.name ?? '');
    _noteController =
        TextEditingController(text: widget.contactToEdit?.note ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
      _inlineError = null;
    });

    try {
      final contactProvider = context.read<ContactProvider>();
      final txProvider = Provider.of<TransactionProvider?>(
        context,
        listen: false,
      );
      final recProvider = Provider.of<RecurringProvider?>(
        context,
        listen: false,
      );

      final name = _nameController.text.trim();
      final rawNote = _noteController.text.trim();
      final note = rawNote.isEmpty ? null : rawNote;

      final ContactModel saved;
      if (_isEdit) {
        final editing = widget.contactToEdit!;
        final bool nameChanged = editing.name.trim() != name;
        saved = await contactProvider.updateContact(
          ContactModel(
            id: editing.id,
            name: name,
            note: note,
          ),
        );
        if (nameChanged) {
          if (txProvider != null) {
            await txProvider.loadTransactions(silent: true);
          }
          if (recProvider != null) {
            await recProvider.loadRecurring(silent: true);
          }
        }
      } else {
        saved = await contactProvider.addContact(
          name,
          note: note,
          rejectDuplicate: true,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _inlineError = ErrorMapper.message(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: primaryGreen.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isEdit ? 'Edit Kontak' : 'Tambah Kontak Baru',
                  style: const TextStyle(
                    color: primaryGreen,
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isEdit
                      ? 'Perubahan nama akan otomatis disinkronkan ke riwayat transaksi terkait.'
                      : 'Simpan nama teman agar lebih cepat saat mencatat transfer atau pinjaman.',
                  style: TextStyle(
                    color: primaryGreen.withValues(alpha: 0.75),
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  label: 'Nama Kontak',
                  hint: 'Contoh: Budi Santoso',
                  controller: _nameController,
                  validator: (val) {
                    final trimmed = val?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return 'Nama kontak tidak boleh kosong';
                    }
                    if (trimmed.length > 40) {
                      return 'Nama kontak maksimal 40 karakter';
                    }
                    return null;
                  },
                ),
                CustomTextField(
                  label: 'Catatan (Opsional)',
                  hint: 'Contoh: Teman sekelas, GoPay 0812...',
                  controller: _noteController,
                  validator: (val) {
                    if (val != null && val.trim().length > 60) {
                      return 'Catatan maksimal 60 karakter';
                    }
                    return null;
                  },
                ),
                if (_inlineError != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _inlineError!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                PrimaryButton(
                  label: _isSaving
                      ? 'Menyimpan...'
                      : (_isEdit ? 'Simpan Perubahan' : 'Simpan Kontak'),
                  onPressed: _isSaving ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
