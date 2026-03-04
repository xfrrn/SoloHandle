import "dart:convert";
import "package:flutter/material.dart";

import "../../../core/constants.dart";
import "../chat_controller.dart";

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = isUser ? AppColors.surface : const Color(0xFFF2F2F2);
    final textColor = AppColors.textPrimary;

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isUser ? null : AppColors.assistantBubble,
          gradient: isUser
              ? const LinearGradient(
                  colors: [
                    AppColors.userBubbleGradientStart,
                    AppColors.userBubbleGradientEnd,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          boxShadow: isUser
              ? [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser
              ? null
              : Border.all(color: AppColors.assistantBubbleBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.imageBytes != null)
              Padding(
                padding:
                    EdgeInsets.only(bottom: message.text != null ? 8.0 : 0.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(message.imageBytes!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (message.text != null)
              Text(
                message.text!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isUser
                          ? AppColors.userBubbleText
                          : AppColors.textPrimary,
                      height: 1.4,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
