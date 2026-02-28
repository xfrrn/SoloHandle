class Draft {
  final String draftId;
  final String toolName;
  final Map<String, dynamic> payload;
  final double confidence;
  final String status;

  Draft({
    required this.draftId,
    required this.toolName,
    required this.payload,
    required this.confidence,
    required this.status,
  });

  factory Draft.fromJson(Map<String, dynamic> json) {
    return Draft(
      draftId: json["draft_id"] as String? ?? "",
      toolName: json["tool_name"] as String? ?? "",
      payload: (json["payload"] as Map?)?.cast<String, dynamic>() ?? {},
      confidence: (json["confidence"] as num?)?.toDouble() ?? 0.0,
      status: json["status"] as String? ?? "",
    );
  }
}

class CardData {
  final String cardId;
  final String type;
  final String status;
  final String title;
  final String subtitle;
  final Map<String, dynamic> data;

  CardData({
    required this.cardId,
    required this.type,
    required this.status,
    required this.title,
    required this.subtitle,
    required this.data,
  });

  factory CardData.fromJson(Map<String, dynamic> json) {
    return CardData(
      cardId: json["card_id"] as String? ?? "",
      type: json["type"] as String? ?? "",
      status: json["status"] as String? ?? "",
      title: json["title"] as String? ?? "",
      subtitle: json["subtitle"] as String? ?? "",
      data: (json["data"] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }
}

class ChatResponse {
  final bool needClarification;
  final String? clarifyQuestion;
  final String? replyToUser;
  final String? requestId;
  final List<Draft> drafts;
  final List<CardData> cards;
  final String? undoToken;
  final List<dynamic> committed;
  final List<dynamic> undone;

  ChatResponse({
    required this.needClarification,
    required this.clarifyQuestion,
    required this.replyToUser,
    required this.requestId,
    required this.drafts,
    required this.cards,
    required this.undoToken,
    required this.committed,
    required this.undone,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    final draftsJson = (json["drafts"] as List?) ?? [];
    final cardsJson = (json["cards"] as List?) ?? [];
    return ChatResponse(
      needClarification: json["need_clarification"] == true,
      clarifyQuestion: json["clarify_question"] as String?,
      replyToUser: json["reply_to_user"] as String?,
      requestId: json["request_id"] as String?,
      drafts: draftsJson.map((e) => Draft.fromJson(e as Map<String, dynamic>)).toList(),
      cards: cardsJson.map((e) => CardData.fromJson(e as Map<String, dynamic>)).toList(),
      undoToken: json["undo_token"] as String?,
      committed: (json["committed"] as List?) ?? [],
      undone: (json["undone"] as List?) ?? [],
    );
  }
}
