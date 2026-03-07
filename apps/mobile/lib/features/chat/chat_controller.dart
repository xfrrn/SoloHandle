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
      status: status == "" ? null : (status ?? this.status),
      undoToken: undoToken == "" ? null : (undoToken ?? this.undoToken),
      clarifyQuestion: clarifyQuestion == "" ? null : (clarifyQuestion ?? this.clarifyQuestion),
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
  ChatMessage({
    required this.role,
    this.text,
    this.imageBytes,
    this.audioBytes,
    this.cards,
  });

  final MessageRole role;
  final String? text;
  final List<String>? imageBytes;
  final String? audioBytes;
  final List<CardDto>? cards;
}

enum MessageRole { user, assistant }

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._repo, this._ref) : super(ChatState.initial());

  final ChatRepository _repo;
  final Ref _ref;
  final LocalStore _store = LocalStore();

  Future<void> sendText({
    String? text,
    List<String>? imageBase64,
    String? audioBase64,
  }) async {
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
      status: "",
      drafts: state.drafts,
      cards: state.cards,
      clarifyQuestion: "",
    );
    try {
      final imageForRequest = hasImage ? imageBase64!.first : null;
      final req = ChatRequest(
        text: text,
        image: imageForRequest,
        images: imageBase64,
        audio: audioBase64,
      );
      state = state.copyWith(lastFailedRequest: req); // track for retry

      final resp = await _repo.send(req);
      
      final updatedMessages = List<ChatMessage>.from(newMessages);
      
      final hasReply = resp.replyToUser != null && resp.replyToUser!.trim().isNotEmpty;
      final hasCards = resp.cards.isNotEmpty;

      if (hasReply || hasCards) {
        updatedMessages.add(ChatMessage(
          role: MessageRole.assistant,
          text: hasReply ? resp.replyToUser!.trim() : null,
          cards: hasCards ? resp.cards : null,
        ));
      }

      state = state.copyWith(
        messages: updatedMessages,
        drafts: [...state.drafts, ...resp.drafts],
        cards: [...state.cards, ...resp.cards],
        loading: false,
        status: resp.needClarification ? "需要补充说明" : "",
        clarifyQuestion: resp.clarifyQuestion ?? "",
      );
    } catch (exc) {
      state = state.copyWith(
        loading: false,
        status: "请求失败：$exc",
      );
    }
  }

  Future<void> confirmDrafts(List<String> draftIds) async {
    final cleaned = draftIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (cleaned.isEmpty) {
      state = state.copyWith(status: "没有可确认的草稿");
      return;
    }
    state = state.copyWith(loading: true, status: "正在确认...");
    try {
      final resp = await _repo.send(ChatRequest(confirmDraftIds: cleaned));
      
      final committedIds = resp.committed.map((e) => e["draft_id"].toString()).toList();
      
      final updatedCards = state.cards.map((c) {
        if (cleaned.contains(c.cardId) || committedIds.contains(c.cardId)) {
          return CardDto(
            cardId: c.cardId,
            type: c.type,
            status: "committed",
            title: c.title,
            subtitle: c.subtitle,
            data: c.data,
          );
        }
        return c;
      }).toList();
      
      final updatedDrafts = state.drafts.where((d) {
        return !cleaned.contains(d.draftId) && !committedIds.contains(d.draftId);
      }).toList();

      final updatedMessages = state.messages.map((m) {
        if (m.cards != null) {
          final mappedCards = m.cards!.map((c) {
            if (cleaned.contains(c.cardId) || committedIds.contains(c.cardId)) {
              return CardDto(
                cardId: c.cardId,
                type: c.type,
                status: "committed",
                title: c.title,
                subtitle: c.subtitle,
                data: c.data,
              );
            }
            return c;
          }).toList();
          return ChatMessage(
            role: m.role,
            text: m.text,
            imageBytes: m.imageBytes,
            audioBytes: m.audioBytes,
            cards: mappedCards,
          );
        }
        return m;
      }).toList();

      state = state.copyWith(
        loading: false,
        status: "已确认 ${resp.committed.length} 条记录",
        drafts: updatedDrafts,
        cards: updatedCards,
        messages: updatedMessages,
        undoToken: resp.undoToken ?? "",
      );

      if (resp.undoToken != null && resp.undoToken!.isNotEmpty) {
        await _store.setUndoToken(resp.undoToken!);
      }
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
      state = state.copyWith(
        loading: false,
        status: "已撤销 ${resp.undone.length} 条记录",
        undoToken: "", // Clear token after successful undo
      );
      await _store.clearUndoToken();
      
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
      final newDrafts = state.drafts.map((d) => 
          d.draftId == draftId && resp.drafts.isNotEmpty ? resp.drafts.first : d).toList();
      final newCards = state.cards.map((c) => 
          c.cardId == draftId && resp.cards.isNotEmpty ? resp.cards.first : c).toList();

      // The edited card needs to be updated not just in state.cards, but also inside messages!
      final newMessages = state.messages.map((m) {
        if (m.cards != null) {
          final mappedCards = m.cards!.map((c) => 
              c.cardId == draftId && resp.cards.isNotEmpty ? resp.cards.first : c).toList();
          return ChatMessage(
            role: m.role,
            text: m.text,
            imageBytes: m.imageBytes,
            audioBytes: m.audioBytes,
            cards: mappedCards,
          );
        }
        return m;
      }).toList();

      state = state.copyWith(
        loading: false,
        status: "草稿已更新",
        drafts: newDrafts,
        cards: newCards,
        messages: newMessages,
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
      state = state.copyWith(
        loading: false,
        status: "任务已更新",
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
      await sendText(
        text: req.text,
        imageBase64: req.images ?? (req.image != null ? [req.image!] : null),
        audioBase64: req.audio,
      );
    } else if (req.confirmDraftIds != null) {
      await confirmDrafts(req.confirmDraftIds!);
    } else if (req.undoToken != null) {
      await undo();
    }
  }
}
