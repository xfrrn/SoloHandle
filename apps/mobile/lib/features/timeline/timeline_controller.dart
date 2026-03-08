import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../data/api/api_client.dart";
import "../../data/api/chat_api.dart";
import "../../data/api/dto.dart";
import "../../data/api/events_api.dart";
import "../../data/api/models.dart";
import "../../data/storage/local_store.dart";

final timelineControllerProvider =
    StateNotifierProvider<TimelineController, TimelineState>((ref) {
  return TimelineController();
});

class TimelineState {
  TimelineState({
    required this.events,
    required this.loading,
    required this.error,
    required this.selectedTypes,
    required this.searchQuery,
    required this.expandedEventId,
    required this.undoLoading,
  });

  final List<EventDto> events;
  final bool loading;
  final String? error;
  final Set<String> selectedTypes;
  final String searchQuery;
  final bool undoLoading;
  final int? expandedEventId;

  factory TimelineState.initial() {
    return TimelineState(
      events: [],
      loading: false,
      error: null,
      selectedTypes: {},
      searchQuery: "",
      expandedEventId: null,
      undoLoading: false,
    );
  }

  static const _noChange = Object();

  TimelineState copyWith({
    List<EventDto>? events,
    bool? loading,
    String? error,
    Set<String>? selectedTypes,
    String? searchQuery,
    bool? undoLoading,
    Object? expandedEventId = _noChange,
  }) {
    return TimelineState(
      events: events ?? this.events,
      loading: loading ?? this.loading,
      error: error,
      selectedTypes: selectedTypes ?? this.selectedTypes,
      searchQuery: searchQuery ?? this.searchQuery,
      undoLoading: undoLoading ?? this.undoLoading,
      expandedEventId: identical(expandedEventId, _noChange)
          ? this.expandedEventId
          : expandedEventId as int?,
    );
  }

  List<EventDto> get filteredEvents {
    if (selectedTypes.isEmpty) return events;
    return events.where((e) {
      final isRepayment = e.type == "transfer" &&
          ((e.data["note"]?.toString() ?? "").trim().startsWith("还款"));
      if (selectedTypes.contains("repayment") && isRepayment) {
        return true;
      }
      return selectedTypes.contains(e.type);
    }).toList();
  }

  Map<String, List<EventDto>> get groupedByDate {
    final map = <String, List<EventDto>>{};
    for (final event in filteredEvents) {
      final k = _extractDate(event.happenedAt);
      map.putIfAbsent(k, () => []).add(event);
    }
    return map;
  }

  static String _extractDate(String isoDate) {
    final dt = DateTime.tryParse(isoDate)?.toLocal();
    if (dt == null) return isoDate;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);

    if (target == today) {
      return "\u4ECA\u5929";
    }
    if (target == today.subtract(const Duration(days: 1))) {
      return "\u6628\u5929";
    }
    return "${dt.month}\u6708${dt.day}\u65E5";
  }
}

class TimelineController extends StateNotifier<TimelineState> {
  TimelineController() : super(TimelineState.initial());

  final _apiClient = ApiClient(store: LocalStore());

  Future<void> undoCommit(String commitId) async {
    if (commitId.isEmpty) return;

    state = state.copyWith(undoLoading: true, error: null);
    try {
      final dio = await _apiClient.dio;
      final api = ChatApi(dio);
      await api.send(ChatRequest(commitId: commitId));
      state = state.copyWith(undoLoading: false);
      await loadEvents();
    } on DioException catch (exc) {
      state = state.copyWith(
        undoLoading: false,
        error: exc.response?.data?.toString() ??
            exc.message ??
            "\u64A4\u9500\u5931\u8D25",
      );
    } catch (exc) {
      state = state.copyWith(
          undoLoading: false, error: "\u64A4\u9500\u5931\u8D25\uFF1A$exc");
    }
  }

  Future<void> loadEvents({int? expandEventId}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final dio = await _apiClient.dio;
      final api = EventsApi(dio);
      final resp = await api.list(
        query: state.searchQuery.isEmpty ? null : state.searchQuery,
        types: state.selectedTypes
                .where((type) => type != "repayment")
                .toList()
                .isEmpty
            ? null
            : state.selectedTypes.where((type) => type != "repayment").toList(),
      );
      state = state.copyWith(
        events: resp.items,
        loading: false,
        expandedEventId: expandEventId ?? state.expandedEventId,
      );
    } on DioException catch (exc) {
      state = state.copyWith(
        loading: false,
        error: exc.response?.data?.toString() ??
            exc.message ??
            "\u52A0\u8F7D\u5931\u8D25",
      );
    } catch (exc) {
      state = state.copyWith(
          loading: false, error: "\u52A0\u8F7D\u5931\u8D25\uFF1A$exc");
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggleType(String type) {
    final types = Set<String>.from(state.selectedTypes);
    if (types.contains(type)) {
      types.remove(type);
    } else {
      types.add(type);
    }
    state = state.copyWith(selectedTypes: types);
  }

  void clearFilters() {
    state = state.copyWith(selectedTypes: {}, searchQuery: "");
  }

  void toggleExpanded(int eventId) {
    state = state.copyWith(
      expandedEventId: state.expandedEventId == eventId ? null : eventId,
    );
  }

  Future<void> focusEvent(int eventId) async {
    state = state.copyWith(
      selectedTypes: {},
      searchQuery: "",
      expandedEventId: eventId,
      error: null,
    );
    await loadEvents(expandEventId: eventId);
  }
}
