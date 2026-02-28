import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../core/constants.dart";
import "../../core/time.dart";
import "../../data/api/dto.dart";
import "chat_controller.dart";
import "widgets/card_edit_sheet.dart";
import "widgets/card_renderer.dart";
import "widgets/confirm_bar.dart";
import "widgets/input_bar.dart";
import "widgets/message_bubble.dart";

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _lastPrefill;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is Map && extra["prefill"] is String) {
      final text = extra["prefill"] as String;
      if (text != _lastPrefill) {
        _controller.text = text;
        _lastPrefill = text;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    final notifier = ref.read(chatControllerProvider.notifier);
    ref.listen<ChatState>(chatControllerProvider, (prev, next) {
      if (prev?.undoToken != next.undoToken && next.undoToken != null) {
        _showUndoSnack(context);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("Assistant"),
        actions: [
          IconButton(
            onPressed: () => _openNotifications(context),
            icon: _BadgeIcon(
              icon: Icons.notifications_none,
              showDot: state.drafts.isNotEmpty,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
                for (final message in state.messages) MessageBubble(message: message),
                if (state.clarifyQuestion != null) _ClarifyBlock(text: state.clarifyQuestion!),
                if (state.cards.isNotEmpty)
                  ...state.cards.map((card) => _buildCard(card, notifier)),
                if (state.status != null) _StatusLine(text: state.status!),
              ],
            ),
          ),
          ConfirmBar(
            count: state.drafts.length,
            onConfirmAll: () => notifier.confirmDrafts(
              state.drafts.map((d) => d.draftId).toList(),
            ),
          ),
          InputBar(
            controller: _controller,
            loading: state.loading,
            onSend: () {
              final text = _controller.text.trim();
              _controller.clear();
              notifier.sendText(text);
            },
          ),
        ],
      ),
      floatingActionButton: state.undoToken == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                notifier.undo();
              },
              label: const Text("撤销"),
              icon: const Icon(Icons.undo),
              backgroundColor: AppColors.danger,
            ),
    );
  }

  Widget _buildCard(CardDto card, ChatController notifier) {
    final taskId = _extractTaskId(card);
    return CardRenderer(
      card: card,
      onConfirm: () => notifier.confirmDrafts([card.cardId]),
      onEdit: () => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => CardEditSheet(
          card: card,
          onSubmit: (patch) => notifier.editDraft(card.cardId, patch),
        ),
      ),
      onComplete: card.type == "task" && card.status != "draft" && taskId != null
          ? () => notifier.taskAction(taskId: taskId, op: "complete")
          : null,
      onPostpone: card.type == "task" && card.status != "draft" && taskId != null
          ? () => _postponeTask(taskId, notifier)
          : null,
      onDelete: card.type == "task" && card.status != "draft" && taskId != null
          ? () => notifier.taskAction(taskId: taskId, op: "delete")
          : null,
    );
  }

  void _openNotifications(BuildContext context) {
    context.push("/notifications");
  }

  void _showUndoSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("已提交，可在 10 分钟内撤销"),
        duration: Duration(seconds: 3),
      ),
    );
  }

  int? _extractTaskId(CardDto card) {
    final value = card.data["task_id"];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  Future<void> _postponeTask(int taskId, ChatController notifier) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    notifier.taskAction(
      taskId: taskId,
      op: "postpone",
      payload: {"due_at": toIsoWithOffset(dt)},
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.icon, required this.showDot});

  final IconData icon;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (showDot)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _ClarifyBlock extends StatelessWidget {
  const _ClarifyBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text("需要补充：$text"),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
