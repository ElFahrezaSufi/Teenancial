import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/common/custom_card.dart';

const Color _primaryGreen = Color(0xFF627931);
const Color _scaffoldBg = Color(0xFFEDEFE2);
const Color _appBarBg = Color(0xFFF8FFE8);
const Color _cardBg = Color(0xFFF7FFE7);
const Color _orangeText = Color(0xFFE18151);
const Color _lightGreen = Color(0xFFCADCA4);

// ─── Data model ──────────────────────────────────────────────────────────────

enum TransactionType { food, transport, income, entertainment, other }

class TransactionItem {
  final TransactionType type;
  final String title;
  final String description;
  final double amount;
  final bool isExpense;

  const TransactionItem({
    required this.type,
    required this.title,
    required this.description,
    required this.amount,
    required this.isExpense,
  });
}

class TransactionGroup {
  final String dateLabel;
  final List<TransactionItem> items;

  const TransactionGroup({required this.dateLabel, required this.items});
}

// ─── Chart painter ───────────────────────────────────────────────────────────

class _TrendChartPainter extends CustomPainter {
  final List<double> values;

  _TrendChartPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final double minVal = values.reduce(min);
    final double maxVal = values.reduce(max);
    final double range = (maxVal - minVal) == 0 ? 1 : maxVal - minVal;

    final gridPaint = Paint()
      ..color = _lightGreen.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    const int gridLines = 5;
    for (int i = 0; i <= gridLines; i++) {
      final double y = size.height * i / gridLines;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final List<Offset> points = [];
    for (int i = 0; i < values.length; i++) {
      final double x = size.width * i / (values.length - 1);
      final double normalized = (values[i] - minVal) / range;
      final double y = size.height * (1 - normalized);
      points.add(Offset(x, y));
    }

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final pt in points) {
      fillPath.lineTo(pt.dx, pt.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFE53935).withValues(alpha: 0.15),
          const Color(0xFFE53935).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.fill;
    for (final pt in points) {
      canvas.drawCircle(pt, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_TrendChartPainter oldDelegate) => true;
}

// ─── Screen ──────────────────────────────────────────────────────────────────

// ─── Loading state ─────────────────────────────────────────────────────────

enum _LoadState { loading, success }

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  int _selectedFilter = 0;

  final Map<int, List<double>> _trendData = {
    0: [120, 95, 140, 80, 110, 75, 160, 130, 90, 170, 145, 185],
    1: [200, 180, 220, 160, 240, 210, 195, 230],
    2: [500, 480, 520, 560, 510, 590, 570, 610, 580, 640, 620, 680],
  };

  final Map<int, String> _maxLabels = {
    0: '+ Rp 185.000,00',
    1: '+ Rp 240.000,00',
    2: '+ Rp 680.000,00',
  };

  final List<TransactionGroup> _allGroups = const [
    TransactionGroup(
      dateLabel: 'Rabu, 08 Juli 2026',
      items: [
        TransactionItem(
          type: TransactionType.food,
          title: 'Aktivitas',
          description: 'deskripsi',
          amount: 45000,
          isExpense: true,
        ),
        TransactionItem(
          type: TransactionType.transport,
          title: 'Aktivitas',
          description: 'deskripsi',
          amount: 20000,
          isExpense: true,
        ),
      ],
    ),
    TransactionGroup(
      dateLabel: 'Senin, 06 Juli 2026',
      items: [
        TransactionItem(
          type: TransactionType.food,
          title: 'Aktivitas',
          description: 'deskripsi',
          amount: 30000,
          isExpense: true,
        ),
        TransactionItem(
          type: TransactionType.income,
          title: 'Aktivitas',
          description: 'deskripsi',
          amount: 150000,
          isExpense: false,
        ),
      ],
    ),
    TransactionGroup(
      dateLabel: 'Sabtu, 04 Juli 2026',
      items: [
        TransactionItem(
          type: TransactionType.entertainment,
          title: 'Aktivitas',
          description: 'deskripsi',
          amount: 55000,
          isExpense: true,
        ),
      ],
    ),
  ];

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    int count = 0;
    for (int i = parts.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(parts[i]);
      count++;
    }
    final reversed = buffer.toString().split('').reversed.join();
    return 'Rp $reversed,00';
  }

  IconData _iconForType(TransactionType type) {
    switch (type) {
      case TransactionType.food:
        return Icons.restaurant;
      case TransactionType.transport:
        return Icons.directions_bus;
      case TransactionType.income:
        return Icons.arrow_downward;
      case TransactionType.entertainment:
        return Icons.sports_esports;
      case TransactionType.other:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleGroups = _allGroups.take(2).toList();

    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            color: _appBarBg,
            border: Border(
              bottom: BorderSide(color: _primaryGreen, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Opacity(
      opacity: 0.4,
      child: Image.asset(
        'assets/images/bg_curve.png',
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildLoading() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter chip skeleton
            Row(
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Skeleton(width: 80, height: 34, radius: 20),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _Skeleton(width: 100, height: 16),
            const SizedBox(height: 10),
            _Skeleton(width: double.infinity, height: 180),
            const SizedBox(height: 24),
            _Skeleton(width: 130, height: 16),
            const SizedBox(height: 12),
            _Skeleton(width: double.infinity, height: 72),
            const SizedBox(height: 10),
            _Skeleton(width: double.infinity, height: 72),
            const SizedBox(height: 10),
            _Skeleton(width: double.infinity, height: 72),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Default: show only the first 2 groups; "Lihat semua" opens a new page
    final visibleGroups = _allGroups.take(2).toList();

    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: _buildAppBar(),
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
                  Row(
                    children: [
                      _FilterChip(
                        label: 'Mingguan',
                        selected: _selectedFilter == 0,
                        onTap: () => setState(() => _selectedFilter = 0),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _primaryGreen, width: 2),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _maxLabels[_selectedFilter]!,
                            style: const TextStyle(
                              color: _primaryGreen,
                              fontSize: 12,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 150,
                            child: CustomPaint(
                              painter: _TrendChartPainter(
                                  _trendData[_selectedFilter]!),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Tren Saldo',
                    style: TextStyle(
                      color: _primaryGreen,
                      fontSize: 14,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomCard(
                    backgroundColor: _cardBg,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Aktivitas Terbaru',
                          style: TextStyle(
                            color: _primaryGreen,
                            fontSize: 14,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 150,
                          child: CustomPaint(
                            painter: _TrendChartPainter(
                                _trendData[_selectedFilter]!),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Aktivitas Terbaru',
                        style: TextStyle(
                          color: _primaryGreen,
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _SemuaAktivitasScreen(
                                groups: _allGroups,
                                formatCurrency: _formatCurrency,
                                iconForType: _iconForType,
                              ),
                            );
                          },
                          child: const Text(
                            'Lihat semua',
                            style: TextStyle(
                              color: _orangeText,
                              fontSize: 13,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...visibleGroups.map(
                      (group) => _TransactionGroup(
                        group: group,
                        formatCurrency: _formatCurrency,
                        iconForType: _iconForType,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...visibleGroups.map(
                    (group) => _TransactionGroup(
                      group: group,
                      formatCurrency: _formatCurrency,
                      iconForType: _iconForType,
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SemuaAktivitasScreen extends StatelessWidget {
  final List<TransactionGroup> groups;
  final String Function(double) formatCurrency;
  final IconData Function(TransactionType) iconForType;

  const _SemuaAktivitasScreen({
    required this.groups,
    required this.formatCurrency,
    required this.iconForType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            color: _appBarBg,
            border: Border(
              bottom: BorderSide(color: _primaryGreen, width: 1.5),
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
                      color: _primaryGreen,
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
                        color: _primaryGreen, size: 20),
                    onPressed: () => Navigator.pop(context),
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
                    (group) => _TransactionGroup(
                      group: group,
                      formatCurrency: formatCurrency,
                      iconForType: iconForType,
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _primaryGreen,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _primaryGreen,
            fontSize: 13,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _TransactionGroup extends StatelessWidget {
  final TransactionGroup group;
  final String Function(double) formatCurrency;
  final IconData Function(TransactionType) iconForType;

  const _TransactionGroup({
    required this.group,
    required this.formatCurrency,
    required this.iconForType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.dateLabel,
          style: const TextStyle(
            color: _orangeText,
            fontSize: 13,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...group.items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TransactionCard(
              item: item,
              formatCurrency: formatCurrency,
              icon: iconForType(item.type),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionItem item;
  final String Function(double) formatCurrency;
  final IconData icon;

  const _TransactionCard({
    required this.item,
    required this.formatCurrency,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      backgroundColor: _cardBg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _lightGreen.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _primaryGreen, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: _primaryGreen,
                    fontSize: 14,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: const TextStyle(
                    color: _primaryGreen,
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatCurrency(item.amount),
            style: const TextStyle(
              color: _primaryGreen,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton widget ─────────────────────────────────────────────────────────

class _Skeleton extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _Skeleton({
    required this.width,
    required this.height,
    this.radius = 12,
  });

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: _lightGreen.withValues(alpha: _anim.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
