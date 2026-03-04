import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../data/api/api_client.dart";
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
  });

  final List<EventDto> events;
  final bool loading;
  final String? error;
  final Set<String> selectedTypes;
  final String searchQuery;

  factory TimelineState.initial() {
    return TimelineState(
      events: [],
      loading: false,
      error: null,
      selectedTypes: {},
      searchQuery: "",
    );
  }

  TimelineState copyWith({
    List<EventDto>? events,
    bool? loading,
    String? error,
    Set<String>? selectedTypes,
    String? searchQuery,
  }) {
    return TimelineState(
      events: events ?? this.events,
      loading: loading ?? this.loading,
      error: error,
      selectedTypes: selectedTypes ?? this.selectedTypes,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Group events by date for section headers.
  Map<String, List<EventDto>> get groupedByDate {
    final map = <String, List<EventDto>>{};
    for (final event in filteredEvents) {
      final dateKey = _extractDate(event.happenedAt);
      map.putIfAbsent(dateKey, () => []).add(event);
    }
    return map;
  }

  List<EventDto> get filteredEvents {
    if (selectedTypes.isEmpty) return events;
    return events.where((e) => selectedTypes.contains(e.type)).toList();
  }

  static String _extractDate(String isoDate) {
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return isoDate;
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return "今天";
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return "昨天";
    }
    return "${dt.month}月${dt.day}日";
  }
}

class TimelineController extends StateNotifier<TimelineState> {
  TimelineController() : super(TimelineState.initial());

  final _apiClient = ApiClient(store: LocalStore());

  Future<void> loadEvents() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final dio = await _apiClient.dio;
      final api = EventsApi(dio);
      final resp = await api.list(
        query: state.searchQuery.isEmpty ? null : state.searchQuery,
      );
      state = state.copyWith(events: resp.items, loading: false);
    } on DioException catch (exc) {
      state = state.copyWith(
        loading: false,
        error: exc.response?.data?.toString() ?? exc.message ?? "加载失败",
      );
    } catch (exc) {
      state = state.copyWith(loading: false, error: "加载失败：$exc");
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
}
