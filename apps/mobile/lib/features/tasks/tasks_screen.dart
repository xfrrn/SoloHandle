import "package:flutter/material.dart";

import "../../core/constants.dart";

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tasks")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SectionHeader(text: "Today"),
          _TaskItem(title: "示例任务", time: "18:00"),
          _SectionHeader(text: "Overdue"),
          _TaskItem(title: "逾期任务", time: "昨天"),
          _SectionHeader(text: "All"),
          _TaskItem(title: "更多任务", time: "-"),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _TaskItem extends StatelessWidget {
  const _TaskItem({required this.title, required this.time});

  final String title;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_box_outline_blank, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
          Text(
            time,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
