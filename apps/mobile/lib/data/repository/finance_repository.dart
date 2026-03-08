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

  Future<Map<String, dynamic>> createAccount({
    required String name,
    required String kind,
    required String subtype,
    required double balanceBase,
    String currency = 'CNY',
  }) {
    return _api.createAccount(
      name: name,
      kind: kind,
      subtype: subtype,
      balanceBase: balanceBase,
      currency: currency,
    );
  }

  Future<Map<String, dynamic>> setAccountBalance({
    required int accountId,
    required double balanceBase,
  }) {
    return _api.setAccountBalance(
      accountId: accountId,
      balanceBase: balanceBase,
    );
  }

  Future<Map<String, dynamic>> createTransfer({
    required double amount,
    required int fromAccountId,
    required int toAccountId,
    String currency = 'CNY',
    String? note,
  }) {
    return _api.createTransfer(
      amount: amount,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      currency: currency,
      note: note,
    );
  }
}

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(financeApiProvider));
});
