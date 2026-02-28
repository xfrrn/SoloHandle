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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: card.status == "draft" ? AppColors.accent : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.title.isEmpty ? "草稿" : card.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (card.type == "task") ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _taskBadges(card.data).map((text) => _Badge(text: text)).toList(),
            ),
          ],
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
          if (dataEntries.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dataEntries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Text(
                    "${entry.key}: ${entry.value}",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),
          if (card.status == "draft")
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onEdit,
                  child: const Text("编辑"),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onConfirm,
                  style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                  child: const Text("确认"),
                ),
              ],
            )
          else if (card.type == "task" &&
              (onComplete != null || onPostpone != null || onDelete != null))
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onComplete != null)
                  TextButton(onPressed: onComplete, child: const Text("完成")),
                if (onPostpone != null)
                  TextButton(onPressed: onPostpone, child: const Text("延期")),
                if (onDelete != null)
                  TextButton(
                    onPressed: onDelete,
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    child: const Text("删除"),
                  ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                card.status == "failed" ? "失败" : "已提交",
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
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
