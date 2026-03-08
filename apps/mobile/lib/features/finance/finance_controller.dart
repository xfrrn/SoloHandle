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
}

final financeControllerProvider =
    AsyncNotifierProvider<FinanceController, FinanceSummaryState>(
  () => FinanceController(),
);
