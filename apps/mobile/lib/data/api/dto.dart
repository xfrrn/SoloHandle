class ChatRequest {
  ChatRequest({
    this.text,
    this.confirmDraftIds,
    this.undoToken,
    this.requestId,
    this.action,
    this.draftId,
    this.patch,
    this.taskId,
    this.op,
    this.payload,
  });

  final String? text;
  final List<String>? confirmDraftIds;
  final String? undoToken;
  final String? requestId;
  final String? action;
  final String? draftId;
  final Map<String, dynamic>? patch;
  final int? taskId;
  final String? op;
  final Map<String, dynamic>? payload;

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (text != null && text!.trim().isNotEmpty) data["text"] = text!.trim();
    if (confirmDraftIds != null && confirmDraftIds!.isNotEmpty) {
      data["confirm_draft_ids"] = confirmDraftIds;
    }
    if (undoToken != null && undoToken!.trim().isNotEmpty) {
      data["undo_token"] = undoToken!.trim();
    }
    if (requestId != null && requestId!.trim().isNotEmpty) {
      data["request_id"] = requestId!.trim();
    }
    if (action != null && action!.trim().isNotEmpty) {
      data["action"] = action!.trim();
    }
    if (draftId != null && draftId!.trim().isNotEmpty) {
      data["draft_id"] = draftId!.trim();
    }
    if (patch != null && patch!.isNotEmpty) {
      data["patch"] = patch;
    }
    if (taskId != null) {
      data["task_id"] = taskId;
    }
    if (op != null && op!.trim().isNotEmpty) {
      data["op"] = op!.trim();
    }
    if (payload != null && payload!.isNotEmpty) {
      data["payload"] = payload;
    }
    return data;
  }
}

class DraftDto {
  DraftDto({
    required this.draftId,
    required this.toolName,
    required this.payload,
    required this.confidence,
    required this.status,
  });

  final String draftId;
  final String toolName;
  final Map<String, dynamic> payload;
  final double confidence;
  final String status;

  factory DraftDto.fromJson(Map<String, dynamic> json) {
    return DraftDto(
      draftId: json["draft_id"] as String? ?? "",
      toolName: json["tool_name"] as String? ?? "",
      payload: (json["payload"] as Map?)?.cast<String, dynamic>() ?? {},
      confidence: (json["confidence"] as num?)?.toDouble() ?? 0.0,
      status: json["status"] as String? ?? "",
    );
  }
}

class CardDto {
  CardDto({
    required this.cardId,
    required this.type,
    required this.status,
    required this.title,
    required this.subtitle,
    required this.data,
  });

  final String cardId;
  final String type;
  final String status;
  final String title;
  final String subtitle;
  final Map<String, dynamic> data;

  factory CardDto.fromJson(Map<String, dynamic> json) {
    return CardDto(
      cardId: json["card_id"] as String? ?? "",
      type: json["type"] as String? ?? "",
      status: json["status"] as String? ?? "",
      title: json["title"] as String? ?? "",
      subtitle: json["subtitle"] as String? ?? "",
      data: (json["data"] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }
}

class ChatResponseDto {
  ChatResponseDto({
    required this.needClarification,
    required this.clarifyQuestion,
    required this.replyToUser,
    required this.drafts,
    required this.cards,
    required this.undoToken,
    required this.committed,
    required this.undone,
  });

  final bool needClarification;
  final String? clarifyQuestion;
  final String? replyToUser;
  final List<DraftDto> drafts;
  final List<CardDto> cards;
  final String? undoToken;
  final List<dynamic> committed;
  final List<dynamic> undone;

  factory ChatResponseDto.fromJson(Map<String, dynamic> json) {
    final draftsJson = (json["drafts"] as List?) ?? [];
    final cardsJson = (json["cards"] as List?) ?? [];
    return ChatResponseDto(
      needClarification: json["need_clarification"] == true,
      clarifyQuestion: json["clarify_question"] as String?,
      replyToUser: json["reply_to_user"] as String?,
      drafts: draftsJson.map((e) => DraftDto.fromJson(e as Map<String, dynamic>)).toList(),
      cards: cardsJson.map((e) => CardDto.fromJson(e as Map<String, dynamic>)).toList(),
      undoToken: json["undo_token"] as String?,
      committed: (json["committed"] as List?) ?? [],
      undone: (json["undone"] as List?) ?? [],
    );
  }
}
