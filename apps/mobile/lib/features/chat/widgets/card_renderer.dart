import "package:flutter/material.dart";

import "../../../core/constants.dart";
import "../../../core/time.dart";
import "../../../data/api/dto.dart";

class CardRenderer extends StatelessWidget {
  const CardRenderer({
    super.key,
    required this.card,
    required this.onConfirm,
    required this.onEdit,
    this.onComplete,
    this.onPostpone,
    this.onDelete,
  });

  final CardDto card;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;
  final VoidCallback? onComplete;
  final VoidCallback? onPostpone;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final subtitle =
        card.type == "task" ? _subtitleFromData(card.data) : (card.subtitle.isNotEmpty ? card.subtitle : _subtitleFromData(card.data));
    final dataEntries = card.data.entries.toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: card.status == "draft" ? AppColors.accent.withAlpha(128) : AppColors.divider,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CardAvatar(type: card.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title.isEmpty ? "草稿" : card.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              _StatusBadge(status: card.status),
            ],
          ),
          if (card.type == "task") ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _taskBadges(card.data).map((text) => _Badge(text: text)).toList(),
            ),
          ],
          if (dataEntries.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                children: dataEntries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.key.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.value.toString(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (card.status == "draft")
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text("修改"),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: const Text("确认提交"),
                ),
              ],
            )
          else if (card.type == "task" &&
              (onComplete != null || onPostpone != null || onDelete != null))
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onPostpone != null) ...[
                  OutlinedButton(
                    onPressed: onPostpone,
                    style: OutlinedButton.styleFrom(
                       foregroundColor: AppColors.textSecondary,
                       side: const BorderSide(color: AppColors.divider),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("延期"),
                  ),
                  const SizedBox(width: 8),
                ],
                if (onDelete != null) ...[
                   OutlinedButton(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                       foregroundColor: AppColors.danger,
                       side: const BorderSide(color: AppColors.dangerLight),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("删除"),
                  ),
                  const SizedBox(width: 8),
                ],
                if (onComplete != null)
                  ElevatedButton(
                    onPressed: onComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("完成"),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _subtitleFromData(Map<String, dynamic> data) {
    final due = data["due_at"];
    final remind = data["remind_at"];
    final priority = data["priority"];
    final parts = <String>[];
    if (due is String && due.isNotEmpty) {
      parts.add("截止：${formatIsoToLocal(due)}");
    }
    if (remind is String && remind.isNotEmpty) {
      parts.add("提醒：${formatIsoToLocal(remind)}");
    }
    if (priority is String && priority.isNotEmpty) {
      parts.add("优先级：${_priorityLabel(priority)}");
    }
    if (parts.isNotEmpty) return parts.join(" · ");
    final time = data["time"] ?? data["happened_at"];
    if (time is String && time.isNotEmpty) return "时间：${formatIsoToLocal(time)}";
    return "";
  }

  String _priorityLabel(String value) {
    return switch (value) {
      "low" => "低",
      "high" => "高",
      _ => "中",
    };
  }

  List<String> _taskBadges(Map<String, dynamic> data) {
    final priority = data["priority"];
    final status = data["status"];
    final badges = <String>[];
    if (priority is String && priority.isNotEmpty) {
      badges.add(_priorityLabel(priority));
    }
    if (status is String && status.isNotEmpty) {
      badges.add(_statusLabel(status));
    }
    return badges;
  }

  String _statusLabel(String value) {
    return switch (value) {
      "done" => "已完成",
      "canceled" => "已取消",
      _ => "进行中",
    };
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: const Color(0xFF444444)),
      ),
    );
  }
}

class _CardAvatar extends StatelessWidget {
  const _CardAvatar({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    Color bgColor;
    Color iconColor;

    switch (type) {
      case "expense":
        iconData = Icons.receipt_long;
        bgColor = AppColors.warningLight;
        iconColor = AppColors.warning;
        break;
      case "task":
        iconData = Icons.check_circle_outline;
        bgColor = AppColors.accentLight;
        iconColor = AppColors.accent;
        break;
      case "mood":
        iconData = Icons.mood;
        bgColor = AppColors.successLight;
        iconColor = AppColors.success;
        break;
      default:
        iconData = Icons.event_note;
        bgColor = const Color(0xFFF1F5F9); // slate-100
        iconColor = const Color(0xFF64748B); // slate-500
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    if (status == "draft") {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          "草稿",
          style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      );
    } else if (status == "failed") {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          "失败",
          style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      );
    }
    
    return Text(
      "已提交",
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
    );
  }
}
