class ExpenseTrendModel {
  ExpenseTrendModel({required this.date, required this.amount});
  final String date;
  final double amount;

  factory ExpenseTrendModel.fromJson(Map<String, dynamic> json) {
    return ExpenseTrendModel(
      date: json['date'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MoodTrendModel {
  MoodTrendModel({required this.date, required this.averageValence});
  final String date;
  final double averageValence;

  factory MoodTrendModel.fromJson(Map<String, dynamic> json) {
    return MoodTrendModel(
      date: json['date'] as String? ?? '',
      averageValence: (json['average_valence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TaskStreakModel {
  TaskStreakModel({required this.label, required this.days, required this.progress});
  final String label;
  final int days;
  final double progress;

  factory TaskStreakModel.fromJson(Map<String, dynamic> json) {
    return TaskStreakModel(
      label: json['label'] as String? ?? '',
      days: json['days'] as int? ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DashboardSummaryState {
  DashboardSummaryState({
    required this.totalExpense30d,
    required this.expenseTrend,
    required this.moodTrend,
    required this.todayCompletedTasks,
    required this.todayTotalTasks,
    required this.taskStreaks,
  });

  final double totalExpense30d;
  final List<ExpenseTrendModel> expenseTrend;
  final List<MoodTrendModel> moodTrend;
  final int todayCompletedTasks;
  final int todayTotalTasks;
  final List<TaskStreakModel> taskStreaks;

  factory DashboardSummaryState.fromJson(Map<String, dynamic> json) {
    final financeMap = json['finance'] as Map<String, dynamic>? ?? {};
    final totalExpense = (financeMap['total_expense_30d'] as num?)?.toDouble() ?? 0.0;
    final exList = (financeMap['trend'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final moodMap = json['mood'] as Map<String, dynamic>? ?? {};
    final mdList = (moodMap['trend'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final taskMap = json['tasks'] as Map<String, dynamic>? ?? {};
    final completed = taskMap['today_completed'] as int? ?? 0;
    final total = taskMap['today_total'] as int? ?? 0;
    final stList = (taskMap['streaks'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return DashboardSummaryState(
      totalExpense30d: totalExpense,
      expenseTrend: exList.map(ExpenseTrendModel.fromJson).toList(),
      moodTrend: mdList.map(MoodTrendModel.fromJson).toList(),
      todayCompletedTasks: completed,
      todayTotalTasks: total,
      taskStreaks: stList.map(TaskStreakModel.fromJson).toList(),
    );
  }
}
