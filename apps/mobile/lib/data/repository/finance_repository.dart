import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/finance_api.dart';

final financeApiProvider = Provider<FinanceApi>((ref) {
  return FinanceApi(ApiClient());
});

class FinanceRepository {
  FinanceRepository(this._api);

  final FinanceApi _api;

  Future<Map<String, dynamic>> getSummary() {
    return _api.getSummary();
  }

  Future<Map<String, dynamic>> setBalance({
    required double amount,
    String currency = 'CNY',
  }) {
    return _api.setBalance(amount: amount, currency: currency);
  }
}

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(financeApiProvider));
});
