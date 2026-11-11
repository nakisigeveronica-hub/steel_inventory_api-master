import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class DashboardPerformanceChart extends StatelessWidget {
  final int totalProducts;
  final int totalRawMaterials;
  final int totalSuppliers;
  final int lowStockItems;

  const DashboardPerformanceChart({
    super.key,
    required this.totalProducts,
    required this.totalRawMaterials,
    required this.totalSuppliers,
    required this.lowStockItems,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final chartData = [
      _ChartBar(
        'Products',
        totalProducts.toDouble(),
        theme.colorScheme.primary,
      ),
      _ChartBar(
        'Raw',
        totalRawMaterials.toDouble(),
        theme.colorScheme.secondary,
      ),
      _ChartBar('Sup', totalSuppliers.toDouble(), Colors.deepPurple),
      _ChartBar('Low', lowStockItems.toDouble(), Colors.orange),
    ];

    if (chartData.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxValue = chartData
        .map((entry) => entry.value)
        .reduce((a, b) => a > b ? a : b);

    final chartMax = maxValue > 0 ? maxValue * 1.2 : 1.0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Overview',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 132,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: chartMax,
                barTouchData: BarTouchData(enabled: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: chartMax / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: theme.dividerColor, strokeWidth: 1);
                  },
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= chartData.length) {
                          return const SizedBox();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            chartData[index].label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(chartData.length, (index) {
                  final item = chartData[index];
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: item.value,
                        width: 18,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        color: item.color,
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartBar {
  final String label;
  final double value;
  final Color color;

  const _ChartBar(this.label, this.value, this.color);
}
