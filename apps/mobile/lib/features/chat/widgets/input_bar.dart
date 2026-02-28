import "package:flutter/material.dart";

import "../../../core/constants.dart";

class InputBar extends StatelessWidget {
  const InputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.loading,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.add_circle_outline),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(hintText: "输入内容"),
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: loading ? null : onSend,
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: Text(loading ? "..." : "发送"),
          ),
        ],
      ),
    );
  }
}
