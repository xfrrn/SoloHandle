class FinanceBalanceModel {
  FinanceBalanceModel({
    required this.current,
    required this.currency,
    required this.baseAmount,
    required this.baseAt,
    required this.isSet,
  });

  final double? current;
  final String currency;
  final double? baseAmount;
  final String? baseAt;
  final bool isSet;

  factory FinanceBalanceModel.fromJson(Map<String, dynamic> json) {
    return FinanceBalanceModel(
      current: (json['current'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'CNY',
      baseAmount: (json['base_amount'] as num?)?.toDouble(),
      baseAt: json['base_at'] as String?,
      isSet: json['is_set'] == true,
    );
  }
}

class FinanceMonthModel {
  FinanceMonthModel({
    required this.income,
    required this.expense,
    required this.net,
    required this.monthStart,
    required this.incomeCategories,
    required this.expenseCategories,
  });

  final double income;
  final double expense;
  final double net;
  final String monthStart;
  final List<FinanceCategoryBreakdownModel> incomeCategories;
  final List<FinanceCategoryBreakdownModel> expenseCategories;

  factory FinanceMonthModel.fromJson(Map<String, dynamic> json) {
    return FinanceMonthModel(
      income: (json['income'] as num?)?.toDouble() ?? 0,
      expense: (json['expense'] as num?)?.toDouble() ?? 0,
      net: (json['net'] as num?)?.toDouble() ?? 0,
      monthStart: json['month_start'] as String? ?? '',
      incomeCategories: ((json['income_categories'] as List?) ?? [])
          .map((e) =>
              FinanceCategoryBreakdownModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      expenseCategories: ((json['expense_categories'] as List?) ?? [])
          .map((e) =>
              FinanceCategoryBreakdownModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FinanceCategoryBreakdownModel {
  FinanceCategoryBreakdownModel({
    required this.category,
    required this.amount,
  });

  final String category;
  final double amount;

  factory FinanceCategoryBreakdownModel.fromJson(Map<String, dynamic> json) {
    return FinanceCategoryBreakdownModel(
      category: json['category'] as String? ?? 'other',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class FinanceEntryModel {
  FinanceEntryModel({
    required this.eventId,
    required this.type,
    required this.happenedAt,
    required this.createdAt,
    required this.amount,
    required this.currency,
    required this.category,
    required this.note,
  });

  final int eventId;
  final String type;
  final String happenedAt;
  final String createdAt;
  final double amount;
  final String currency;
  final String? category;
  final String? note;

  factory FinanceEntryModel.fromJson(Map<String, dynamic> json) {
    return FinanceEntryModel(
      eventId: json['event_id'] as int? ?? 0,
      type: json['type'] as String? ?? '',
      happenedAt: json['happened_at'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'CNY',
      category: json['category'] as String?,
      note: json['note'] as String?,
    );
  }
}

class FinanceSummaryState {
  FinanceSummaryState({
    required this.balance,
    required this.month,
    required this.recent,
  });

  final FinanceBalanceModel balance;
  final FinanceMonthModel month;
  final List<FinanceEntryModel> recent;

  factory FinanceSummaryState.fromJson(Map<String, dynamic> json) {
    final balanceMap = json['balance'] as Map<String, dynamic>? ?? {};
    final monthMap = json['month'] as Map<String, dynamic>? ?? {};
    final recentList = (json['recent'] as List?)
            ?.map((e) => FinanceEntryModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <FinanceEntryModel>[];
    return FinanceSummaryState(
      balance: FinanceBalanceModel.fromJson(balanceMap),
      month: FinanceMonthModel.fromJson(monthMap),
      recent: recentList,
    );
  }
}
