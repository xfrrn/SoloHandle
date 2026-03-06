import "dart:typed_data";
import "package:flutter/material.dart";

import "../../../core/constants.dart";

class InputBar extends StatelessWidget {
  const InputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.loading,
    this.selectedImage,
    this.isRecording = false,
    this.onPickImage,
    this.onRemoveImage,
    this.onStartRecord,
    this.onStopRecord,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool loading;
  final bool isRecording;
  final Uint8List? selectedImage;
  final VoidCallback? onPickImage;
  final VoidCallback? onRemoveImage;
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
            if (selectedImage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 44),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: MemoryImage(selectedImage!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -8,
                      top: -8,
                      child: GestureDetector(
                        onTap: onRemoveImage,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
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
                      color: isRecording ? AppColors.danger.withOpacity(0.1) : AppColors.background,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: isRecording
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.mic, color: AppColors.danger, size: 20),
                                SizedBox(width: 8),
                                Text("正在录音...", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w500)),
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
                      final isSendMode = hasText || selectedImage != null;

                      if (isSendMode) {
                        return InkWell(
                          onTap: loading ? null : onSend,
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: loading ? AppColors.divider : AppColors.accent,
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

                      return GestureDetector(
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
