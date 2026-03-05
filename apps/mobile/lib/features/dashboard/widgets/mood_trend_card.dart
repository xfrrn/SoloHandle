import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants.dart';
import '../../../shared/widgets/glass_card.dart';
import '../dashboard_state.dart';

class MoodTrendCard extends StatelessWidget {
  const MoodTrendCard({super.key, required this.trend});

  final List<MoodTrendModel> trend;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    double sum = 0;
    for (int i = 0; i < trend.length; i++) {
        spots.add(FlSpot(i.toDouble(), trend[i].averageValence));
        sum += trend[i].averageValence;
    }
    final avgMood = trend.isNotEmpty ? sum / trend.length : 0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE68A).withOpacity(0.3), // Light warm yellow
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.wb_sunny_rounded, color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '近期情绪趋势',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    '过去 7 天平均 ${avgMood.toStringAsFixed(1)} 分',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: trend.length > 5 ? (trend.length / 5).toDouble() : 1.0,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        );
                        final index = value.toInt();
                        if (index >= 0 && index < trend.length) {
                            final dateStr = trend[index].date;
                            final displayStr = dateStr.length >= 10 ? dateStr.substring(5) : dateStr;
                            return SideTitleWidget(
                                meta: meta,
                                child: Text(displayStr, style: style),
                            );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (trend.length - 1).toDouble() > 0 ? (trend.length - 1).toDouble() : 1,
                minY: 0,
                maxY: 10,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots.isEmpty ? const [FlSpot(0, 5)] : spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFFF59E0B), // Warm yellow/orange
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.surface,
                          strokeWidth: 2,
                          strokeColor: const Color(0xFFF59E0B),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFF59E0B).withOpacity(0.3),
                          const Color(0xFFF59E0B).withOpacity(0.0),
                        ],
                      ),
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
}
