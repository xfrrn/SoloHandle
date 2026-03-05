import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/dashboard_api.dart';

final dashboardApiProvider = Provider<DashboardApi>((ref) {
  // In a real app we might want to inject ApiClient via Riverpod.
  // Assuming a static/singleton-like ApiClient for simplicity based on the pattern
  return DashboardApi(ApiClient());
});

class DashboardRepository {
  DashboardRepository(this._api);
  final DashboardApi _api;

  Future<Map<String, dynamic>> getSummary() {
    return _api.getSummary();
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(dashboardApiProvider));
});
