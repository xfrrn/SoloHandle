import "package:dio/dio.dart";

import "../api/chat_api.dart";
import "../api/dto.dart";
import "../storage/local_store.dart";

class ChatRepository {
  ChatRepository({required this.store});

  final LocalStore store;

  Future<ChatResponseDto> send(ChatRequest request) async {
    final baseUrl = await store.getBaseUrl() ?? "http://127.0.0.1:8000";
    final token = await store.getToken();

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          "Content-Type": "application/json",
          if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
        },
      ),
    );

    final api = ChatApi(dio);
    try {
      return await api.send(request);
    } on DioException catch (exc) {
      final message = exc.response?.data?.toString() ?? exc.message ?? "request failed";
      throw ChatRepositoryException(message);
    }
  }
}

class ChatRepositoryException implements Exception {
  ChatRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
