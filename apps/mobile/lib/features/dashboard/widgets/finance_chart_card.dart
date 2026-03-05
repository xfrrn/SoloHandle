import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants.dart';
import '../../../shared/widgets/glass_card.dart';
import '../dashboard_state.dart';

class FinanceChartCard extends StatelessWidget {
  const FinanceChartCard({
    super.key,
    required this.totalExpense,
    required this.trend,
  });

  final double totalExpense;
  final List<ExpenseTrendModel> trend;

  @override
  Widget build(BuildContext context) {
    // Process trend data to generate spots
    final spots = <FlSpot>[];
    double maxAmount = 3000;
    
    if (trend.isNotEmpty) {
      maxAmount = trend.map((e) => e.amount).reduce(max);
      maxAmount = maxAmount == 0 ? 1000 : maxAmount * 1.2;
      
      for (int i = 0; i < trend.length; i++) {
        spots.add(FlSpot(i.toDouble(), trend[i].amount));
      }
    } else {
      spots.add(const FlSpot(0, 0));
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '最近30天支出',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '¥${totalExpense.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.show_chart, color: AppColors.accent, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxAmount / 3) > 0 ? (maxAmount / 3) : 100,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.divider.withOpacity(0.5),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                           // Example: '2023-11-05' -> '11-05'
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
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (trend.length - 1).toDouble() > 0 ? (trend.length - 1).toDouble() : 1,
                minY: 0,
                maxY: maxAmount,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.accent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.accent.withOpacity(0.3),
                          AppColors.accent.withOpacity(0.0),
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
