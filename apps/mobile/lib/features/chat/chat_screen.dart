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
  Uint8List? _selectedImageBytes;
  String? _selectedImageBase64;
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

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

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = "${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a";
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
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageBase64 = base64String;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("选择图片失败: $e")),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageBase64 = null;
    });
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
                for (final message in state.messages)
                  MessageBubble(message: message),
                if (state.clarifyQuestion != null)
                  _ClarifyBlock(text: state.clarifyQuestion!),
                if (state.cards.isNotEmpty)
                  ...state.cards.map((card) => _buildCard(card, notifier)),
                if (state.status != null) _StatusLine(text: state.status!),
                if (state.hasError && state.lastFailedRequest != null)
                  ErrorBanner(
                    message: state.status ?? "请求失败",
                    onRetry: () => notifier.retry(),
                  ),
                if (state.undoToken != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Align(
                      alignment: Alignment.center,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          backgroundColor: AppColors.danger.withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          notifier.undo();
                        },
                        icon: const Icon(Icons.undo, size: 18),
                        label: const Text("撤销刚才的记录"),
                      ),
                    ),
                  ),
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
            isRecording: _isRecording,
            selectedImage: _selectedImageBytes,
            onPickImage: _pickImage,
            onRemoveImage: _removeImage,
            onStartRecord: _startRecording,
            onStopRecord: () => _stopRecording(notifier),
            onSend: () {
              final text = _controller.text.trim();
              final imageBase64 = _selectedImageBase64;
              if (text.isEmpty && imageBase64 == null) return;

              _controller.clear();
              _removeImage();
              notifier.sendText(
                  text: text.isEmpty ? null : text, imageBase64: imageBase64);
            },
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
