import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repository/dashboard_repository.dart';
import 'dashboard_state.dart';

class DashboardController extends AsyncNotifier<DashboardSummaryState> {
  @override
  Future<DashboardSummaryState> build() async {
    return _fetchSummary();
  }

  Future<DashboardSummaryState> _fetchSummary() async {
    final repo = ref.read(dashboardRepositoryProvider);
    final data = await repo.getSummary();
    return DashboardSummaryState.fromJson(data);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchSummary());
  }
}

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardSummaryState>(
  () => DashboardController(),
);
