import "dart:convert";
import "dart:typed_data";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:image_picker/image_picker.dart";
import "package:path_provider/path_provider.dart";
import "package:record/record.dart";

import "../../core/constants.dart";
import "../../core/time.dart";
import "../../data/api/dto.dart";
import "../../shared/widgets/error_banner.dart";
import "chat_controller.dart";
import "widgets/card_edit_sheet.dart";
import "widgets/card_renderer.dart";
import "widgets/confirm_bar.dart";
import "widgets/input_bar.dart";
import "widgets/message_bubble.dart";
import "widgets/typing_indicator.dart";

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _lastPrefill;
  final ImagePicker _picker = ImagePicker();
  List<Uint8List> _selectedImageBytes = [];
  List<String> _selectedImageBase64 = [];
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _sendingLock = false;
  bool _shouldAutoScroll = true;
  int _lastMessageCount = 0;

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
    _audioRecorder.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent + 120;
    if (jump) {
      _scrollController.jumpTo(target);
    } else {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path =
            "${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a";
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
          path: path,
        );
        setState(() {
          _isRecording = true;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("录音需要麦克风权限")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("录音失败: $e")),
      );
    }
  }

  Future<void> _stopRecording(ChatController notifier) async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      if (path != null) {
        final bytes = await XFile(path).readAsBytes();
        final base64String = base64Encode(bytes);
        notifier.sendText(audioBase64: base64String);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("处理录音失败: $e")),
      );
    }
  }

  Future<void> _pickImage() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      List<XFile> images = [];
      if (source == ImageSource.gallery) {
        images = await _picker.pickMultiImage(
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );
      } else {
        final single = await _picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );
        if (single != null) images = [single];
      }
      if (images.isEmpty) return;
      final bytesList = <Uint8List>[];
      final base64List = <String>[];
      for (final image in images) {
        final bytes = await image.readAsBytes();
        bytesList.add(bytes);
        base64List.add(base64Encode(bytes));
      }
      setState(() {
        _selectedImageBytes = bytesList;
        _selectedImageBase64 = base64List;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("选择图片失败: $e")),
      );
    }
  }

  void _removeImageAt(int index) {
    setState(() {
      if (index >= 0 && index < _selectedImageBytes.length) {
        _selectedImageBytes.removeAt(index);
        _selectedImageBase64.removeAt(index);
      }
    });
  }

  void _clearImages() {
    setState(() {
      _selectedImageBytes = [];
      _selectedImageBase64 = [];
    });
  }

  Future<void> _handleSend(ChatController notifier) async {
    if (_sendingLock) return;
    final text = _controller.text.trim();
    final imageBase64 = _selectedImageBase64;
    if (text.isEmpty && imageBase64.isEmpty) return;

    setState(() => _sendingLock = true);
    _controller.clear();
    _clearImages();
    _shouldAutoScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(jump: true);
    });
    notifier.sendText(
      text: text.isEmpty ? null : text,
      imageBase64: imageBase64.isEmpty ? null : imageBase64,
    );
    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    setState(() => _sendingLock = false);
  }

  void _showMoreMenu(BuildContext context, ChatController notifier) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.dashboard_outlined),
                title: const Text("Dashboard"),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.go("/dashboard");
                },
              ),
              ListTile(
                leading: const Icon(Icons.timeline),
                title: const Text("Timeline"),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.go("/timeline");
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_box_outlined),
                title: const Text("Tasks"),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.go("/tasks");
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text("Me"),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.go("/me");
                },
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.clear_all, color: AppColors.danger),
                title: const Text('清空当前上下文',
                    style: TextStyle(color: AppColors.danger)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  notifier.clearSession();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已清空当前聊天记忆')),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    final notifier = ref.read(chatControllerProvider.notifier);
    ref.listen<ChatState>(chatControllerProvider, (prev, next) {
      if (_lastMessageCount != next.messages.length) {
        _lastMessageCount = next.messages.length;
        if (_shouldAutoScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      }
    });

    final hasMessages = state.messages.isNotEmpty;

    return Scaffold(
      body: Column(
        children: [
          _Header(
            onNotifications: () => _openNotifications(context),
            onMore: () => _showMoreMenu(context, notifier),
            showDot: state.drafts.isNotEmpty,
            compact: hasMessages,
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  final metrics = notification.metrics;
                  final isNearBottom = metrics.extentAfter < 120;
                  _shouldAutoScroll = isNearBottom;
                }
                return false;
              },
              child: ListView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(16, hasMessages ? 8 : 12, 16, 16),
                children: [
                  if (!hasMessages)
                    _WelcomeSection(
                      onSuggestion: (text) {
                        _controller.text = text;
                        _controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: _controller.text.length),
                        );
                      },
                    ),
                  for (var i = 0; i < state.messages.length; i++)
                    Builder(
                      builder: (_) {
                        final message = state.messages[i];
                        final prevRole =
                            i > 0 ? state.messages[i - 1].role : null;
                        final nextRole = i < state.messages.length - 1
                            ? state.messages[i + 1].role
                            : null;
                        final mergeTop = prevRole == message.role;
                        final mergeBottom = nextRole == message.role;
                        final hasCards =
                            message.cards != null && message.cards!.isNotEmpty;
                        final cardsColumn = hasCards
                            ? Column(
                                children: message.cards!
                                    .map((c) => _buildCard(c, notifier))
                                    .toList(),
                              )
                            : null;
                        return MessageBubble(
                          message: message,
                          compactTop: mergeTop,
                          mergeTop: mergeTop,
                          mergeBottom: mergeBottom,
                          bottom: hasCards
                              ? _DelayedReveal(
                                  delay: const Duration(milliseconds: 140),
                                  child: cardsColumn!,
                                )
                              : null,
                        );
                      },
                    ),
                  if (state.loading)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: TypingIndicator(),
                    ),
                  if (state.clarifyQuestion != null)
                    _ClarifyBlock(text: state.clarifyQuestion!),
                  if (state.status != null) _StatusLine(text: state.status!),
                  if (state.hasError && state.lastFailedRequest != null)
                    ErrorBanner(
                      message: state.status ?? "请求失败",
                      onRetry: () => notifier.retry(),
                    ),
                ],
              ),
            ),
          ),
          AnimatedSlide(
            duration: const Duration(milliseconds: 250),
            offset:
                state.drafts.length > 1 ? Offset.zero : const Offset(0, 0.2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: state.drafts.length > 1 ? 1 : 0,
              child: ConfirmBar(
                count: state.drafts.length,
                onConfirmAll: () => notifier.confirmDrafts(
                  state.drafts.map((d) => d.draftId).toList(),
                ),
              ),
            ),
          ),
          InputBar(
            controller: _controller,
            loading: state.loading || _sendingLock,
            isRecording: _isRecording,
            selectedImages: _selectedImageBytes,
            onPickImage: _pickImage,
            onRemoveImageAt: _removeImageAt,
            onStartRecord: _startRecording,
            onStopRecord: () => _stopRecording(notifier),
            onSend: () => _handleSend(notifier),
          ),
        ],
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
      onComplete:
          card.type == "task" && card.status != "draft" && taskId != null
              ? () => notifier.taskAction(taskId: taskId, op: "complete")
              : null,
      onPostpone:
          card.type == "task" && card.status != "draft" && taskId != null
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

  // 撤销提示已移动至 Timeline

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
    if (!mounted) return;
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (!mounted) return;
    if (time == null) return;
    final dt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 14, color: AppColors.success),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onNotifications,
    required this.onMore,
    required this.showDot,
    required this.compact,
  });

  final VoidCallback onNotifications;
  final VoidCallback onMore;
  final bool showDot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(16, compact ? 10 : 14, 16, compact ? 6 : 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Assistant",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 4),
                    Text(
                      "说句话，我来帮你记录、整理和提醒",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: onNotifications,
              icon: _BadgeIcon(
                icon: Icons.notifications_none,
                showDot: showDot,
              ),
            ),
            IconButton(
              onPressed: onMore,
              icon: const Icon(Icons.more_horiz),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeSection extends StatelessWidget {
  const _WelcomeSection({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.accentLight,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.auto_awesome, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "今天想从哪件事开始？",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SuggestionChip(
                  label: "记一笔支出",
                  onTap: () => onSuggestion("我今天花了50元买咖啡"),
                ),
                _SuggestionChip(
                  label: "添加一个任务",
                  onTap: () => onSuggestion("提醒我明天上午10点开会"),
                ),
                _SuggestionChip(
                  label: "记录今天心情",
                  onTap: () => onSuggestion("我今天心情不错，挺开心"),
                ),
                _SuggestionChip(
                  label: "写一条生活记录",
                  onTap: () => onSuggestion("今天去跑步了，感觉很放松"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
              ),
        ),
      ),
    );
  }
}

class _DelayedReveal extends StatefulWidget {
  const _DelayedReveal({
    required this.child,
    this.delay = const Duration(milliseconds: 120),
  });

  final Widget child;
  final Duration delay;

  @override
  State<_DelayedReveal> createState() => _DelayedRevealState();
}

class _DelayedRevealState extends State<_DelayedReveal> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        offset: _visible ? Offset.zero : const Offset(0, 0.03),
        child: widget.child,
      ),
    );
  }
}
