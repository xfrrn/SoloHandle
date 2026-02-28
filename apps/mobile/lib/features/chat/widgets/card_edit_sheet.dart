import "package:flutter/material.dart";

import "../../../core/constants.dart";
import "../../../core/time.dart";
import "../../../data/api/dto.dart";

class CardEditSheet extends StatefulWidget {
  const CardEditSheet({super.key, required this.card, required this.onSubmit});

  final CardDto card;
  final ValueChanged<Map<String, dynamic>> onSubmit;

  @override
  State<CardEditSheet> createState() => _CardEditSheetState();
}

class _CardEditSheetState extends State<CardEditSheet> {
  late final TextEditingController _titleController;
  DateTime? _dueAt;
  DateTime? _remindAt;
  bool _remindCleared = false;
  String _priority = "medium";

  @override
  void initState() {
    super.initState();
    final data = widget.card.data;
    _titleController = TextEditingController(
      text: (data["title"] as String?)?.trim().isNotEmpty == true
          ? data["title"] as String
          : widget.card.title,
    );
    _dueAt = parseIsoToLocal(data["due_at"] as String?);
    _remindAt = parseIsoToLocal(data["remind_at"] as String?);
    _priority = (data["priority"] as String?) ?? "medium";
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.card.type != "task") {
      return _FallbackSheet(onSubmit: () => Navigator.of(context).pop());
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("编辑任务", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: "标题"),
          ),
          const SizedBox(height: 12),
          _TimeRow(
            label: "截止时间",
            value: _dueAt == null ? "未设置" : formatIsoToLocal(toIsoWithOffset(_dueAt!)),
            onPick: () => _pickDueAt(context),
            onClear: _dueAt == null ? null : () => setState(() => _dueAt = null),
          ),
          const SizedBox(height: 8),
          _TimeRow(
            label: "提醒时间",
            value: _remindAt == null ? "未设置" : formatIsoToLocal(toIsoWithOffset(_remindAt!)),
            onPick: () => _pickRemindAt(context),
            onClear: _remindAt == null
                ? null
                : () => setState(() {
                      _remindAt = null;
                      _remindCleared = true;
                    }),
          ),
          const SizedBox(height: 12),
          Text("优先级", style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: "low", label: Text("低")),
              ButtonSegment(value: "medium", label: Text("中")),
              ButtonSegment(value: "high", label: Text("高")),
            ],
            selected: {_priority},
            onSelectionChanged: (value) => setState(() => _priority = value.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("取消"),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _submit(context),
                style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                child: const Text("发送修改"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDueAt(BuildContext context) async {
    final picked = await _pickDateTime(context, _dueAt);
    if (picked != null) {
      setState(() => _dueAt = picked);
    }
  }

  Future<void> _pickRemindAt(BuildContext context) async {
    final picked = await _pickDateTime(context, _remindAt ?? _dueAt);
    if (picked != null) {
      setState(() {
        _remindAt = picked;
        _remindCleared = false;
      });
    }
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime? initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (date == null) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _submit(BuildContext context) {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("标题不能为空")),
      );
      return;
    }
    if (_dueAt == null && _remindAt != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请先设置截止时间")),
      );
      return;
    }

    DateTime? remindValue = _remindAt;
    if (_dueAt != null && _remindAt == null && !_remindCleared) {
      remindValue = _dueAt!.subtract(const Duration(minutes: 30));
    }

    final patch = <String, dynamic>{
      "title": title,
      "due_at": _dueAt == null ? null : toIsoWithOffset(_dueAt!),
      "remind_at": remindValue == null ? null : toIsoWithOffset(remindValue),
      "priority": _priority,
    };

    widget.onSubmit(patch);
    Navigator.of(context).pop();
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 8),
        TextButton(onPressed: onPick, child: const Text("选择")),
        if (onClear != null)
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text("清空"),
          ),
      ],
    );
  }
}

class _FallbackSheet extends StatelessWidget {
  const _FallbackSheet({required this.onSubmit});

  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("当前卡片暂不支持结构化编辑"),
          const SizedBox(height: 12),
          TextButton(onPressed: onSubmit, child: const Text("关闭")),
        ],
      ),
    );
  }
}
