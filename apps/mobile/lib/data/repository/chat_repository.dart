import "package:dio/dio.dart";

import "../api/api_client.dart";
import "../api/chat_api.dart";
import "../api/dto.dart";
import "../storage/local_store.dart";

class ChatRepository {
  ChatRepository({required this.store});

  final LocalStore store;
  final ApiClient _apiClient = ApiClient();

  Future<ChatResponseDto> send(ChatRequest request) async {
    try {
      final dio = await _apiClient.dio;
      final api = ChatApi(dio);
      return await api.send(request);
    } catch (exc) {
      if (exc is DioException) {
        final detail = exc.response?.data;
        final message = detail != null ? "${exc.message} | $detail" : exc.message;
        throw ChatRepositoryException(message ?? exc.toString());
      }
      throw ChatRepositoryException(exc.toString());
    }
  }
}

class ChatRepositoryException implements Exception {
  ChatRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

