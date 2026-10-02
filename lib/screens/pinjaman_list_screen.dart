import 'package:flutter/material.dart';
import '../data/pinjaman_model.dart';
import '../repositories/pinjaman_repository.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/common/custom_card.dart';
import '../widgets/common/skeleton.dart';
import '../widgets/transaction/transaction_scaffold.dart';

enum _State { loading, success, empty, error }

class PinjamanListScreen extends StatefulWidget {
  const PinjamanListScreen({super.key});

  @override
  State<PinjamanListScreen> createState() => _PinjamanListScreenState();
}

class _PinjamanListScreenState extends State<PinjamanListScreen> {
  _State _state = _State.loading;
  List<PinjamanItem> _items = [];
  String _error = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _State.loading);
    try {
      final data = await PinjamanRepository.instance.getAll();
      if (!mounted) return;
      setState(() {
        _items = data;
        _state = data.isEmpty ? _State.empty : _State.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _state = _State.error;
      });
    }
  }

  Future<void> _delete(PinjamanItem item) async {
    if (_busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Data', style: TextStyle(color: primaryGreen)),
        content: Text('Hapus ${item.jenis.label.toLowerCase()} ${item.nama}?'),
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
      await PinjamanRepository.instance.delete(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Data berhasil dihapus!'),
              backgroundColor: primaryGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('❌ Gagal menghapus: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _load();
  }

  String _rp(double v) => CurrencyInputFormatter.formatValue(v.toStringAsFixed(0));

  @override
  Widget build(BuildContext context) {
    return TransactionScaffold(
      title: 'Daftar Pinjaman',
      child: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    switch (_state) {
      case _State.loading:
        return ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            Skeleton(width: double.infinity, height: 72),
            SizedBox(height: 12),
            Skeleton(width: double.infinity, height: 72),
            SizedBox(height: 12),
            Skeleton(width: double.infinity, height: 72),
          ],
        );
      case _State.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(_error, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _load,
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                  child: const Text('Coba lagi',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      case _State.empty:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Belum ada pinjaman atau piutang.\nTambahkan lewat tombol Simpan di layar sebelumnya.',
              textAlign: TextAlign.center,
              style: TextStyle(color: primaryGreen),
            ),
          ),
        );
      case _State.success:
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final p = _items[i];
            final isPinjaman = p.jenis == JenisPinjaman.pinjaman;
            return CustomCard(
              backgroundColor: cardBg,
              borderRadius: 16,
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
              child: Row(
                children: [
                  Icon(isPinjaman ? Icons.call_received : Icons.call_made,
                      color: isPinjaman ? Colors.red : primaryGreen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${p.jenis.label} - ${p.nama}',
                            style: const TextStyle(
                                color: primaryGreen,
                                fontWeight: FontWeight.w700)),
                        Text(
                            '${_rp(p.jumlah)} • tempo ${p.jatuhTempo.day}/${p.jatuhTempo.month}/${p.jatuhTempo.year}',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: _busy ? null : () => _delete(p),
                  ),
                ],
              ),
            );
          },
        );
    }
  }
}
