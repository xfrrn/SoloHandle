import "package:flutter/material.dart";

import "../../../core/constants.dart";

class ConfirmBar extends StatelessWidget {
  const ConfirmBar({super.key, required this.count, required this.onConfirmAll});

  final int count;
  final VoidCallback onConfirmAll;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Text("$count 条草稿", style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          TextButton(
            onPressed: onConfirmAll,
            child: const Text("确认全部"),
          ),
        ],
      ),
    );
  }
}
