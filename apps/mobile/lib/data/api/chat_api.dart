import "package:dio/dio.dart";

import "dto.dart";

class ChatApi {
  ChatApi(this._dio);

  final Dio _dio;

  Future<ChatResponseDto> send(ChatRequest request) async {
    final resp = await _dio.post("/chat", data: request.toJson());
    return ChatResponseDto.fromJson(resp.data as Map<String, dynamic>);
  }
}
