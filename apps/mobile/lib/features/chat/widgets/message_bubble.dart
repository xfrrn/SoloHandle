import "dart:convert";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../../core/constants.dart";
import "../chat_controller.dart";

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.bottom,
  });

  final ChatMessage message;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = isUser ? AppColors.surface : const Color(0xFFF2F2F2);
    final textColor = AppColors.textPrimary;
    final maxWidth = MediaQuery.of(context).size.width * 0.78;

    final bubble = Align(
      alignment: align,
      child: GestureDetector(
        onLongPress: () => _showMessageMenu(context, message),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 12),
                child: child,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(maxWidth: maxWidth),
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
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      )
                    ],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 6),
                bottomRight: Radius.circular(isUser ? 6 : 16),
              ),
              border: isUser
                  ? null
                  : Border.all(color: AppColors.assistantBubbleBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.imageBytes != null &&
                    message.imageBytes!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(
                        bottom: message.text != null ? 8.0 : 0.0),
                    child: _ImageGrid(
                      images: message.imageBytes!,
                      isUser: isUser,
                    ),
                  ),
                if (message.text != null)
                  _ExpandableText(
                    text: message.text!,
                    textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isUser
                              ? AppColors.userBubbleText
                              : AppColors.textPrimary,
                          height: 1.4,
                        ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (bottom == null) return bubble;
    
    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        bubble,
        bottom!,
      ],
    );
  }

  void _showMessageMenu(BuildContext context, ChatMessage message) {
    final text = message.text ?? "";
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_all),
              title: const Text("复制"),
              onTap: () {
                if (text.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: text));
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("已复制")),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text("转发"),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("已加入转发队列")),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text("删除"),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("删除操作未实现")),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_border),
              title: const Text("收藏"),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("已收藏")),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text, this.textStyle});

  final String text;
  final TextStyle? textStyle;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    const int limit = 180;
    final text = widget.text;
    final shouldCollapse = text.length > limit;
    final display = (!shouldCollapse || _expanded)
        ? text
        : "${text.substring(0, limit)}...";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(display, style: widget.textStyle),
        if (shouldCollapse)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(_expanded ? "收起" : "展开全文"),
          ),
      ],
    );
  }
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.images, required this.isUser});

  final List<String> images;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final count = images.length;
    final crossAxisCount = count <= 2 ? 2 : 3;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: GestureDetector(
            onTap: () => _openImage(context, images, index),
            child: Image.memory(
              base64Decode(images[index]),
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  void _openImage(BuildContext context, List<String> images, int index) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: PageView.builder(
          controller: PageController(initialPage: index),
          itemCount: images.length,
          itemBuilder: (context, i) {
            return InteractiveViewer(
              child: Image.memory(
                base64Decode(images[i]),
                fit: BoxFit.contain,
              ),
            );
          },
        ),
      ),
    );
  }
}
