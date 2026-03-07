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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.88),
            border: Border(
              top: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectedImages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 44, bottom: 8),
                    child: SizedBox(
                      height: 72,
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isRecording
                        ? AppColors.danger.withValues(alpha: 0.08)
                        : AppColors.background.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _RoundIconButton(
                        onTap: loading ? null : onPickImage,
                        icon: Icons.add,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: isRecording
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 9),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    RecordingWave(),
                                    SizedBox(width: 8),
                                    Icon(Icons.mic,
                                        color: AppColors.danger, size: 18),
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
                            : TextField(
                                controller: controller,
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: TextInputAction.newline,
                                decoration: const InputDecoration(
                                  hintText: "和助理说话...",
                                  hintStyle:
                                      TextStyle(color: AppColors.textSecondary),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (context, value, _) {
                          final hasText = value.text.trim().isNotEmpty;
                          final isSendMode =
                              hasText || selectedImages.isNotEmpty;
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: isSendMode
                                ? _RoundIconButton(
                                    key: const ValueKey("send"),
                                    onTap: loading ? null : onSend,
                                    icon: Icons.arrow_upward_rounded,
                                    primary: true,
                                    loading: loading,
                                  )
                                : _RoundIconButton(
                                    key: const ValueKey("mic"),
                                    onTap: loading
                                        ? null
                                        : () {
                                            if (isRecording) {
                                              onStopRecord?.call();
                                            } else {
                                              onStartRecord?.call();
                                            }
                                          },
                                    onLongPressStart: loading
                                        ? null
                                        : (_) => onStartRecord?.call(),
                                    onLongPressEnd: loading
                                        ? null
                                        : (_) => onStopRecord?.call(),
                                    icon: Icons.mic,
                                    danger: isRecording,
                                  ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    super.key,
    required this.onTap,
    required this.icon,
    this.primary = false,
    this.danger = false,
    this.loading = false,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  final VoidCallback? onTap;
  final IconData icon;
  final bool primary;
  final bool danger;
  final bool loading;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    Color bg = AppColors.surface;
    Color fg = AppColors.textPrimary;
    BorderSide side = const BorderSide(color: AppColors.divider);
    if (primary) {
      bg = loading ? AppColors.divider : AppColors.accent;
      fg = Colors.white;
      side = BorderSide.none;
    } else if (danger) {
      bg = AppColors.danger;
      fg = Colors.white;
      side = BorderSide.none;
    }

    return PressableScale(
      onTap: onTap,
      onLongPressStart: onLongPressStart,
      onLongPressEnd: onLongPressEnd,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.fromBorderSide(side),
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
            : Icon(icon, size: 18, color: fg),
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
