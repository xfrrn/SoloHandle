import "dart:typed_data";
import "dart:ui";
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
    this.onChanged,
    this.topContent,
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
  final ValueChanged<String>? onChanged;
  final Widget? topContent;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 4, 12, 7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (topContent != null) ...[
            topContent!,
            const SizedBox(height: 8),
          ],
          if (selectedImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 18, bottom: 8),
              child: SizedBox(
                height: 66,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: selectedImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => _ImagePreview(
                    bytes: selectedImages[i],
                    onRemove: () => onRemoveImageAt?.call(i),
                  ),
                ),
              ),
            ),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFF0F0F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    PressableScale(
                      onTap: loading ? null : onPickImage,
                      child: const SizedBox(
                        width: 30,
                        height: 30,
                        child: Icon(
                          Icons.add,
                          size: 26,
                          color: Color(0xFF111111),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: isRecording
                          ? const SizedBox(
                              height: 34,
                              child: Row(
                                children: [
                                  RecordingWave(),
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.mic,
                                    color: AppColors.danger,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "正在录音...",
                                    style: TextStyle(
                                      color: AppColors.danger,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 120),
                              child: TextField(
                                controller: controller,
                                onChanged: onChanged,
                                minLines: 1,
                                maxLines: 5,
                                textInputAction: TextInputAction.newline,
                                decoration: const InputDecoration(
                                  hintText: "问问助手",
                                  hintStyle: TextStyle(
                                    color: Color(0xFF9A9A9A),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    PressableScale(
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
                      child: Icon(
                        Icons.mic_none_rounded,
                        size: 30,
                        color: isRecording
                            ? AppColors.danger
                            : const Color(0xFF8F8F8F),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        final hasText = value.text.trim().isNotEmpty;
                        final isSendMode = hasText || selectedImages.isNotEmpty;
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: _RoundIconButton(
                            key: ValueKey(isSendMode ? "send" : "voice"),
                            onTap: loading
                                ? null
                                : () {
                                    if (isSendMode) {
                                      onSend();
                                    } else if (isRecording) {
                                      onStopRecord?.call();
                                    } else {
                                      onStartRecord?.call();
                                    }
                                  },
                            onLongPressStart: (!loading && !isSendMode)
                                ? (_) => onStartRecord?.call()
                                : null,
                            onLongPressEnd: (!loading && !isSendMode)
                                ? (_) => onStopRecord?.call()
                                : null,
                            icon: isSendMode
                                ? Icons.arrow_upward_rounded
                                : Icons.graphic_eq,
                            loading: loading && isSendMode,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    super.key,
    required this.onTap,
    required this.icon,
    this.loading = false,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  final VoidCallback? onTap;
  final IconData icon;
  final bool loading;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      onLongPressStart: onLongPressStart,
      onLongPressEnd: onLongPressEnd,
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          shape: BoxShape.circle,
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              )
            : Icon(icon, size: 18, color: Colors.white),
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
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
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
