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

  Future<Map<String, dynamic>> createAccount({
    required String name,
    required String kind,
    required String subtype,
    required double balanceBase,
    String currency = 'CNY',
  }) async {
    final dio = await _apiClient.dio;
    final response = await dio.post(
      '/api/finance/accounts',
      data: {
        'name': name,
        'kind': kind,
        'subtype': subtype,
        'currency': currency,
        'balance_base': balanceBase,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setAccountBalance({
    required int accountId,
    required double balanceBase,
  }) async {
    final dio = await _apiClient.dio;
    final response = await dio.post(
      '/api/finance/accounts/$accountId/balance',
      data: {
        'balance_base': balanceBase,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createTransfer({
    required double amount,
    required int fromAccountId,
    required int toAccountId,
    String currency = 'CNY',
    String? note,
  }) async {
    final dio = await _apiClient.dio;
    final response = await dio.post(
      '/api/finance/transfer',
      data: {
        'amount': amount,
        'from_account_id': fromAccountId,
        'to_account_id': toAccountId,
        'currency': currency,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
