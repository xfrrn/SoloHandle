import "dart:typed_data";
import "package:flutter/material.dart";

import "../../../core/constants.dart";

class InputBar extends StatelessWidget {
  const InputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.loading,
    this.selectedImages = const [],
    this.isRecording = false,
    this.onPickImage,
    this.onRemoveImageAt,
    this.onStartRecord,
    this.onStopRecord,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool loading;
  final bool isRecording;
  final List<Uint8List> selectedImages;
  final VoidCallback? onPickImage;
  final ValueChanged<int>? onRemoveImageAt;
  final VoidCallback? onStartRecord;
  final VoidCallback? onStopRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          )
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectedImages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 44),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < selectedImages.length; i++)
                      _ImagePreview(
                        bytes: selectedImages[i],
                        onRemove: () => onRemoveImageAt?.call(i),
                      ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: loading ? null : onPickImage,
                  icon: const Icon(Icons.add_circle),
                  color: AppColors.textSecondary,
                  iconSize: 28,
                  padding: const EdgeInsets.only(bottom: 10),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isRecording
                          ? AppColors.danger.withOpacity(0.08)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: isRecording
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                RecordingWave(),
                                SizedBox(width: 8),
                                Icon(Icons.mic,
                                    color: AppColors.danger, size: 20),
                                SizedBox(width: 8),
                                Text("正在录音...",
                                    style: TextStyle(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          )
                        : TextField(
                            controller: controller,
                            minLines: 1,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: "和助理说话...",
                              hintStyle: TextStyle(color: AppColors.textSecondary),
                              border: InputBorder.none,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, child) {
                      final hasText = value.text.trim().isNotEmpty;
                      final isSendMode = hasText || selectedImages.isNotEmpty;

                      if (isSendMode) {
                        return PressableScale(
                          onTap: loading ? null : onSend,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: loading
                                  ? AppColors.divider
                                  : AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                            child: loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.send_rounded,
                                    color: Colors.white, size: 20),
                          ),
                        );
                      }

                      return PressableScale(
                        onTap: loading
                            ? null
                            : () {
                                if (isRecording) {
                                  onStopRecord?.call();
                                } else {
                                  onStartRecord?.call();
                                }
                              },
                        onLongPressStart:
                            loading ? null : (_) => onStartRecord?.call(),
                        onLongPressEnd:
                            loading ? null : (_) => onStopRecord?.call(),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isRecording ? AppColors.danger : AppColors.divider,
                            shape: BoxShape.circle,
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : Icon(Icons.mic,
                                  color: isRecording ? Colors.white : AppColors.textPrimary, size: 20),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.bytes, required this.onRemove});

  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            image: DecorationImage(
              image: MemoryImage(bytes),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          right: -6,
          top: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  final Widget child;
  final VoidCallback? onTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onLongPressStart: widget.onLongPressStart,
      onLongPressEnd: widget.onLongPressEnd,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.95 : 1.0,
        child: widget.child,
      ),
    );
  }
}

class RecordingWave extends StatefulWidget {
  const RecordingWave({super.key});

  @override
  State<RecordingWave> createState() => _RecordingWaveState();
}

class _RecordingWaveState extends State<RecordingWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final heights = [
          6 + 6 * (0.5 + 0.5 * (1 - (t - 0.1).abs() * 2)).clamp(0, 1),
          6 + 10 * (0.5 + 0.5 * (1 - (t - 0.5).abs() * 2)).clamp(0, 1),
          6 + 8 * (0.5 + 0.5 * (1 - (t - 0.85).abs() * 2)).clamp(0, 1),
        ];
        return Row(
          children: heights
              .map(
                (h) => Container(
                  width: 3,
                  height: h.toDouble(),
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
