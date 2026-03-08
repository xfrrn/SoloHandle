import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";

import "../../../core/constants.dart";
import "../../../shared/widgets/glass_card.dart";
import "../dashboard_state.dart";

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
                  color: const Color(0xFFFDE68A).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.wb_sunny_rounded,
                    color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "\u8fd1\u671f\u60c5\u7eea\u8d8b\u52bf",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    "\u8fc7\u53bb 7 \u5929\u5e73\u5747 ${avgMood.toStringAsFixed(0)} \u5206",
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
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(
                            color: AppColors.textSecondary, fontSize: 10);
                        final index = value.toInt();
                        if (index >= 0 &&
                            index < trend.length &&
                            _shouldShowDateLabel(index, trend.length)) {
                          final dateStr = trend[index].date;
                          final displayStr = dateStr.length >= 10
                              ? dateStr.substring(5)
                              : dateStr;
                          return SideTitleWidget(
                              meta: meta,
                              child: Text(displayStr, style: style));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (trend.length - 1).toDouble() > 0
                    ? (trend.length - 1).toDouble()
                    : 1,
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots.isEmpty ? const [FlSpot(0, 50)] : spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFFF59E0B),
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
                          const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          const Color(0xFFF59E0B).withValues(alpha: 0.0),
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

bool _shouldShowDateLabel(int index, int total) {
  if (total <= 1) return index == 0;
  if (index == 0 || index == total - 1) return true;
  final step = (total / 4).ceil();
  if (index >= total - step) return false;
  return index % step == 0;
}
