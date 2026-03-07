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
      return _GenericEditSheet(card: widget.card, onSubmit: widget.onSubmit);
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
            value: _dueAt == null
                ? "未设置"
                : formatIsoToLocal(toIsoWithOffset(_dueAt!)),
            onPick: () => _pickDueAt(context),
            onClear:
                _dueAt == null ? null : () => setState(() => _dueAt = null),
          ),
          const SizedBox(height: 8),
          _TimeRow(
            label: "提醒时间",
            value: _remindAt == null
                ? "未设置"
                : formatIsoToLocal(toIsoWithOffset(_remindAt!)),
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
            onSelectionChanged: (value) =>
                setState(() => _priority = value.first),
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

  Future<DateTime?> _pickDateTime(
      BuildContext context, DateTime? initial) async {
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
            style:
                TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text("清空"),
          ),
      ],
    );
  }
}

class _GenericEditSheet extends StatefulWidget {
  const _GenericEditSheet({required this.card, required this.onSubmit});

  final CardDto card;
  final ValueChanged<Map<String, dynamic>> onSubmit;

  @override
  State<_GenericEditSheet> createState() => _GenericEditSheetState();
}

class _GenericEditSheetState extends State<_GenericEditSheet> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, DateTime?> _dates = {};

  @override
  void initState() {
    super.initState();
    for (final entry in widget.card.data.entries) {
      if (entry.key.endsWith("_at")) {
        _dates[entry.key] = parseIsoToLocal(entry.value as String?);
      } else {
        _controllers[entry.key] = TextEditingController(text: entry.value?.toString() ?? "");
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("修改记录", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final entry in _controllers.entries) ...[
              TextField(
                controller: entry.value,
                decoration: InputDecoration(labelText: entry.key),
              ),
              const SizedBox(height: 12),
            ],
            for (final entry in _dates.entries) ...[
              _TimeRow(
                label: entry.key,
                value: entry.value == null
                    ? "未设置"
                    : formatIsoToLocal(toIsoWithOffset(entry.value!)),
                onPick: () async {
                  final now = DateTime.now();
                  final date = await showDatePicker(
                    context: context,
                    initialDate: entry.value ?? now,
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (date == null) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(entry.value ?? now),
                  );
                  if (time == null) return;
                  setState(() {
                    _dates[entry.key] = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                  });
                },
                onClear: entry.value == null ? null : () => setState(() => _dates[entry.key] = null),
              ),
              const SizedBox(height: 12),
            ],
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
                  onPressed: () {
                    final patch = <String, dynamic>{};
                    for (final entry in _controllers.entries) {
                      final val = entry.value.text.trim();
                      final original = widget.card.data[entry.key];
                      if (original is num) {
                        patch[entry.key] = num.tryParse(val) ?? original;
                      } else if (original is bool) {
                        patch[entry.key] = val.toLowerCase() == 'true';
                      } else {
                        patch[entry.key] = val;
                      }
                    }
                    for (final entry in _dates.entries) {
                      patch[entry.key] = entry.value == null ? null : toIsoWithOffset(entry.value!);
                    }
                    widget.onSubmit(patch);
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                  child: const Text("发送修改"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
