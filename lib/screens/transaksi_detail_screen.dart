import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/transaction_model.dart';
import '../repositories/transaction_repository.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/common/primary_button.dart';
import '../widgets/common/skeleton.dart';
import 'pemasukan_screen.dart';
import 'pengeluaran_screen.dart';

/// Layar detail transaksi. Diakses lewat rute /transaksi/:id.
/// ID tidak valid atau gagal memuat -> tampil pesan + tombol Kembali/Coba lagi.
class TransaksiDetailScreen extends StatefulWidget {
  final String id;
  const TransaksiDetailScreen({super.key, required this.id});

  @override
  State<TransaksiDetailScreen> createState() => _TransaksiDetailScreenState();
}

class _TransaksiDetailScreenState extends State<TransaksiDetailScreen> {
  TransactionModel? _item;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final t = await TransactionRepository.instance.getTransactionById(widget.id);
      if (!mounted) return;
      setState(() {
        _item = t;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/riwayat');
    }
  }

  Future<void> _edit() async {
    final t = _item!;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => t.type == TransactionType.income
            ? PemasukanScreen(transactionToEdit: t)
            : PengeluaranScreen(transactionToEdit: t),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _delete() async {
    if (_busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi', style: TextStyle(color: primaryGreen)),
        content: const Text('Apakah Anda yakin ingin menghapus data ini? Aksi ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      await TransactionRepository.instance.deleteTransaction(widget.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✅ Data berhasil dihapus!'),
            backgroundColor: primaryGreen),
      );
      _back();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Gagal menghapus: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(
                      color: primaryGreen, fontWeight: FontWeight.w700)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        foregroundColor: primaryGreen,
        title: const Text('Detail Transaksi',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: _back,
        ),
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Skeleton(width: double.infinity, height: 180),
        ],
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              PrimaryButton(label: 'Coba lagi', onPressed: _load),
              TextButton(
                onPressed: _back,
                child: const Text('Kembali',
                    style: TextStyle(color: primaryGreen)),
              ),
            ],
          ),
        ),
      );
    }
    final t = _item!;
    final cat = TransactionRepository.instance.getCategoryById(t.categoryId);
    final isExpense = t.type == TransactionType.expense;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomCard(
            backgroundColor: cardBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title,
                    style: const TextStyle(
                        color: primaryGreen,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  '${isExpense ? '-' : '+'} ${CurrencyInputFormatter.formatValue(t.amount.toStringAsFixed(0))}',
                  style: TextStyle(
                      color: isExpense ? Colors.red : primaryGreen,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                ),
                const Divider(height: 24),
                _row('Jenis', isExpense ? 'Pengeluaran' : 'Pemasukan'),
                _row('Kategori', cat.name),
                _row('Sumber', t.isDigital ? 'Digital' : 'Cash'),
                _row('Tanggal',
                    '${t.date.day}/${t.date.month}/${t.date.year} ${t.date.hour.toString().padLeft(2, '0')}:${t.date.minute.toString().padLeft(2, '0')}'),
                _row('Catatan', t.notes.isEmpty ? '-' : t.notes),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Edit', onPressed: _busy ? null : _edit),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _busy ? null : _delete,
            child: Text(_busy ? 'Menghapus...' : 'Hapus',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
