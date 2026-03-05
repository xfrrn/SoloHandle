import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../shared/widgets/glass_card.dart';

class TaskStreakCard extends StatelessWidget {
  const TaskStreakCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.successLight, // Light green
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '打卡与习惯',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    '今天已完成 3 个任务',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStreakCircle(context, label: '阅读', days: 12, progress: 0.8),
              _buildStreakCircle(context, label: '运动', days: 5, progress: 0.5),
              _buildStreakCircle(context, label: '冥想', days: 2, progress: 0.2),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStreakCircle(BuildContext context, {required String label, required int days, required double progress}) {
    return Column(
      children: [
        SizedBox(
          width: 70,
          height: 70,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 6,
                backgroundColor: AppColors.divider.withOpacity(0.5),
                color: AppColors.success,
                strokeCap: StrokeCap.round,
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$days',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      '天',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
