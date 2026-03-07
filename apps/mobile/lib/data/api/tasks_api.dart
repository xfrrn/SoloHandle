import "package:dio/dio.dart";

import "models.dart";

class TasksApi {
  TasksApi(this._dio);

  final Dio _dio;

  Future<PaginatedResponse<TaskDto>> list({
    String? query,
    String? status,
    String? scope,
    String? dateFrom,
    String? dateTo,
    String timezone = "Asia/Shanghai",
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      "limit": limit,
      "offset": offset,
      "timezone": timezone,
    };
    if (query != null && query.isNotEmpty) params["query"] = query;
    if (status != null && status.isNotEmpty) params["status"] = status;
    if (scope != null && scope.isNotEmpty) params["scope"] = scope;
    if (dateFrom != null) params["date_from"] = dateFrom;
    if (dateTo != null) params["date_to"] = dateTo;

    final resp = await _dio.get("/tasks", queryParameters: params);
    final data = resp.data as Map<String, dynamic>;
    final items = (data["items"] as List)
        .map((e) => TaskDto.fromJson(e as Map<String, dynamic>))
        .toList();
    return PaginatedResponse(
        items: items, total: data["total"] as int? ?? items.length);
  }

  Future<TaskDto> complete(int taskId) async {
    final resp = await _dio.post("/tasks/$taskId/complete");
    return TaskDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<TaskDto> waiting(int taskId) async {
    final resp = await _dio.post("/tasks/$taskId/waiting");
    return TaskDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<TaskDto> update(
    int taskId, {
    String? title,
    String? note,
    String? priority,
    String? dueAt,
    bool clearDueAt = false,
    String? status,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body["title"] = title;
    if (note != null) body["note"] = note;
    if (priority != null) body["priority"] = priority;
    if (dueAt != null) body["due_at"] = dueAt;
    if (clearDueAt) body["due_at"] = null;
    if (status != null) body["status"] = status;

    final resp = await _dio.patch("/tasks/$taskId", data: body);
    return TaskDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<TaskDto> delete(int taskId) async {
    final resp = await _dio.delete("/tasks/$taskId");
    return TaskDto.fromJson(resp.data as Map<String, dynamic>);
  }
}
