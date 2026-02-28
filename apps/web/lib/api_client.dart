import "dart:convert";

import "package:http/http.dart" as http;

import "models.dart";

class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;

  Future<ChatResponse> chat({
    String? text,
    List<String>? confirmDraftIds,
    String? undoToken,
  }) async {
    final payload = <String, dynamic>{};
    if (text != null && text.trim().isNotEmpty) {
      payload["text"] = text.trim();
    }
    if (confirmDraftIds != null && confirmDraftIds.isNotEmpty) {
      payload["confirm_draft_ids"] = confirmDraftIds;
    }
    if (undoToken != null && undoToken.trim().isNotEmpty) {
      payload["undo_token"] = undoToken.trim();
    }

    final url = Uri.parse("$baseUrl/chat");
    final resp = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (resp.statusCode >= 400) {
      throw ApiException("HTTP ${resp.statusCode}", resp.body);
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return ChatResponse.fromJson(data);
  }
}

class ApiException implements Exception {
  ApiException(this.message, this.body);

  final String message;
  final String body;

  @override
  String toString() => "$message: $body";
}
