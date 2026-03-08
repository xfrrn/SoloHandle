import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/finance_repository.dart';
import 'finance_state.dart';

class FinanceController extends AsyncNotifier<FinanceSummaryState> {
  @override
  Future<FinanceSummaryState> build() async {
    return _fetchSummary();
  }

  Future<FinanceSummaryState> _fetchSummary() async {
    final repo = ref.read(financeRepositoryProvider);
    final data = await repo.getSummary();
    return FinanceSummaryState.fromJson(data);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchSummary);
  }

  Future<void> setBalance(double amount) async {
    final repo = ref.read(financeRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final data = await repo.setBalance(amount: amount);
      return FinanceSummaryState.fromJson(data);
    });
  }

  Future<void> createAccount({
    required String name,
    required String kind,
    required String subtype,
    required double balanceBase,
  }) async {
    final repo = ref.read(financeRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repo.createAccount(
        name: name,
        kind: kind,
        subtype: subtype,
        balanceBase: balanceBase,
      );
      final data = await repo.getSummary();
      return FinanceSummaryState.fromJson(data);
    });
  }

  Future<void> setAccountBalance({
    required int accountId,
    required double balanceBase,
  }) async {
    final repo = ref.read(financeRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repo.setAccountBalance(accountId: accountId, balanceBase: balanceBase);
      final data = await repo.getSummary();
      return FinanceSummaryState.fromJson(data);
    });
  }

  Future<void> createTransfer({
    required double amount,
    required int fromAccountId,
    required int toAccountId,
    String? note,
  }) async {
    final repo = ref.read(financeRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repo.createTransfer(
        amount: amount,
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        note: note,
      );
      final data = await repo.getSummary();
      return FinanceSummaryState.fromJson(data);
    });
  }
}

final financeControllerProvider =
    AsyncNotifierProvider<FinanceController, FinanceSummaryState>(
  () => FinanceController(),
);
