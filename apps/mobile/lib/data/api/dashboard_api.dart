import 'api_client.dart';

class DashboardApi {
  DashboardApi(this._apiClient);
  final ApiClient _apiClient;

  Future<Map<String, dynamic>> getSummary() async {
    final dio = await _apiClient.dio;
    final response = await dio.get('/api/dashboard/summary');
    return response.data as Map<String, dynamic>;
  }
}
