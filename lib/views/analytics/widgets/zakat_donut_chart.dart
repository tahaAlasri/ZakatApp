import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';

class ChartDataSegment {
  final String label;
  final double value;
  final Color color;
  final String? subtitle;

  const ChartDataSegment({
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });
}

class ZakatDonutChart extends StatefulWidget {
  final List<ChartDataSegment> segments;
  final double totalAmount;
  final String currency;
  final String centerTitle;

  const ZakatDonutChart({
    super.key,
    required this.segments,
    required this.totalAmount,
    required this.currency,
    this.centerTitle = 'إجمالي الزكاة',
  });

  @override
  State<ZakatDonutChart> createState() => _ZakatDonutChartState();
}

class _ZakatDonutChartState extends State<ZakatDonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _animation;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ZakatDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalAmount != widget.totalAmount ||
        oldWidget.segments.length != widget.segments.length) {
      _animCtrl.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = widget.totalAmount > 0
        ? widget.totalAmount
        : widget.segments.fold<double>(0.0, (sum, s) => sum + s.value);

    if (widget.segments.isEmpty || total <= 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'لا توجد عمليات زكوية مسجلة بعد لعرض المخطط',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Donut Chart Canvas
        SizedBox(
          height: 220,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(200, 200),
                    painter: _DonutChartPainter(
                      segments: widget.segments,
                      total: total,
                      progress: _animation.value,
                      hoveredIndex: _hoveredIndex,
                      isDark: isDark,
                    ),
                  ),
                  // Center Text info
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _hoveredIndex != null && _hoveredIndex! < widget.segments.length
                            ? widget.segments[_hoveredIndex!].label
                            : widget.centerTitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _hoveredIndex != null && _hoveredIndex! < widget.segments.length
                            ? AppFormatters.formatNumber(widget.segments[_hoveredIndex!].value, decimals: 0)
                            : AppFormatters.formatNumber(total, decimals: 0),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.goldLight : AppColors.emeraldPrimary,
                        ),
                      ),
                      Text(
                        widget.currency,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Legend Breakdown
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(widget.segments.length, (index) {
            final seg = widget.segments[index];
            final pct = total > 0 ? (seg.value / total * 100) : 0.0;
            final isHovered = _hoveredIndex == index;

            return InkWell(
              onTap: () {
                setState(() {
                  _hoveredIndex = _hoveredIndex == index ? null : index;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isHovered
                      ? seg.color.withValues(alpha: isDark ? 0.35 : 0.20)
                      : (isDark ? AppColors.darkCard : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isHovered ? seg.color : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: seg.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      seg.label,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<ChartDataSegment> segments;
  final double total;
  final double progress;
  final int? hoveredIndex;
  final bool isDark;

  _DonutChartPainter({
    required this.segments,
    required this.total,
    required this.progress,
    required this.hoveredIndex,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 26.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    double startAngle = -math.pi / 2;
    final maxSweep = 2 * math.pi * progress;

    double accumulatedAngle = 0;

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final sweepAngle = (seg.value / total) * 2 * math.pi;
      final currentSweep = math.min(sweepAngle, math.max(0.0, maxSweep - accumulatedAngle));

      if (currentSweep > 0) {
        final isSelected = hoveredIndex == i;
        paint.color = seg.color;
        paint.strokeWidth = isSelected ? strokeWidth + 6 : strokeWidth;

        final currentRadius = isSelected ? radius - strokeWidth / 2 + 2 : radius - strokeWidth / 2;

        // Draw arc
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: currentRadius),
          startAngle,
          currentSweep,
          false,
          paint,
        );

        // Gap line
        if (segments.length > 1) {
          final gapPaint = Paint()
            ..color = isDark ? AppColors.darkSurface : Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5;
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: currentRadius),
            startAngle + currentSweep - 0.02,
            0.04,
            false,
            gapPaint,
          );
        }
      }

      startAngle += sweepAngle;
      accumulatedAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.total != total;
  }
}
