import 'api_client.dart';

class FinanceApi {
  FinanceApi(this._apiClient);
  final ApiClient _apiClient;

  Future<Map<String, dynamic>> getSummary() async {
    final dio = await _apiClient.dio;
    final response = await dio.get('/api/finance/summary');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setBalance({
    required double amount,
    String currency = 'CNY',
  }) async {
    final dio = await _apiClient.dio;
    final response = await dio.post(
      '/api/finance/balance',
      data: {
        'amount': amount,
        'currency': currency,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
