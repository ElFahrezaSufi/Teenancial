import '../models/models.dart';

DateTime _utc(DateTime d) => DateTime.utc(d.year, d.month, d.day);
List<double> buildTrend(List<AppTransaction> txs, int period,
    {DateTime? anchor}) {
  const spans = [1, 4, 30];
  const counts = [7, 8, 12];
  final span = spans[period];
  final n = counts[period];

  DateTime end;
  if (anchor != null) {
    end = _utc(anchor);
  } else if (txs.isEmpty) {
    end = _utc(DateTime.now());
  } else {
    end = _utc(txs.map((t) => t.date).reduce((a, b) => a.isAfter(b) ? a : b));
  }
  final start = end.subtract(Duration(days: n * span - 1));

  final buckets = List<double>.filled(n, 0);
  for (final t in txs) {
    final d = _utc(t.date);
    if (d.isBefore(start) || d.isAfter(end)) continue;
    final idx = d.difference(start).inDays ~/ span;
    buckets[idx] += t.isExpense ? -t.amount : t.amount;
  }
  double running = 0;
  return buckets.map((b) => running += b).toList();
}
