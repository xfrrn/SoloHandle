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
    required this.accountId,
    required this.fromAccountId,
    required this.toAccountId,
    required this.fromAccountName,
    required this.toAccountName,
  });

  final int eventId;
  final String type;
  final String happenedAt;
  final String createdAt;
  final double amount;
  final String currency;
  final String? category;
  final String? note;
  final int? accountId;
  final int? fromAccountId;
  final int? toAccountId;
  final String? fromAccountName;
  final String? toAccountName;

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
      accountId: json['account_id'] as int?,
      fromAccountId: json['from_account_id'] as int?,
      toAccountId: json['to_account_id'] as int?,
      fromAccountName: json['from_account_name'] as String?,
      toAccountName: json['to_account_name'] as String?,
    );
  }
}

class FinanceAccountModel {
  FinanceAccountModel({
    required this.accountId,
    required this.name,
    required this.kind,
    required this.subtype,
    required this.currency,
    required this.baseBalance,
    required this.baseAt,
    required this.currentBalance,
  });

  final int accountId;
  final String name;
  final String kind;
  final String subtype;
  final String currency;
  final double baseBalance;
  final String? baseAt;
  final double currentBalance;

  factory FinanceAccountModel.fromJson(Map<String, dynamic> json) {
    return FinanceAccountModel(
      accountId: json['account_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      kind: json['kind'] as String? ?? 'asset',
      subtype: json['subtype'] as String? ?? '',
      currency: json['currency'] as String? ?? 'CNY',
      baseBalance: (json['base_balance'] as num?)?.toDouble() ?? 0,
      baseAt: json['base_at'] as String?,
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0,
    );
  }
}

class FinanceAccountsSummaryModel {
  FinanceAccountsSummaryModel({
    required this.items,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netAssets,
  });

  final List<FinanceAccountModel> items;
  final double totalAssets;
  final double totalLiabilities;
  final double netAssets;

  factory FinanceAccountsSummaryModel.fromJson(Map<String, dynamic> json) {
    return FinanceAccountsSummaryModel(
      items: ((json['items'] as List?) ?? [])
          .map((e) => FinanceAccountModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalAssets: (json['total_assets'] as num?)?.toDouble() ?? 0,
      totalLiabilities: (json['total_liabilities'] as num?)?.toDouble() ?? 0,
      netAssets: (json['net_assets'] as num?)?.toDouble() ?? 0,
    );
  }
}

class FinanceSummaryState {
  FinanceSummaryState({
    required this.balance,
    required this.month,
    required this.accounts,
    required this.recent,
  });

  final FinanceBalanceModel balance;
  final FinanceMonthModel month;
  final FinanceAccountsSummaryModel accounts;
  final List<FinanceEntryModel> recent;

  factory FinanceSummaryState.fromJson(Map<String, dynamic> json) {
    final balanceMap = json['balance'] as Map<String, dynamic>? ?? {};
    final monthMap = json['month'] as Map<String, dynamic>? ?? {};
    final accountsMap = json['accounts'] as Map<String, dynamic>? ?? {};
    final recentList = (json['recent'] as List?)
            ?.map((e) => FinanceEntryModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <FinanceEntryModel>[];
    return FinanceSummaryState(
      balance: FinanceBalanceModel.fromJson(balanceMap),
      month: FinanceMonthModel.fromJson(monthMap),
      accounts: FinanceAccountsSummaryModel.fromJson(accountsMap),
      recent: recentList,
    );
  }
}
