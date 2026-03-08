import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/time.dart';
import '../../shared/widgets/glass_card.dart';
import 'finance_controller.dart';
import 'finance_state.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  _RecentFilter _recentFilter = _RecentFilter.all;
  String? _selectedCategory;
  _BreakdownType? _selectedBreakdownType;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(financeControllerProvider);
    final notifier = ref.read(financeControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('收支汇总'),
        actions: [
          IconButton(
            tooltip: '设置余额',
            onPressed: summary.isLoading ? null : () => _showSetBalanceDialog(context),
            icon: const Icon(Icons.account_balance_wallet_outlined),
          ),
        ],
      ),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                const SizedBox(height: 12),
                Text('加载失败：$error', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: notifier.refresh, child: const Text('重试')),
              ],
            ),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: notifier.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _BalanceCard(
                balance: data.balance,
                month: data.month,
                onSetBalance: () => _showSetBalanceDialog(context),
              ),
              const SizedBox(height: 16),
              _AccountsSection(
                accounts: data.accounts,
                onCreateAccount: () => _showCreateAccountDialog(context),
                onCreateTransfer: data.accounts.items.length >= 2
                    ? () => _showCreateTransferDialog(context, data.accounts.items)
                    : null,
                onSetAccountBalance: (account) =>
                    _showSetAccountBalanceDialog(context, account),
              ),
              const SizedBox(height: 16),
              _MonthSummaryGrid(month: data.month, currency: data.balance.currency),
              const SizedBox(height: 16),
              _BreakdownSection(
                month: data.month,
                currency: data.balance.currency,
                selectedCategory: _selectedCategory,
                selectedBreakdownType: _selectedBreakdownType,
                onCategorySelected: (type, category) {
                  setState(() {
                    final sameSelection =
                        _selectedBreakdownType == type && _selectedCategory == category;
                    if (sameSelection) {
                      _selectedBreakdownType = null;
                      _selectedCategory = null;
                    } else {
                      _selectedBreakdownType = type;
                      _selectedCategory = category;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              _RecentSection(
                entries: _filterEntries(data.recent, _recentFilter),
                selectedFilter: _recentFilter,
                selectedCategory: _selectedCategory,
                selectedBreakdownType: _selectedBreakdownType,
                onFilterChanged: (value) => setState(() => _recentFilter = value),
                onClearCategory: () => setState(() {
                  _selectedCategory = null;
                  _selectedBreakdownType = null;
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<FinanceEntryModel> _filterEntries(
    List<FinanceEntryModel> entries,
    _RecentFilter filter,
  ) {
    List<FinanceEntryModel> filtered;
    switch (filter) {
      case _RecentFilter.income:
        filtered = entries.where((entry) => entry.type == 'income').toList();
        break;
      case _RecentFilter.expense:
        filtered = entries.where((entry) => entry.type == 'expense').toList();
        break;
      case _RecentFilter.all:
        filtered = entries;
        break;
    }
    if (_selectedCategory != null && _selectedBreakdownType != null) {
      final expectedType =
          _selectedBreakdownType == _BreakdownType.income ? 'income' : 'expense';
      filtered = filtered.where((entry) {
        return entry.type == expectedType &&
            (entry.category ?? '').trim() == _selectedCategory;
      }).toList();
    }
    return filtered;
  }

  Future<void> _showSetBalanceDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置当前余额'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '余额',
            hintText: '例如 1200.50',
            prefixText: '¥ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(controller.text.trim());
              if (amount == null) return;
              Navigator.of(context).pop(amount);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !context.mounted) return;
    try {
      await ref.read(financeControllerProvider.notifier).setBalance(result);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('余额已更新')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('余额更新失败')),
      );
    }
  }

  Future<void> _showCreateAccountDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final balanceController = TextEditingController(text: '0');
    var selectedKind = 'asset';
    var selectedSubtype = _subtypesForKind(selectedKind).first;
    final result = await showDialog<_AccountDraft>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('新增账户'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '账户名称'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedKind,
                  decoration: const InputDecoration(labelText: '账户类型'),
                  items: const [
                    DropdownMenuItem(value: 'asset', child: Text('资产账户')),
                    DropdownMenuItem(value: 'liability', child: Text('负债账户')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setModalState(() {
                      selectedKind = value;
                      selectedSubtype = _subtypesForKind(value).first;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedSubtype,
                  decoration: const InputDecoration(labelText: '账户子类'),
                  items: _subtypesForKind(selectedKind)
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_mapAccountSubtypeLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setModalState(() => selectedSubtype = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '初始余额/欠款',
                    hintText: '例如 2000 或 -3500',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final balance = double.tryParse(balanceController.text.trim());
                final name = nameController.text.trim();
                if (balance == null || name.isEmpty) return;
                Navigator.of(context).pop(
                  _AccountDraft(
                    name: name,
                    kind: selectedKind,
                    subtype: selectedSubtype,
                    balance: balance,
                  ),
                );
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    balanceController.dispose();
    if (result == null || !context.mounted) return;
    try {
      await ref.read(financeControllerProvider.notifier).createAccount(
            name: result.name,
            kind: result.kind,
            subtype: result.subtype,
            balanceBase: result.balance,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('账户已创建')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('创建账户失败')),
      );
    }
  }

  Future<void> _showSetAccountBalanceDialog(
    BuildContext context,
    FinanceAccountModel account,
  ) async {
    final controller = TextEditingController(
      text: account.currentBalance.toStringAsFixed(2),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('设置 ${account.name} 余额'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: '当前余额/欠款'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final balance = double.tryParse(controller.text.trim());
              if (balance == null) return;
              Navigator.of(context).pop(balance);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !context.mounted) return;
    try {
      await ref.read(financeControllerProvider.notifier).setAccountBalance(
            accountId: account.accountId,
            balanceBase: result,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('账户余额已更新')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('更新账户余额失败')),
      );
    }
  }

  Future<void> _showCreateTransferDialog(
    BuildContext context,
    List<FinanceAccountModel> accounts,
  ) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    var fromAccount = accounts.first;
    var toAccount = accounts.length > 1 ? accounts[1] : accounts.first;
    final result = await showDialog<_TransferDraft>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('账户转账'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: fromAccount.accountId,
                  decoration: const InputDecoration(labelText: '转出账户'),
                  items: accounts
                      .map(
                        (account) => DropdownMenuItem(
                          value: account.accountId,
                          child: Text(account.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setModalState(() {
                      fromAccount = accounts.firstWhere((item) => item.accountId == value);
                      if (fromAccount.accountId == toAccount.accountId && accounts.length > 1) {
                        toAccount = accounts.firstWhere(
                          (item) => item.accountId != value,
                        );
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: toAccount.accountId,
                  decoration: const InputDecoration(labelText: '转入账户'),
                  items: accounts
                      .where((account) => account.accountId != fromAccount.accountId)
                      .map(
                        (account) => DropdownMenuItem(
                          value: account.accountId,
                          child: Text(account.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setModalState(() {
                      toAccount = accounts.firstWhere((item) => item.accountId == value);
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '金额'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: '备注（可选）'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) return;
                Navigator.of(context).pop(
                  _TransferDraft(
                    amount: amount,
                    fromAccountId: fromAccount.accountId,
                    toAccountId: toAccount.accountId,
                    note: noteController.text.trim(),
                  ),
                );
              },
              child: const Text('转账'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
    noteController.dispose();
    if (result == null || !context.mounted) return;
    try {
      await ref.read(financeControllerProvider.notifier).createTransfer(
            amount: result.amount,
            fromAccountId: result.fromAccountId,
            toAccountId: result.toAccountId,
            note: result.note.isEmpty ? null : result.note,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('转账已记录')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('转账失败')),
      );
    }
  }
}

class _AccountDraft {
  const _AccountDraft({
    required this.name,
    required this.kind,
    required this.subtype,
    required this.balance,
  });

  final String name;
  final String kind;
  final String subtype;
  final double balance;
}

class _TransferDraft {
  const _TransferDraft({
    required this.amount,
    required this.fromAccountId,
    required this.toAccountId,
    required this.note,
  });

  final double amount;
  final int fromAccountId;
  final int toAccountId;
  final String note;
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.month,
    required this.onSetBalance,
  });

  final FinanceBalanceModel balance;
  final FinanceMonthModel month;
  final VoidCallback onSetBalance;

  @override
  Widget build(BuildContext context) {
    final current = balance.current;
    final hasBalance = balance.isSet && current != null;
    final netPositive = month.net >= 0;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.accent,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onSetBalance,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(hasBalance ? '校准余额' : '设置余额'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '当前余额',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            hasBalance ? _formatAmount(current, balance.currency) : '未设置',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            hasBalance
                ? '本月净额 ${netPositive ? '+' : ''}${_formatAmount(month.net, balance.currency)}'
                : '先设置一次当前余额，后续会按收入减支出自动更新',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _MonthSummaryGrid extends StatelessWidget {
  const _MonthSummaryGrid({
    required this.month,
    required this.currency,
  });

  final FinanceMonthModel month;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '本月概览',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _MetricCard(
              title: '本月收入',
              value: _formatAmount(month.income, currency),
              color: AppColors.success,
              icon: Icons.south_west_rounded,
            ),
            _MetricCard(
              title: '本月支出',
              value: _formatAmount(month.expense, currency),
              color: AppColors.warning,
              icon: Icons.north_east_rounded,
            ),
            _MetricCard(
              title: '本月净额',
              value: _formatSignedAmount(month.net, currency),
              color: month.net >= 0 ? AppColors.success : AppColors.danger,
              icon: Icons.equalizer_rounded,
            ),
            _MetricCard(
              title: '统计起点',
              value: month.monthStart.isEmpty ? '—' : month.monthStart,
              color: AppColors.accent,
              icon: Icons.calendar_month_outlined,
            ),
          ],
        ),
      ],
    );
  }
}

class _AccountsSection extends StatelessWidget {
  const _AccountsSection({
    required this.accounts,
    required this.onCreateAccount,
    required this.onCreateTransfer,
    required this.onSetAccountBalance,
  });

  final FinanceAccountsSummaryModel accounts;
  final VoidCallback onCreateAccount;
  final VoidCallback? onCreateTransfer;
  final ValueChanged<FinanceAccountModel> onSetAccountBalance;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '账户总览',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onCreateAccount,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('新增账户'),
            ),
            if (onCreateTransfer != null)
              TextButton.icon(
                onPressed: onCreateTransfer,
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text('转账'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.08,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _MetricCard(
              title: '总资产',
              value: _formatAmount(accounts.totalAssets, 'CNY'),
              color: AppColors.success,
              icon: Icons.account_balance_outlined,
            ),
            _MetricCard(
              title: '总负债',
              value: _formatAmount(accounts.totalLiabilities, 'CNY'),
              color: AppColors.danger,
              icon: Icons.credit_card_outlined,
            ),
            _MetricCard(
              title: '净资产',
              value: _formatSignedAmount(accounts.netAssets, 'CNY'),
              color: accounts.netAssets >= 0 ? AppColors.accent : AppColors.danger,
              icon: Icons.stacked_line_chart,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (accounts.items.isEmpty)
          const GlassCard(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: Text('还没有账户，先把银行卡、支付宝、花呗这些加进来')),
            ),
          )
        else
          ...accounts.items.map(
            (account) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AccountTile(
                account: account,
                onTap: () => onSetAccountBalance(account),
              ),
            ),
          ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.onTap,
  });

  final FinanceAccountModel account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isAsset = account.kind == 'asset';
    final color = isAsset ? AppColors.success : AppColors.danger;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: GlassCard(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isAsset ? Icons.account_balance_wallet_outlined : Icons.credit_card_outlined,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${isAsset ? '资产' : '负债'} · ${_mapAccountSubtypeLabel(account.subtype)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatSignedAmount(account.currentBalance, account.currency),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '点按校准',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const Spacer(),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 6),
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

class _BreakdownSection extends StatelessWidget {
  const _BreakdownSection({
    required this.month,
    required this.currency,
    required this.selectedCategory,
    required this.selectedBreakdownType,
    required this.onCategorySelected,
  });

  final FinanceMonthModel month;
  final String currency;
  final String? selectedCategory;
  final _BreakdownType? selectedBreakdownType;
  final void Function(_BreakdownType type, String category) onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '分类占比',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        _BreakdownCard(
          title: '收入分类',
          color: AppColors.success,
          currency: currency,
          items: month.incomeCategories,
          emptyText: '本月还没有收入记录',
          selected: selectedBreakdownType == _BreakdownType.income
              ? selectedCategory
              : null,
          onCategoryTap: (category) =>
              onCategorySelected(_BreakdownType.income, category),
        ),
        const SizedBox(height: 12),
        _BreakdownCard(
          title: '支出分类',
          color: AppColors.warning,
          currency: currency,
          items: month.expenseCategories,
          emptyText: '本月还没有支出记录',
          selected: selectedBreakdownType == _BreakdownType.expense
              ? selectedCategory
              : null,
          onCategoryTap: (category) =>
              onCategorySelected(_BreakdownType.expense, category),
        ),
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.title,
    required this.color,
    required this.currency,
    required this.items,
    required this.emptyText,
    required this.selected,
    required this.onCategoryTap,
  });

  final String title;
  final Color color;
  final String currency;
  final List<FinanceCategoryBreakdownModel> items;
  final String emptyText;
  final String? selected;
  final ValueChanged<String> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (sum, item) => sum + item.amount);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              emptyText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            )
          else
            ...items.map((item) {
              final ratio = total <= 0 ? 0.0 : item.amount / total;
              final isSelected = selected == item.category;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onCategoryTap(item.category),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? color.withValues(alpha: 0.35)
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _mapCategoryLabel(item.category),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            Text(
                              '${(ratio * 100).toStringAsFixed(0)}%',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _formatAmount(item.amount, currency),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 8,
                            color: color,
                            backgroundColor: color.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _RecentSection extends StatelessWidget {
  const _RecentSection({
    required this.entries,
    required this.selectedFilter,
    required this.selectedCategory,
    required this.selectedBreakdownType,
    required this.onFilterChanged,
    required this.onClearCategory,
  });

  final List<FinanceEntryModel> entries;
  final _RecentFilter selectedFilter;
  final String? selectedCategory;
  final _BreakdownType? selectedBreakdownType;
  final ValueChanged<_RecentFilter> onFilterChanged;
  final VoidCallback onClearCategory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '最近流水',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (selectedCategory != null && selectedBreakdownType != null)
                  InputChip(
                    label: Text(
                      '${selectedBreakdownType == _BreakdownType.income ? '收入' : '支出'} · ${_mapCategoryLabel(selectedCategory!)}',
                    ),
                    onDeleted: onClearCategory,
                  ),
                for (final filter in _RecentFilter.values)
                  ChoiceChip(
                    label: Text(filter.label),
                    selected: filter == selectedFilter,
                    onSelected: (_) => onFilterChanged(filter),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  selectedCategory == null ? '没有符合筛选条件的流水' : '当前分类下没有符合筛选条件的流水',
                ),
              ),
            ),
          )
        else
          ..._groupEntries(entries).entries.map(
            (group) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _RecentGroup(
                label: group.key,
                entries: group.value,
              ),
            ),
          ),
      ],
    );
  }
}

class _RecentGroup extends StatelessWidget {
  const _RecentGroup({
    required this.label,
    required this.entries,
  });

  final String label;
  final List<FinanceEntryModel> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        ...entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _EntryTile(entry: entry),
          ),
        ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final FinanceEntryModel entry;

  @override
  Widget build(BuildContext context) {
    final isIncome = entry.type == 'income';
    final isTransfer = entry.type == 'transfer';
    final color = isTransfer
        ? AppColors.accent
        : (isIncome ? AppColors.success : AppColors.warning);
    final signedAmount = isTransfer
        ? _formatAmount(entry.amount, entry.currency)
        : (isIncome
            ? _formatSignedAmount(entry.amount, entry.currency)
            : _formatSignedAmount(-entry.amount, entry.currency));
    final note = (entry.note ?? '').trim();
    final category = (entry.category ?? '').trim();
    final subtitleParts = <String>[
      if (isTransfer &&
          (entry.fromAccountName ?? '').isNotEmpty &&
          (entry.toAccountName ?? '').isNotEmpty)
        '${entry.fromAccountName} -> ${entry.toAccountName}',
      if (!isTransfer && category.isNotEmpty) _mapCategoryLabel(category),
      if (entry.happenedAt.isNotEmpty) formatIsoToLocal(entry.happenedAt),
    ];
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => context.go('/timeline?eventId=${entry.eventId}'),
      child: GlassCard(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isTransfer
                    ? Icons.swap_horiz
                    : (isIncome ? Icons.south_west_rounded : Icons.north_east_rounded),
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.isNotEmpty
                        ? note
                        : (isTransfer
                            ? '转账记录'
                            : (isIncome ? '收入记录' : '支出记录')),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitleParts.join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              signedAmount,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RecentFilter {
  all('全部'),
  income('收入'),
  expense('支出');

  const _RecentFilter(this.label);
  final String label;
}

enum _BreakdownType {
  income,
  expense,
}

Map<String, List<FinanceEntryModel>> _groupEntries(List<FinanceEntryModel> entries) {
  final grouped = <String, List<FinanceEntryModel>>{};
  for (final entry in entries) {
    final label = _groupLabel(entry.happenedAt);
    grouped.putIfAbsent(label, () => <FinanceEntryModel>[]).add(entry);
  }
  return grouped;
}

String _groupLabel(String happenedAt) {
  final dt = parseIsoToLocal(happenedAt);
  if (dt == null) return '更早';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(dt.year, dt.month, dt.day);
  final diff = date.difference(today).inDays;
  if (diff == 0) return '今天';
  if (diff == -1) return '昨天';
  return '${dt.month}月${dt.day}日';
}

String _formatAmount(double value, String currency) {
  final symbol = currency == 'CNY' ? '¥' : '$currency ';
  return '$symbol${value.toStringAsFixed(2)}';
}

String _formatSignedAmount(double value, String currency) {
  final sign = value >= 0 ? '+' : '-';
  return '$sign${_formatAmount(value.abs(), currency)}';
}

String _mapCategoryLabel(String value) {
  switch (value) {
    case 'salary':
      return '工资';
    case 'bonus':
      return '奖金';
    case 'freelance':
      return '副业';
    case 'refund':
      return '退款';
    case 'gift':
      return '礼金';
    case 'investment':
      return '投资';
    case 'food':
      return '餐饮';
    case 'transport':
      return '交通';
    case 'shopping':
      return '购物';
    case 'entertainment':
      return '娱乐';
    case 'housing':
      return '住房';
    case 'bills':
      return '账单';
    case 'medical':
      return '医疗';
    case 'education':
      return '教育';
    case 'personal_care':
      return '个人护理';
    case 'other':
      return '其他';
    default:
      return value;
  }
}

List<String> _subtypesForKind(String kind) {
  if (kind == 'liability') {
    return const ['huabei', 'credit_card', 'jd_baitiao', 'loan', 'other_liability'];
  }
  return const ['bank', 'wechat', 'alipay', 'cash', 'investment', 'other_asset'];
}

String _mapAccountSubtypeLabel(String value) {
  switch (value) {
    case 'bank':
      return '银行卡';
    case 'wechat':
      return '微信零钱';
    case 'alipay':
      return '支付宝';
    case 'cash':
      return '现金';
    case 'investment':
      return '投资账户';
    case 'huabei':
      return '花呗';
    case 'credit_card':
      return '信用卡';
    case 'jd_baitiao':
      return '白条';
    case 'loan':
      return '借款';
    case 'other_asset':
      return '其他资产';
    case 'other_liability':
      return '其他负债';
    default:
      return value;
  }
}
