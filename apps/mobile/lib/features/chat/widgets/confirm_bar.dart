import "package:flutter/material.dart";

import "../../../core/constants.dart";

class ConfirmBar extends StatelessWidget {
  const ConfirmBar(
      {super.key, required this.count, required this.onConfirmAll});

  final int count;
  final VoidCallback onConfirmAll;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
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
