import 'dart:io';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../models/target_model.dart';
import '../providers/dompet_provider.dart';
import '../providers/target_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../utils/error_mapper.dart';
import '../widgets/common/custom_card.dart';

class TargetMenabungScreen extends StatelessWidget {
  const TargetMenabungScreen({super.key});

  Future<void> _navigasiDanTambahData(BuildContext context) async {
    await context.push(AppRoutes.buatTarget);
  }

  String _formatRupiah(double value) {
    final parts = value.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i != 0 && (parts.length - i) % 3 == 0) buffer.write('.');
      buffer.write(parts[i]);
    }
    return 'Rp ${buffer.toString()}';
  }

  Widget _buildTargetImage(String imageUrl) {
    final fallback = Container(
      height: 160,
      color: Colors.grey[300],
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );

    if (imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 160,
          color: lightGreen.withValues(alpha: 0.35),
          child: const Center(
            child: CircularProgressIndicator(color: primaryGreen),
          ),
        ),
        errorWidget: (context, url, error) => fallback,
      );
    }

    return Image.file(
      File(imageUrl),
      height: 160,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetProvider = context.watch<TargetProvider>();
    final items = targetProvider.items;
    final saldoSekarang = context.watch<DompetProvider>().totalSaldo;
    final totalAllocated = targetProvider.totalAllocated;
    final availableSaldo = targetProvider.availableToAllocate(saldoSekarang);

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
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: primaryGreen,
                        size: 20,
                      ),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    'Target Menabung',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 25,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
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
          Container(
            color: scaffoldBg,
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                'assets/images/bg_curve.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (targetProvider.isLoading && items.isEmpty)
            const Center(
              child: CircularProgressIndicator(color: primaryGreen),
            )
          else
            SafeArea(
              child: RefreshIndicator(
                color: primaryGreen,
                backgroundColor: scaffoldBg,
                onRefresh: () =>
                    context.read<TargetProvider>().loadTargets(silent: true),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 160),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (items.isEmpty)
                        _buildEmptyState(context)
                      else ...[
                        _buildAllocationSummaryCard(
                          saldoSekarang: saldoSekarang,
                          totalAllocated: totalAllocated,
                          availableSaldo: availableSaldo,
                        ),
                        const SizedBox(height: 20),
                        ...items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: _buildTargetCard(
                              context,
                              item: item,
                              saldoSekarang: saldoSekarang,
                              availableSaldo: availableSaldo,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: items.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 140.0),
              child: FloatingActionButton(
                onPressed: () => _navigasiDanTambahData(context),
                backgroundColor: primaryGreen,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 30),
              ),
            )
          : null,
    );
  }

  Widget _buildAllocationSummaryCard({
    required double saldoSekarang,
    required double totalAllocated,
    required double availableSaldo,
  }) {
    final bool isOverAllocated = totalAllocated > saldoSekarang + 0.0001;

    return CustomCard(
      backgroundColor: appBarBg,
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saldo Bebas Tersedia',
                      style: TextStyle(
                        color: primaryGreen.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatRupiah(availableSaldo),
                      style: const TextStyle(
                        color: primaryGreen,
                        fontSize: 18,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1.5,
                height: 36,
                color: primaryGreen.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Dialokasikan',
                      style: TextStyle(
                        color: primaryGreen.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatRupiah(totalAllocated),
                      style: const TextStyle(
                        color: Color(0xFFDAB62C),
                        fontSize: 18,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isOverAllocated) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Total alokasi melebihi saldo dompet saat ini karena pengeluaran. Tarik sebagian alokasi atau tambah saldo dompet.',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return CustomCard(
      backgroundColor: appBarBg,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 60,
            color: primaryGreen.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada target impian nih!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primaryGreen,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yuk mulai tabung uangmu untuk beli barang impianmu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primaryGreen.withValues(alpha: 0.7),
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _navigasiDanTambahData(context),
            child: CustomCard(
              borderRadius: 100,
              backgroundColor: primaryGreen,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Buat Target Baru',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetCard(
    BuildContext context, {
    required TargetItem item,
    required double saldoSekarang,
    required double availableSaldo,
  }) {
    final double progress = item.progress;
    final String terkumpulStr = _formatRupiah(item.savedAmount);
    final String targetStr = _formatRupiah(item.targetAmount);
    final bool canDeposit = !item.isAchieved && availableSaldo > 0;
    final bool canWithdraw = item.savedAmount > 0;

    return CustomCard(
      backgroundColor: cardBg,
      borderRadius: 20,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
                child: _buildTargetImage(item.imageUrl),
              ),
              if (item.isAchieved)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Tercapai 🎉',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.more_vert,
                      color: primaryGreen,
                      size: 20,
                    ),
                    color: appBarBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final bool? confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text(
                              'Hapus Target',
                              style: TextStyle(color: primaryGreen),
                            ),
                            content: const Text(
                              'Apakah Anda yakin ingin menghapus target ini?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text(
                                  'Batal',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'Hapus',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && context.mounted) {
                          try {
                            await context
                                .read<TargetProvider>()
                                .deleteTarget(item.id);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Gagal menghapus target: ${ErrorMapper.message(e)}',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Hapus Target',
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
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () async {
                    try {
                      await context.read<TargetProvider>().togglePin(item);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Gagal mengubah pin target: ${ErrorMapper.message(e)}',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.isPinned
                          ? const Color(0xFFDAB62C).withValues(alpha: 0.2)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 24,
                      color:
                          item.isPinned ? const Color(0xFFDAB62C) : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nama,
                        style: const TextStyle(
                          color: primaryGreen,
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$terkumpulStr / $targetStr',
                        style: TextStyle(
                          color: primaryGreen.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: primaryGreen,
                    fontSize: 14,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: lightGreen,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canWithdraw
                        ? () => _showAllocationDialog(
                              context,
                              item: item,
                              isDeposit: false,
                              saldoSekarang: saldoSekarang,
                              availableSaldo: availableSaldo,
                            )
                        : null,
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: const Text(
                      'Tarik',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryGreen,
                      side: BorderSide(
                        color: canWithdraw
                            ? primaryGreen
                            : Colors.grey.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: canDeposit
                        ? () => _showAllocationDialog(
                              context,
                              item: item,
                              isDeposit: true,
                              saldoSekarang: saldoSekarang,
                              availableSaldo: availableSaldo,
                            )
                        : null,
                    icon: const Icon(Icons.savings_outlined, size: 18),
                    label: Text(
                      item.isAchieved ? 'Tercapai' : 'Tabung',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          Colors.grey.withValues(alpha: 0.3),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
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

  Future<void> _showAllocationDialog(
    BuildContext context, {
    required TargetItem item,
    required bool isDeposit,
    required double saldoSekarang,
    required double availableSaldo,
  }) async {
    final remainingTarget =
        (item.targetAmount - item.savedAmount).clamp(0.0, double.infinity);
    final double maxAmount =
        isDeposit ? math.min(availableSaldo, remainingTarget) : item.savedAmount;

    final double? submittedAmount = await showDialog<double>(
      context: context,
      builder: (_) => _TargetAllocationDialog(
        targetName: item.nama,
        isDeposit: isDeposit,
        maxAmount: maxAmount,
        formatRupiah: _formatRupiah,
      ),
    );

    if (submittedAmount == null || !context.mounted) return;

    try {
      await context.read<TargetProvider>().allocateTargetFunds(
            targetId: item.id,
            amountDelta: isDeposit ? submittedAmount : -submittedAmount,
            totalWalletBalance: saldoSekarang,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDeposit
                  ? '✅ Berhasil menabung ${_formatRupiah(submittedAmount)} ke ${item.nama}!'
                  : '✅ Berhasil menarik ${_formatRupiah(submittedAmount)} dari ${item.nama}!',
            ),
            backgroundColor: primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final message = ErrorMapper.message(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _TargetAllocationDialog extends StatefulWidget {
  final String targetName;
  final bool isDeposit;
  final double maxAmount;
  final String Function(double) formatRupiah;

  const _TargetAllocationDialog({
    required this.targetName,
    required this.isDeposit,
    required this.maxAmount,
    required this.formatRupiah,
  });

  @override
  State<_TargetAllocationDialog> createState() =>
      _TargetAllocationDialogState();
}

class _TargetAllocationDialogState extends State<_TargetAllocationDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final raw = _controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = double.tryParse(raw) ?? 0.0;
    if (amount <= 0) {
      setState(() => _errorText = 'Masukkan nominal lebih dari Rp 0');
      return;
    }
    if (amount > widget.maxAmount + 0.0001) {
      setState(
        () => _errorText = widget.isDeposit
            ? 'Melebihi batas maksimal (${widget.formatRupiah(widget.maxAmount)})'
            : 'Melebihi saldo tersimpan (${widget.formatRupiah(widget.maxAmount)})',
      );
      return;
    }
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: appBarBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        widget.isDeposit ? 'Tabung ke Target' : 'Tarik Alokasi Target',
        style: const TextStyle(
          color: primaryGreen,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.targetName,
              style: const TextStyle(
                color: primaryGreen,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isDeposit
                  ? 'Maksimal dapat ditabung: ${widget.formatRupiah(widget.maxAmount)}'
                  : 'Tersimpan di target ini: ${widget.formatRupiah(widget.maxAmount)}',
              style: TextStyle(
                color: primaryGreen.withValues(alpha: 0.75),
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              autofocus: true,
              style: const TextStyle(
                color: primaryGreen,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Rp 0',
                errorText: _errorText,
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryGreen, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryGreen, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryGreen, width: 2),
                ),
              ),
            ),
            if (widget.maxAmount > 0) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    _controller.text = CurrencyInputFormatter.formatValue(
                      widget.maxAmount.toStringAsFixed(0),
                    );
                    setState(() => _errorText = null);
                  },
                  child: Text(
                    widget.isDeposit ? 'Isi Maksimal' : 'Tarik Semua',
                    style: const TextStyle(
                      color: primaryGreen,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
          child: const Text(
            'Batal',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          onPressed: _submit,
          child: Text(widget.isDeposit ? 'Tabung' : 'Tarik'),
        ),
      ],
    );
  }
}
