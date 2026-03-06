import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../data/api/dto.dart";
import "../../data/repository/chat_repository.dart";
import "../../data/storage/local_store.dart";
import "../timeline/timeline_controller.dart";

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(store: LocalStore());
});

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return ChatController(repo, ref);
});

class ChatState {
  ChatState({
    required this.messages,
    required this.drafts,
    required this.cards,
    required this.loading,
    required this.status,
    required this.undoToken,
    required this.clarifyQuestion,
    this.lastFailedRequest,
  });

  final List<ChatMessage> messages;
  final List<DraftDto> drafts;
  final List<CardDto> cards;
  final bool loading;
  final String? status;
  final String? undoToken;
  final String? clarifyQuestion;
  final ChatRequest? lastFailedRequest;

  bool get hasError => status != null && status!.contains("失败");

  ChatState copyWith({
    List<ChatMessage>? messages,
    List<DraftDto>? drafts,
    List<CardDto>? cards,
    bool? loading,
    String? status,
    String? undoToken,
    String? clarifyQuestion,
    ChatRequest? lastFailedRequest,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      drafts: drafts ?? this.drafts,
      cards: cards ?? this.cards,
      loading: loading ?? this.loading,
      status: status ?? this.status,
      undoToken: undoToken ?? this.undoToken,
      clarifyQuestion: clarifyQuestion ?? this.clarifyQuestion,
      lastFailedRequest: lastFailedRequest,
    );
  }

  factory ChatState.initial() {
    return ChatState(
      messages: [],
      drafts: [],
      cards: [],
      loading: false,
      status: null,
      undoToken: null,
      clarifyQuestion: null,
    );
  }
}

class ChatMessage {
  ChatMessage({required this.role, this.text, this.imageBytes, this.audioBytes});

  final MessageRole role;
  final String? text;
  final String? imageBytes;
  final String? audioBytes;
}

enum MessageRole { user, assistant }

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._repo, this._ref) : super(ChatState.initial());

  final ChatRepository _repo;
  final Ref _ref;

  Future<void> sendText({String? text, String? imageBase64, String? audioBase64}) async {
    final hasText = text != null && text.trim().isNotEmpty;
    final hasImage = imageBase64 != null && imageBase64.isNotEmpty;
    final hasAudio = audioBase64 != null && audioBase64.isNotEmpty;

    if (!hasText && !hasImage && !hasAudio) return;

    final newMessages = [
      ...state.messages,
      ChatMessage(
        role: MessageRole.user,
        text: hasText ? text : (hasAudio ? "🔊 [语音识别中...]" : null),
        imageBytes: hasImage ? imageBase64 : null,
        audioBytes: hasAudio ? audioBase64 : null,
      )
    ];

    state = state.copyWith(
      messages: newMessages,
      loading: true,
      status: "正在生成草稿...",
      drafts: [],
      cards: [],
      clarifyQuestion: null,
    );
    try {
      final req = ChatRequest(text: text, image: imageBase64, audio: audioBase64);
      state = state.copyWith(lastFailedRequest: req); // track for retry

      final resp = await _repo.send(req);
      final assistantReply =
          resp.replyToUser ?? (resp.needClarification ? "需要补充信息" : "草稿已生成");
      final updatedMessages = [
        ...newMessages,
        ChatMessage(role: MessageRole.assistant, text: assistantReply),
      ];
      state = state.copyWith(
        messages: updatedMessages,
        drafts: resp.drafts,
        cards: resp.cards,
        loading: false,
        status: resp.needClarification ? "需要补充说明" : "草稿已生成",
        clarifyQuestion: resp.clarifyQuestion,
      );
    } catch (exc) {
      state = state.copyWith(
        loading: false,
        status: "请求失败：$exc",
      );
    }
  }

  Future<void> confirmDrafts(List<String> draftIds) async {
    if (draftIds.isEmpty) return;
    state = state.copyWith(loading: true, status: "正在确认...");
    try {
      final resp = await _repo.send(ChatRequest(confirmDraftIds: draftIds));
      final updatedMessages = [
        ...state.messages,
        ChatMessage(
            role: MessageRole.assistant,
            text: "已确认 ${resp.committed.length} 条记录"),
      ];
      state = state.copyWith(
        loading: false,
        status: "已确认 ${resp.committed.length} 条记录",
        drafts: [],
        cards: [],
        undoToken: resp.undoToken,
        messages: updatedMessages,
      );
      
      // Refresh timeline when records are committed
      _ref.read(timelineControllerProvider.notifier).loadEvents();
    } catch (exc) {
      state = state.copyWith(
        loading: false,
        status: "确认失败：$exc",
        lastFailedRequest: ChatRequest(confirmDraftIds: draftIds),
      );
    }
  }

  Future<void> undo() async {
    final token = state.undoToken;
    if (token == null) return;
    state = state.copyWith(loading: true, status: "正在撤销...");
    try {
      final resp = await _repo.send(ChatRequest(undoToken: token));
      final updatedMessages = [
        ...state.messages,
        ChatMessage(
            role: MessageRole.assistant, text: "已撤销 ${resp.undone.length} 条记录"),
      ];
      state = state.copyWith(
        loading: false,
        status: "已撤销 ${resp.undone.length} 条记录",
        messages: updatedMessages,
        undoToken: null, // Clear token after successful undo
      );
      
      // Refresh timeline after undoing records
      _ref.read(timelineControllerProvider.notifier).loadEvents();
    } catch (exc) {
      state = state.copyWith(
        loading: false,
        status: "撤销失败：$exc",
      );
    }
  }

  Future<void> editDraft(String draftId, Map<String, dynamic> patch) async {
    state = state.copyWith(loading: true, status: "正在更新草稿...");
    try {
      final resp = await _repo.send(
        ChatRequest(action: "edit", draftId: draftId, patch: patch),
      );
      final updatedMessages = [
        ...state.messages,
        ChatMessage(role: MessageRole.assistant, text: "草稿已更新"),
      ];
      state = state.copyWith(
        loading: false,
        status: "草稿已更新",
        drafts: resp.drafts,
        cards: resp.cards,
        messages: updatedMessages,
      );
    } catch (exc) {
      state = state.copyWith(
        loading: false,
        status: "更新失败：$exc",
      );
    }
  }

  Future<void> taskAction({
    required int taskId,
    required String op,
    Map<String, dynamic>? payload,
  }) async {
    state = state.copyWith(loading: true, status: "正在处理任务...");
    try {
      final resp = await _repo.send(
        ChatRequest(
            action: "task_action", taskId: taskId, op: op, payload: payload),
      );
      final updatedMessages = [
        ...state.messages,
        ChatMessage(role: MessageRole.assistant, text: "任务已更新"),
      ];
      state = state.copyWith(
        loading: false,
        status: "任务已更新",
        messages: updatedMessages,
      );
      if (resp.undoToken != null) {
        state = state.copyWith(undoToken: resp.undoToken);
      }
    } catch (exc) {
      state = state.copyWith(
        loading: false,
        status: "任务操作失败：$exc",
      );
    }
  }

  /// Retry the last failed request.
  Future<void> retry() async {
    final req = state.lastFailedRequest;
    if (req == null) return;
    if (req.text != null || req.image != null || req.audio != null) {
      await sendText(text: req.text, imageBase64: req.image, audioBase64: req.audio);
    } else if (req.confirmDraftIds != null) {
      await confirmDrafts(req.confirmDraftIds!);
    } else if (req.undoToken != null) {
      await undo();
    }
  }
}
