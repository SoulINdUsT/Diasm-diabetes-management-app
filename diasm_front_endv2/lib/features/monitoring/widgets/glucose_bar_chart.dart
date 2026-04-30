
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class GlucoseBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final double height;

  const GlucoseBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 140, // a bit tighter
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    // Compute Y range with padding
    double minY = values.reduce((a, b) => a < b ? a : b);
    double maxY = values.reduce((a, b) => a > b ? a : b);
    if (minY == maxY) {
      minY = minY - 5;
      maxY = maxY + 5;
    } else {
      final padding = (maxY - minY) * 0.12;
      minY = (minY - padding).clamp(0, double.infinity);
      maxY += padding;
    }

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < values.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: values[i],
              width: 14,
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  const Color(0xFF02C39A).withOpacity(0.20),
                  const Color(0xFF028090).withOpacity(0.80),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: const Color(0xFFF7FFFE), // soft background tint
        height: height,
        width: double.infinity,
        child: BarChart(
          BarChartData(
            minY: minY,
            maxY: maxY,
            barGroups: barGroups,
            alignment: BarChartAlignment.spaceAround,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (maxY - minY) / 3,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey.withOpacity(0.15),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final index = value.round();
                    if (index < 0 || index >= labels.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 6,
                      child: Text(
                        labels[index],
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
