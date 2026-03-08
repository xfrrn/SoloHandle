import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../core/constants.dart";
import "../../core/time.dart";
import "../../data/api/api_client.dart";
import "../../data/api/events_api.dart";
import "../../data/api/models.dart";
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
  EventDto? _todayMood;
  bool _moodLoading = true;
  bool _moodSaving = false;
  int _moodDraftPercent = 50;
  bool _moodDraftDirty = false;
  final TextEditingController _moodPercentController =
      TextEditingController(text: "50");
  int _expenseWindowDays = 7;

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
    _loadTodayMood();
  }

  @override
  void dispose() {
    _controller.dispose();
    _moodPercentController.dispose();
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
              const Icon(Icons.error_outline,
                  color: AppColors.danger, size: 48),
              const SizedBox(height: 16),
              const Text('加载数据失败',
                  style: TextStyle(color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(error.toString(),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(dashboardControllerProvider.notifier).refresh(),
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
              onRefresh: _refreshAll,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 6, AppSpacing.md, 16),
                children: [
                  _DashboardHeader(
                    onRefresh: () {
                      ref.read(dashboardControllerProvider.notifier).refresh();
                      _loadTodayMood();
                    },
                  ),
                  const SizedBox(height: 12),
                  _TodayOverview(
                    data: data,
                    moodSummary: _todayMoodSummary(),
                  ),
                  const SizedBox(height: 12),
                  _TodayMoodCard(
                    todayMood: _todayMood,
                    loading: _moodLoading,
                    saving: _moodSaving,
                    draftPercent: _moodDraftPercent,
                    draftDirty: _moodDraftDirty,
                    onPick: _onPickMoodOption,
                    onEditPercent: _openMoodPercentDialog,
                    onConfirm: _saveMoodDraft,
                    onReset: _resetMoodDraftFromSaved,
                  ),
                  const SizedBox(height: 16),
                  _TrendSection(
                    title: "Expense Trend",
                    subtitle: "Last $_expenseWindowDays days",
                    value:
                        "¥${_sumExpense(_expenseTrendByWindow(data.expenseTrend)).toStringAsFixed(2)}",
                    insight: _buildExpenseInsight(
                      _expenseTrendByWindow(data.expenseTrend),
                    ),
                    accent: AppColors.accent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ExpenseWindowSwitch(
                          selectedDays: _expenseWindowDays,
                          onChanged: (days) {
                            if (_expenseWindowDays == days) return;
                            setState(() => _expenseWindowDays = days);
                          },
                        ),
                        const SizedBox(height: 10),
                        FinanceChartCard(
                          title: "Last $_expenseWindowDays days spending",
                          totalExpense: _sumExpense(
                              _expenseTrendByWindow(data.expenseTrend)),
                          trend: _expenseTrendByWindow(data.expenseTrend),
                        ),
                      ],
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

  Future<void> _refreshAll() async {
    await Future.wait([
      ref.read(dashboardControllerProvider.notifier).refresh(),
      _loadTodayMood(),
    ]);
  }

  int? _todayMoodPercent() {
    final mood = _todayMood;
    if (mood == null) return null;
    return _extractMoodPercent(mood);
  }

  String _todayMoodSummary() {
    final percent = _todayMoodPercent();
    if (percent == null) return "还未记录";
    final option = _MoodOption.fromPercent(percent);
    return "${option.emoji} ${option.label}";
  }

  int _extractMoodPercent(EventDto mood) {
    final rawPercent = mood.data["score_percent"];
    if (rawPercent is num) return rawPercent.toInt().clamp(0, 100);
    final rawScore = mood.data["score"];
    if (rawScore is num) {
      final score = rawScore.toInt().clamp(1, 5);
      return (((score - 1) / 4) * 100).round();
    }
    final rawIntensity = mood.data["intensity"];
    if (rawIntensity is num) {
      return (rawIntensity.toDouble().clamp(0, 1) * 100).round();
    }
    return 50;
  }

  void _resetMoodDraftFromSaved() {
    final percent = _todayMood == null ? 50 : _extractMoodPercent(_todayMood!);
    setState(() {
      _moodDraftPercent = percent;
      _moodDraftDirty = false;
    });
    _moodPercentController.text = "$percent";
  }

  Future<void> _openMoodPercentDialog() async {
    _moodPercentController.text = "$_moodDraftPercent";
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("输入心情分数"),
          content: TextField(
            controller: _moodPercentController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: "0-100",
              suffixText: "分",
            ),
            onSubmitted: (_) {
              final parsed = int.tryParse(_moodPercentController.text.trim());
              Navigator.of(ctx).pop(parsed);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("取消"),
            ),
            FilledButton(
              onPressed: () {
                final parsed = int.tryParse(_moodPercentController.text.trim());
                Navigator.of(ctx).pop(parsed);
              },
              child: const Text("确定"),
            ),
          ],
        );
      },
    );
    if (value == null) return;
    _updateMoodDraftPercent(value);
  }

  void _onPickMoodOption(_MoodOption option) {
    _updateMoodDraftPercent(option.percent);
  }

  void _updateMoodDraftPercent(int value) {
    final next = value.clamp(0, 100);
    setState(() {
      _moodDraftPercent = next;
      _moodDraftDirty = true;
    });
    if (_moodPercentController.text != "$next") {
      _moodPercentController.value = TextEditingValue(
        text: "$next",
        selection: TextSelection.collapsed(offset: "$next".length),
      );
    }
  }

  Future<void> _loadTodayMood() async {
    setState(() => _moodLoading = true);
    try {
      final dio = await ApiClient().dio;
      final api = EventsApi(dio);
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1));
      final resp = await api.list(
        types: const ["mood"],
        dateFrom: toIsoWithOffset(start),
        dateTo: toIsoWithOffset(end),
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        _todayMood = resp.items.isNotEmpty ? resp.items.first : null;
        _moodLoading = false;
      });
      _resetMoodDraftFromSaved();
    } catch (_) {
      if (!mounted) return;
      setState(() => _moodLoading = false);
    }
  }

  Future<void> _saveMoodDraft() async {
    if (_moodSaving || !_moodDraftDirty) return;
    setState(() => _moodSaving = true);
    try {
      final percent = _moodDraftPercent.clamp(0, 100);
      final option = _MoodOption.fromPercent(percent);
      final score = _scoreFromPercent(percent);
      final dio = await ApiClient().dio;
      final resp = await dio.post(
        "/chat",
        data: {
          "action": "mood_quick",
          "payload": {
            "emoji": option.emoji,
            "score": score,
            "score_percent": percent,
            "mood": option.label,
            "happened_at": toIsoWithOffset(DateTime.now()),
          },
        },
      );
      final body = resp.data as Map<String, dynamic>;
      final eventMap = (body["event"] as Map?)?.cast<String, dynamic>();
      if (eventMap == null || !mounted) return;
      setState(() {
        _todayMood = EventDto.fromJson(eventMap);
        _moodDraftDirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("心情已保存")),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("保存失败，请稍后重试")),
      );
    } finally {
      if (mounted) {
        setState(() => _moodSaving = false);
      }
    }
  }

  int _scoreFromPercent(int percent) {
    if (percent < 20) return 1;
    if (percent < 40) return 2;
    if (percent < 60) return 3;
    if (percent < 80) return 4;
    return 5;
  }

  List<ExpenseTrendModel> _expenseTrendByWindow(List<ExpenseTrendModel> trend) {
    return trend.takeLast(_expenseWindowDays);
  }

  double _sumExpense(List<ExpenseTrendModel> trend) {
    return trend.fold(0.0, (sum, item) => sum + item.amount);
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
  const _TodayOverview({
    required this.data,
    required this.moodSummary,
  });

  final DashboardSummaryState data;
  final String moodSummary;

  @override
  Widget build(BuildContext context) {
    final taskText = "${data.todayCompletedTasks}/${data.todayTotalTasks}";
    final todayExpense = "¥${_todayExpenseAmount(data.expenseTrend).toStringAsFixed(2)}";
    final todayRecordText = data.todayRecordCount.toString();

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
                  value: moodSummary,
                  icon: Icons.mood,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetric(
                  title: "今日记录",
                  value: todayRecordText,
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
  double _todayExpenseAmount(List<ExpenseTrendModel> trend) {
    if (trend.isEmpty) return 0.0;
    final now = DateTime.now();
    final today = "${now.year.toString().padLeft(4, "0")}-"
        "${now.month.toString().padLeft(2, "0")}-"
        "${now.day.toString().padLeft(2, "0")}";
    for (final item in trend.reversed) {
      if (item.date == today) return item.amount;
    }
    return 0.0;
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

class _TodayMoodCard extends StatelessWidget {
  const _TodayMoodCard({
    required this.todayMood,
    required this.loading,
    required this.saving,
    required this.draftPercent,
    required this.draftDirty,
    required this.onPick,
    required this.onEditPercent,
    required this.onConfirm,
    required this.onReset,
  });

  final EventDto? todayMood;
  final bool loading;
  final bool saving;
  final int draftPercent;
  final bool draftDirty;
  final ValueChanged<_MoodOption> onPick;
  final VoidCallback onEditPercent;
  final VoidCallback onConfirm;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final selectedOption = _MoodOption.fromPercent(draftPercent);
    final savedPercent = todayMood == null ? null : _extractPercent(todayMood!);
    final savedOption = _MoodOption.fromPercent(savedPercent ?? 50);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "今日心情",
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            savedPercent == null
                ? "今天感觉怎么样？"
                : "已记录：${savedOption.emoji} ${savedOption.label}",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 10),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _MoodOption.options.map((option) {
                final selected = selectedOption.emoji == option.emoji;
                return GestureDetector(
                  onTap: saving ? null : () => onPick(option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accent.withValues(alpha: 0.10)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? AppColors.accent : AppColors.divider,
                      ),
                    ),
                    child: Text(
                      option.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  "当前匹配：${selectedOption.emoji} ${selectedOption.label}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
              TextButton(
                onPressed: (saving || loading) ? null : onEditPercent,
                child: const Text("输入分数"),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton(
                onPressed: (!draftDirty || saving || loading) ? null : onReset,
                child: const Text("重置"),
              ),
              const Spacer(),
              FilledButton(
                onPressed:
                    (!draftDirty || saving || loading) ? null : onConfirm,
                child: Text(saving
                    ? "保存中..."
                    : (savedPercent == null ? "确认保存" : "更新心情")),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static int _extractPercent(EventDto mood) {
    final rawPercent = mood.data["score_percent"];
    if (rawPercent is num) return rawPercent.toInt().clamp(0, 100);
    final rawScore = mood.data["score"];
    if (rawScore is num) {
      final score = rawScore.toInt().clamp(1, 5);
      return (((score - 1) / 4) * 100).round();
    }
    final rawIntensity = mood.data["intensity"];
    if (rawIntensity is num) {
      return (rawIntensity.toDouble().clamp(0, 1) * 100).round();
    }
    return 50;
  }
}

class _MoodOption {
  const _MoodOption(this.emoji, this.label, this.percent);

  final String emoji;
  final String label;
  final int percent;

  static const options = [
    _MoodOption("😞", "有点低落", 10),
    _MoodOption("😐", "一般", 30),
    _MoodOption("🙂", "还不错", 50),
    _MoodOption("😄", "状态很好", 75),
    _MoodOption("🤩", "今天超棒", 95),
  ];

  static _MoodOption fromPercent(int percent) {
    if (percent < 20) return options[0];
    if (percent < 40) return options[1];
    if (percent < 60) return options[2];
    if (percent < 80) return options[3];
    return options[4];
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

class _ExpenseWindowSwitch extends StatelessWidget {
  const _ExpenseWindowSwitch({
    required this.selectedDays,
    required this.onChanged,
  });

  final int selectedDays;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _WindowChip(
          label: "7天",
          selected: selectedDays == 7,
          onTap: () => onChanged(7),
        ),
        const SizedBox(width: 8),
        _WindowChip(
          label: "30天",
          selected: selectedDays == 30,
          onTap: () => onChanged(30),
        ),
      ],
    );
  }
}

class _WindowChip extends StatelessWidget {
  const _WindowChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.12)
              : AppColors.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.accent : AppColors.textSecondary,
              ),
        ),
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

List<_InsightItem> _buildSuggestions(
    BuildContext context, DashboardSummaryState data) {
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
  final avg = trend.fold(0.0, (p, e) => p + e.averageValence) / trend.length;
  return "平均 ${avg.toStringAsFixed(0)} 分";
}

String _buildMoodInsight(List<MoodTrendModel> trend) {
  if (trend.length < 3) return "近几天情绪平稳";
  final last = trend.last.averageValence;
  final prev = trend[trend.length - 2].averageValence;
  if (last - prev > 8) return "近两天情绪有所提升";
  if (prev - last > 8) return "近两天情绪略有下降";
  return "近几天整体较平稳";
}

extension _ListTakeLast<E> on List<E> {
  List<E> takeLast(int n) {
    if (length <= n) return [...this];
    return sublist(length - n);
  }
}
