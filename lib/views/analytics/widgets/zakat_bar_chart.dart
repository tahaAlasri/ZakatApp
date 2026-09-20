import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import 'zakat_donut_chart.dart';

class ZakatBarChart extends StatefulWidget {
  final List<ChartDataSegment> items;
  final String currency;

  const ZakatBarChart({
    super.key,
    required this.items,
    required this.currency,
  });

  @override
  State<ZakatBarChart> createState() => _ZakatBarChartState();
}

class _ZakatBarChartState extends State<ZakatBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _animation;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
  void didUpdateWidget(covariant ZakatBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _animCtrl.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'لا توجد بيانات كافية لرسم المقارنة الشريطة',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
      );
    }

    final maxValue = widget.items.fold<double>(
      0.0,
      (max, item) => math.max(max, item.value),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 180,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(widget.items.length, (index) {
                  final item = widget.items[index];
                  final isSelected = _selectedIndex == index;
                  final barHeight = maxValue > 0
                      ? (item.value / maxValue) * 120 * _animation.value
                      : 0.0;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedIndex = _selectedIndex == index ? null : index;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Value text label
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                AppFormatters.formatNumber(item.value, decimals: 0),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? (isDark ? AppColors.goldLight : AppColors.emeraldPrimary)
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Animated Bar
                            Container(
                              height: math.max(4.0, barHeight),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isSelected
                                      ? [item.color, item.color.withValues(alpha: 0.7)]
                                      : [
                                          item.color.withValues(alpha: 0.85),
                                          item.color.withValues(alpha: 0.45),
                                        ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: item.color.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, -2),
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Category short label
                            Text(
                              item.label,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}
