import "package:flutter/material.dart";

import "../../core/constants.dart";

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Timeline")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: "搜索"),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: const [
              _Chip(label: "All"),
              _Chip(label: "Expense"),
              _Chip(label: "Mood"),
              _Chip(label: "Task"),
              _Chip(label: "Log"),
            ],
          ),
          const SizedBox(height: 16),
          const _SectionHeader(text: "Feb 28"),
          const _TimelineItem(title: "Lunch: 牛肉面", subtitle: "meal"),
          const _TimelineItem(title: "Expense ¥13", subtitle: "food"),
          const _TimelineItem(title: "Mood: frustrated", subtitle: "mood"),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.divider),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

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
          Expanded(child: Text(title)),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
