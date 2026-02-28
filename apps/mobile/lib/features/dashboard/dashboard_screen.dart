import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../core/constants.dart";

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InsightTile(
            title: "本月支出",
            value: "¥0",
            onTap: () => _jumpToChat(context, "给我本月支出统计"),
          ),
          _InsightTile(
            title: "任务",
            value: "今日 0 · 逾期 0",
            onTap: () => _jumpToChat(context, "我今天有什么任务"),
          ),
          _InsightTile(
            title: "情绪",
            value: "趋势 -",
            onTap: () => _jumpToChat(context, "我最近7天情绪趋势"),
          ),
          _InsightTile(
            title: "记录",
            value: "日志 0",
            onTap: () => _jumpToChat(context, "给我最近的记录"),
          ),
        ],
      ),
    );
  }

  void _jumpToChat(BuildContext context, String text) {
    context.go("/chat", extra: {"prefill": text});
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.title, required this.value, required this.onTap});

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        title: Text(title),
        trailing: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        onTap: onTap,
      ),
    );
  }
}
