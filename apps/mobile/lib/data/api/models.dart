// DTO models for the events and tasks API.

class EventDto {
  EventDto({
    required this.eventId,
    required this.type,
    required this.happenedAt,
    required this.tags,
    required this.data,
    required this.source,
    required this.confidence,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });

  final int eventId;
  final String type;
  final String happenedAt;
  final List<String> tags;
  final Map<String, dynamic> data;
  final String source;
  final double confidence;
  final String createdAt;
  final String updatedAt;
  final int isDeleted;

  factory EventDto.fromJson(Map<String, dynamic> json) {
    final tagsList = (json["tags"] as List?)?.cast<String>() ?? [];
    return EventDto(
      eventId: json["event_id"] as int? ?? 0,
      type: json["type"] as String? ?? "",
      happenedAt: json["happened_at"] as String? ?? "",
      tags: tagsList,
      data: (json["data"] as Map?)?.cast<String, dynamic>() ?? {},
      source: json["source"] as String? ?? "",
      confidence: (json["confidence"] as num?)?.toDouble() ?? 0.0,
      createdAt: json["created_at"] as String? ?? "",
      updatedAt: json["updated_at"] as String? ?? "",
      isDeleted: json["is_deleted"] as int? ?? 0,
    );
  }

  /// Display-friendly summary line.
  String get displayTitle {
    switch (type) {
      case "expense":
        final amount = data["amount"];
        final cat = data["category"] ?? "";
        return "¥$amount $cat";
      case "meal":
        return data["description"] as String? ?? "用餐记录";
      case "mood":
        final emotion = data["emotion"] ?? data["mood"] ?? "";
        return "心情：$emotion";
      case "life_log":
        return data["description"] as String? ?? "生活记录";
      default:
        return type;
    }
  }
}

class TaskDto {
  TaskDto({
    required this.taskId,
    required this.title,
    required this.status,
    required this.priority,
    required this.dueAt,
    required this.remindAt,
    required this.tags,
    required this.project,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.completedAt,
    required this.isDeleted,
  });

  final int taskId;
  final String title;
  final String status;
  final String priority;
  final String? dueAt;
  final String? remindAt;
  final List<String> tags;
  final String? project;
  final String? note;
  final String createdAt;
  final String updatedAt;
  final String? completedAt;
  final int isDeleted;

  bool get isDone => status == "done";
  bool get isOverdue {
    if (dueAt == null || isDone) return false;
    final due = DateTime.tryParse(dueAt!);
    if (due == null) return false;
    return due.isBefore(DateTime.now());
  }

  factory TaskDto.fromJson(Map<String, dynamic> json) {
    final tagsList = (json["tags"] as List?)?.cast<String>() ?? [];
    return TaskDto(
      taskId: json["task_id"] as int? ?? 0,
      title: json["title"] as String? ?? "",
      status: json["status"] as String? ?? "",
      priority: json["priority"] as String? ?? "medium",
      dueAt: json["due_at"] as String?,
      remindAt: json["remind_at"] as String?,
      tags: tagsList,
      project: json["project"] as String?,
      note: json["note"] as String?,
      createdAt: json["created_at"] as String? ?? "",
      updatedAt: json["updated_at"] as String? ?? "",
      completedAt: json["completed_at"] as String?,
      isDeleted: json["is_deleted"] as int? ?? 0,
    );
  }
}

/// Generic paginated list response.
class PaginatedResponse<T> {
  PaginatedResponse({required this.items, required this.total});

  final List<T> items;
  final int total;
}
