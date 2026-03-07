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
    this.compactTop = false,
    this.mergeTop = false,
    this.mergeBottom = false,
  });

  final ChatMessage message;
  final Widget? bottom;
  final bool compactTop;
  final bool mergeTop;
  final bool mergeBottom;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final hasImages =
        message.imageBytes != null && message.imageBytes!.isNotEmpty;
    final hasText = message.text != null && message.text!.trim().isNotEmpty;
    final hasMixed = hasImages && hasText;

    final nodes = <Widget>[];
    if (hasImages) {
      nodes.add(
        _buildImageBubble(
          context: context,
          alignment: align,
          images: message.imageBytes!,
        ),
      );
    }
    if (hasText) {
      if (hasMixed) {
        nodes.add(const SizedBox(height: 6));
      }
      nodes.add(
        _buildTextBubble(
          context: context,
          isUser: isUser,
          alignment: align,
          text: message.text!,
          mergeTop: mergeTop,
          mergeBottom: mergeBottom && bottom == null,
        ),
      );
    }

    if (nodes.isEmpty) {
      return const SizedBox.shrink();
    }

    final content = Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        ...nodes,
        if (bottom != null) ...[
          const SizedBox(height: 6),
          bottom!,
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.only(top: compactTop ? 2 : 6, bottom: 4),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 8),
              child: child,
            ),
          );
        },
        child: content,
      ),
    );
  }

  Widget _buildTextBubble({
    required BuildContext context,
    required bool isUser,
    required Alignment alignment,
    required String text,
    required bool mergeTop,
    required bool mergeBottom,
  }) {
    final maxWidth = MediaQuery.of(context).size.width * 0.78;
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onLongPress: () => _showMessageMenu(context, text),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isUser ? const Color(0xFF2563EB) : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(mergeTop ? 10 : 18),
              topRight: Radius.circular(mergeTop ? 10 : 18),
              bottomLeft: Radius.circular(
                mergeBottom ? 10 : (isUser ? 18 : 8),
              ),
              bottomRight: Radius.circular(
                mergeBottom ? 10 : (isUser ? 8 : 18),
              ),
            ),
            border: isUser ? null : Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isUser ? 0.10 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _ExpandableText(
            text: text,
            textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isUser ? Colors.white : AppColors.textPrimary,
                  height: 1.45,
                ),
            isUser: isUser,
          ),
        ),
      ),
    );
  }

  Widget _buildImageBubble({
    required BuildContext context,
    required Alignment alignment,
    required List<String> images,
  }) {
    final maxWidth = MediaQuery.of(context).size.width * 0.74;
    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _ImageGrid(images: images),
      ),
    );
  }

  void _showMessageMenu(BuildContext context, String text) {
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
  const _ExpandableText({
    required this.text,
    this.textStyle,
    required this.isUser,
  });

  final String text;
  final TextStyle? textStyle;
  final bool isUser;

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
              foregroundColor: widget.isUser
                  ? Colors.white.withValues(alpha: 0.92)
                  : AppColors.accent,
            ),
            child: Text(_expanded ? "收起" : "展开全文"),
          ),
      ],
    );
  }
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    final count = images.length;
    if (count == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: () => _openImage(context, images, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: Image.memory(
              base64Decode(images.first),
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
        ),
      );
    }

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
