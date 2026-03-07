import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/constants.dart";
import "dashboard_controller.dart";
import "dashboard_state.dart";
import "widgets/finance_chart_card.dart";
import "widgets/mood_trend_card.dart";
import "widgets/task_streak_card.dart";

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
            begin: const Offset(0.0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
              const SizedBox(height: 16),
              const Text('加载数据失败', style: TextStyle(color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(error.toString(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(dashboardControllerProvider.notifier).refresh(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (data) => FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: RefreshIndicator(
              onRefresh: () => ref.read(dashboardControllerProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 6, AppSpacing.md, 16),
                children: [
                  _DashboardHeader(
                    onRefresh: () => ref.read(dashboardControllerProvider.notifier).refresh(),
                  ),
                  const SizedBox(height: 12),
                  _TodayOverview(data: data),
                  const SizedBox(height: 16),
                  _TrendSection(
                    title: "支出趋势",
                    subtitle: "最近30天",
                    value: "¥${data.totalExpense30d.toStringAsFixed(2)}",
                    insight: _buildExpenseInsight(data.expenseTrend),
                    accent: AppColors.accent,
                    child: FinanceChartCard(
                      totalExpense: data.totalExpense30d,
                      trend: data.expenseTrend,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _TrendSection(
                    title: "情绪趋势",
                    subtitle: "最近7天",
                    value: _buildMoodValue(data.moodTrend),
                    insight: _buildMoodInsight(data.moodTrend),
                    accent: AppColors.warning,
                    child: MoodTrendCard(trend: data.moodTrend),
                  ),
                  const SizedBox(height: 16),
                  _InsightList(
                    items: _buildSuggestions(context, data),
                  ),
                  const SizedBox(height: 16),
                  _CompactHabitOrRecent(
                    todayCompleted: data.todayCompletedTasks,
                    todayTotal: data.todayTotalTasks,
                    streaks: data.taskStreaks,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "总览",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "今天的记录、任务和状态一目了然",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
              onPressed: onRefresh,
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayOverview extends StatelessWidget {
  const _TodayOverview({required this.data});

  final DashboardSummaryState data;

  @override
  Widget build(BuildContext context) {
    final taskText =
        "${data.todayCompletedTasks}/${data.todayTotalTasks}";
    final moodValue = _buildMoodValue(data.moodTrend);
    final todayExpense = data.expenseTrend.isNotEmpty
        ? "¥${data.expenseTrend.last.amount.toStringAsFixed(0)}"
        : "—";

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "今天",
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  title: "今日支出",
                  value: todayExpense,
                  icon: Icons.receipt_long,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetric(
                  title: "任务完成",
                  value: taskText,
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  title: "今日心情",
                  value: moodValue,
                  icon: Icons.mood,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetric(
                  title: "今日记录",
                  value: "—",
                  icon: Icons.event_note,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _TrendSection extends StatelessWidget {
  const _TrendSection({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.insight,
    required this.accent,
    required this.child,
  });

  final String title;
  final String subtitle;
  final String value;
  final String insight;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insight,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InsightList extends StatelessWidget {
  const _InsightList({required this.items});

  final List<_InsightItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "今日建议",
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          ...items.map((item) => _InsightTile(item: item)),
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.item});

  final _InsightItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, size: 16, color: item.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.text,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _CompactHabitOrRecent extends StatelessWidget {
  const _CompactHabitOrRecent({
    required this.todayCompleted,
    required this.todayTotal,
    required this.streaks,
  });

  final int todayCompleted;
  final int todayTotal;
  final List<TaskStreakModel> streaks;

  @override
  Widget build(BuildContext context) {
    final hasStreaks = streaks.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: hasStreaks
          ? TaskStreakCard(
              todayCompleted: todayCompleted,
              todayTotal: todayTotal,
              streaks: streaks,
            )
          : Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check_circle_outline,
                      color: AppColors.success, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "今日习惯：暂无计划",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _InsightItem {
  _InsightItem({
    required this.text,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

List<_InsightItem> _buildSuggestions(BuildContext context, DashboardSummaryState data) {
  final items = <_InsightItem>[];
  if (data.todayTotalTasks > data.todayCompletedTasks) {
    final remain = data.todayTotalTasks - data.todayCompletedTasks;
    items.add(
      _InsightItem(
        text: "还有 $remain 个任务待完成",
        icon: Icons.checklist,
        color: AppColors.accent,
        onTap: () => context.go('/chat'),
      ),
    );
  }
  if (data.moodTrend.isEmpty) {
    items.add(
      _InsightItem(
        text: "可以记录一下今天的状态",
        icon: Icons.mood,
        color: AppColors.warning,
        onTap: () => context.go('/chat'),
      ),
    );
  }
  if (data.expenseTrend.isEmpty) {
    items.add(
      _InsightItem(
        text: "今天还没有记录支出",
        icon: Icons.receipt_long,
        color: AppColors.accent,
        onTap: () => context.go('/chat'),
      ),
    );
  }
  if (items.isEmpty) {
    items.add(
      _InsightItem(
        text: "今天表现不错，保持节奏",
        icon: Icons.auto_awesome,
        color: AppColors.success,
        onTap: () => context.go('/chat'),
      ),
    );
  }
  return items;
}

String _buildExpenseInsight(List<ExpenseTrendModel> trend) {
  if (trend.length < 10) return "本周暂无明显变化";
  double sum(List<ExpenseTrendModel> list) =>
      list.fold(0, (p, e) => p + e.amount);
  final last7 = sum(trend.takeLast(7));
  final prev7 = sum(trend.takeLast(14).take(7).toList());
  if (prev7 == 0) return "本周支出保持稳定";
  final diff = (last7 - prev7) / prev7;
  if (diff > 0.15) return "本周支出上升较明显";
  if (diff < -0.15) return "本周支出有所回落";
  return "本周支出较为平稳";
}

String _buildMoodValue(List<MoodTrendModel> trend) {
  if (trend.isEmpty) return "—";
  final avg =
      trend.fold(0.0, (p, e) => p + e.averageValence) / trend.length;
  return "平均 ${avg.toStringAsFixed(1)} 分";
}

String _buildMoodInsight(List<MoodTrendModel> trend) {
  if (trend.length < 3) return "近几天情绪平稳";
  final last = trend.last.averageValence;
  final prev = trend[trend.length - 2].averageValence;
  if (last - prev > 0.1) return "近两天情绪有所提升";
  if (prev - last > 0.1) return "近两天情绪略有下降";
  return "近几天整体较平稳";
}

extension _ListTakeLast<E> on List<E> {
  List<E> takeLast(int n) {
    if (length <= n) return [...this];
    return sublist(length - n);
  }
}
