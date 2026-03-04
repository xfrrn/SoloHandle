import "dart:math";

import "package:dio/dio.dart";

import "../storage/local_store.dart";

/// Shared Dio factory with retry interceptor and base configuration.
class ApiClient {
  ApiClient({LocalStore? store}) : _store = store ?? LocalStore();

  final LocalStore _store;
  Dio? _cachedDio;

  Future<Dio> get dio async {
    if (_cachedDio != null) return _cachedDio!;
    final baseUrl = await _store.getBaseUrl() ?? "http://127.0.0.1:8000";
    final token = await _store.getToken();

    _cachedDio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          "Content-Type": "application/json",
          if (token != null && token.isNotEmpty)
            "Authorization": "Bearer $token",
        },
      ),
    );
    _cachedDio!.interceptors.add(RetryInterceptor(_cachedDio!));
    return _cachedDio!;
  }

  /// Force re-create the Dio instance on next access (e.g. after settings change).
  void invalidate() => _cachedDio = null;
}

/// Interceptor that automatically retries requests on network errors
/// with exponential backoff (up to [maxRetries] times).
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {this.maxRetries = 3});

  final Dio _dio;
  final int maxRetries;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err)) {
      final retries = (err.requestOptions.extra["_retryCount"] as int?) ?? 0;
      if (retries < maxRetries) {
        final delay = Duration(milliseconds: 500 * pow(2, retries).toInt());
        await Future.delayed(delay);
        err.requestOptions.extra["_retryCount"] = retries + 1;
        try {
          final response = await _dio.fetch(err.requestOptions);
          return handler.resolve(response);
        } on DioException catch (e) {
          return handler.next(e);
        }
      }
    }
    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError;
  }
}
