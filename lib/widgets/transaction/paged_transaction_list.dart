import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../theme/app_colors.dart';
import 'transaction_card.dart';

/// Daftar transaksi yang dikelompokkan per tanggal dan dimuat secara bertahap
/// (paginasi sisi klien, default 20 transaksi per batch).
class PagedTransactionList extends StatefulWidget {
  final List<TransactionModel> transactions;
  final String Function(double) formatCurrency;
  final ValueChanged<TransactionModel> onEdit;
  final ValueChanged<String> onDelete;
  final Future<void> Function()? onRefresh;
  final int pageSize;
  final Object? filterKey;

  const PagedTransactionList({
    super.key,
    required this.transactions,
    required this.formatCurrency,
    required this.onEdit,
    required this.onDelete,
    this.onRefresh,
    this.pageSize = 20,
    this.filterKey,
  });

  @override
  State<PagedTransactionList> createState() => _PagedTransactionListState();
}

sealed class _ListEntry {
  const _ListEntry();
}

class _HeaderEntry extends _ListEntry {
  final String dateLabel;
  final bool isFirst;
  const _HeaderEntry(this.dateLabel, {required this.isFirst});
}

class _TransactionEntry extends _ListEntry {
  final TransactionModel transaction;
  const _TransactionEntry(this.transaction);
}

class _FooterEntry extends _ListEntry {
  final int shownCount;
  final int totalCount;
  const _FooterEntry({required this.shownCount, required this.totalCount});
}

class _PagedTransactionListState extends State<PagedTransactionList> {
  final ScrollController _scrollController = ScrollController();
  late int _visibleCount;

  @override
  void initState() {
    super.initState();
    _visibleCount = math.min(widget.pageSize, widget.transactions.length);
  }

  @override
  void didUpdateWidget(covariant PagedTransactionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterKey != widget.filterKey) {
      _visibleCount = math.min(widget.pageSize, widget.transactions.length);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    } else if (oldWidget.transactions != widget.transactions) {
      final target = math.max(_visibleCount, widget.pageSize);
      _visibleCount = math.min(target, widget.transactions.length);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMore() {
    if (_visibleCount >= widget.transactions.length) return;
    setState(() {
      _visibleCount = math.min(
        _visibleCount + widget.pageSize,
        widget.transactions.length,
      );
    });
  }

  String _formatGroupDate(DateTime date) {
    try {
      return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return DateFormat('EEEE, dd MMMM yyyy').format(date);
    }
  }

  List<_ListEntry> _buildEntries() {
    final int count = math.min(_visibleCount, widget.transactions.length);
    final entries = <_ListEntry>[];
    String? lastDateLabel;

    for (int i = 0; i < count; i++) {
      final tx = widget.transactions[i];
      final dateLabel = _formatGroupDate(tx.date);
      if (dateLabel != lastDateLabel) {
        entries.add(_HeaderEntry(dateLabel, isFirst: lastDateLabel == null));
        lastDateLabel = dateLabel;
      }
      entries.add(_TransactionEntry(tx));
    }

    if (widget.transactions.isNotEmpty) {
      entries.add(
        _FooterEntry(
          shownCount: count,
          totalCount: widget.transactions.length,
        ),
      );
    }

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries();

    final listView = ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        switch (entry) {
          case _HeaderEntry():
            return Padding(
              padding: EdgeInsets.only(
                top: entry.isFirst ? 0 : 12,
                bottom: 8,
              ),
              child: Text(
                entry.dateLabel,
                style: const TextStyle(
                  color: orangeText,
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          case _TransactionEntry():
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TransactionCard(
                key: ValueKey(entry.transaction.id),
                item: entry.transaction,
                formatCurrency: widget.formatCurrency,
                onEdit: widget.onEdit,
                onDelete: widget.onDelete,
              ),
            );
          case _FooterEntry():
            final hasMore = entry.shownCount < entry.totalCount;
            final nextBatch = math.min(
              widget.pageSize,
              entry.totalCount - entry.shownCount,
            );
            return Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Column(
                children: [
                  Text(
                    'Menampilkan ${entry.shownCount} dari ${entry.totalCount} transaksi',
                    style: TextStyle(
                      color: primaryGreen.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hasMore) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _loadMore,
                      icon: const Icon(
                        Icons.expand_more_rounded,
                        color: primaryGreen,
                        size: 20,
                      ),
                      label: Text(
                        'Muat Lebih Banyak ($nextBatch lagi)',
                        style: const TextStyle(
                          color: primaryGreen,
                          fontSize: 13,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: cardBg,
                        side: const BorderSide(
                          color: primaryGreen,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
        }
      },
    );

    if (widget.onRefresh != null) {
      return RefreshIndicator(
        color: primaryGreen,
        backgroundColor: scaffoldBg,
        onRefresh: widget.onRefresh!,
        child: listView,
      );
    }
    return listView;
  }
}
