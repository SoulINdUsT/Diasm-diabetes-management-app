
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class FitbitLineChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final double height;

  const FitbitLineChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return const SizedBox.shrink();
    }

    // Build spots
    final spots = <FlSpot>[];
    for (int i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }

    // Y range with padding
    double minY = values.reduce((a, b) => a < b ? a : b);
    double maxY = values.reduce((a, b) => a > b ? a : b);
    if (minY == maxY) {
      // flat series: keep but expand a bit so line is not exactly center
      minY = minY - 1;
      maxY = maxY + 1;
    } else {
      final padding = (maxY - minY) * 0.12;
      minY -= padding;
      maxY += padding;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: const Color(0xFFF7FFFE), // very soft background tint
        height: height,
        width: double.infinity,
        child: LineChart(
          LineChartData(
            // extra padding on X so first/last labels are not clipped
            minX: -0.5,
            maxX: (values.length - 1).toDouble() + 0.5,
            minY: minY,
            maxY: maxY,
            lineTouchData: const LineTouchData(enabled: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (maxY - minY) / 3,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey.withOpacity(0.15),
                strokeWidth: 1,
              ),
            ),
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
                  reservedSize: 22, // a bit tighter
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
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.35,
                barWidth: 3.5, // thicker line for visibility
                isStrokeCapRound: true,
                color: const Color(0xFF028090), // line color (blue-teal)
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF028090).withOpacity(0.45), // stronger top
                      const Color(0xFF02C39A).withOpacity(0.12), // subtle bottom
                    ],
                  ),
                ),
                dotData: FlDotData(
                  show: true,
                  checkToShowDot:
                      (spot, barData) => _showLastPointOnly(spot, barData),
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 3, // dot size
                      color: const Color(0xFF028090),
                      strokeColor: Colors.white,
                      strokeWidth: 1,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show dot only on last point – gives “current value” feel without clutter
  static bool _showLastPointOnly(FlSpot spot, LineChartBarData bar) {
    if (bar.spots.isEmpty) return false;
    return spot == bar.spots.last;
  }
}
