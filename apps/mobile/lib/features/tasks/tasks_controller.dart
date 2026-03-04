import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../data/api/api_client.dart";
import "../../data/api/models.dart";
import "../../data/api/tasks_api.dart";
import "../../data/storage/local_store.dart";

final tasksControllerProvider =
    StateNotifierProvider<TasksController, TasksState>((ref) {
  return TasksController();
});

enum TaskScope { today, overdue, all }

class TasksState {
  TasksState({
    required this.todayTasks,
    required this.overdueTasks,
    required this.allTasks,
    required this.loading,
    required this.error,
    required this.activeScope,
  });

  final List<TaskDto> todayTasks;
  final List<TaskDto> overdueTasks;
  final List<TaskDto> allTasks;
  final bool loading;
  final String? error;
  final TaskScope activeScope;

  factory TasksState.initial() {
    return TasksState(
      todayTasks: [],
      overdueTasks: [],
      allTasks: [],
      loading: false,
      error: null,
      activeScope: TaskScope.today,
    );
  }

  TasksState copyWith({
    List<TaskDto>? todayTasks,
    List<TaskDto>? overdueTasks,
    List<TaskDto>? allTasks,
    bool? loading,
    String? error,
    TaskScope? activeScope,
  }) {
    return TasksState(
      todayTasks: todayTasks ?? this.todayTasks,
      overdueTasks: overdueTasks ?? this.overdueTasks,
      allTasks: allTasks ?? this.allTasks,
      loading: loading ?? this.loading,
      error: error,
      activeScope: activeScope ?? this.activeScope,
    );
  }

  List<TaskDto> get activeTasks {
    switch (activeScope) {
      case TaskScope.today:
        return todayTasks;
      case TaskScope.overdue:
        return overdueTasks;
      case TaskScope.all:
        return allTasks;
    }
  }
}

class TasksController extends StateNotifier<TasksState> {
  TasksController() : super(TasksState.initial());

  final _apiClient = ApiClient(store: LocalStore());

  Future<void> loadAll() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final dio = await _apiClient.dio;
      final api = TasksApi(dio);

      final todayResp = await api.list(scope: "today");
      final overdueResp = await api.list(scope: "overdue");
      final allResp = await api.list();

      state = state.copyWith(
        todayTasks: todayResp.items,
        overdueTasks: overdueResp.items,
        allTasks: allResp.items,
        loading: false,
      );
    } on DioException catch (exc) {
      state = state.copyWith(
        loading: false,
        error: exc.response?.data?.toString() ?? exc.message ?? "加载失败",
      );
    } catch (exc) {
      state = state.copyWith(loading: false, error: "加载失败：$exc");
    }
  }

  void setScope(TaskScope scope) {
    state = state.copyWith(activeScope: scope);
  }

  Future<void> completeTask(int taskId) async {
    try {
      final dio = await _apiClient.dio;
      final api = TasksApi(dio);
      await api.complete(taskId);
      await loadAll();
    } catch (exc) {
      state = state.copyWith(error: "完成任务失败：$exc");
    }
  }
}
