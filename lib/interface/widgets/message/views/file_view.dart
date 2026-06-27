import 'dart:math' as math;

import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/message/message_style.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

// 文件消息。
///
/// 参考设计：白底圆角描边气泡，左侧浅蓝圆角图标区，文件名 + 下行「大小 | 时间·状态」。
class FileView extends StatelessWidget {
  final String? url;
  final String? localPath;
  final String filename;
  final int? size;
  final String? messageId;
  final bool isSelf;
  final MessageStatus? messageStatus;
  final String? footerTimeText;

  const FileView({
    super.key,
    this.url,
    this.localPath,
    required this.filename,
    this.size,
    this.messageId,
    required this.isSelf,
    this.messageStatus,
    this.footerTimeText,
  });

  static const double _iconBox = 52;

  @override
  Widget build(BuildContext context) {
    final bg = isSelf
        ? MessageBubbleStyle.selfBubbleBackground(context)
        : MessageBubbleStyle.otherBubbleBackground(context);
    final fg = isSelf
        ? MessageBubbleStyle.selfBubbleForeground(context)
        : MessageBubbleStyle.otherBubbleForeground(context);
    final border = MessageBubbleStyle.bubbleBorder(context, isSelf: isSelf);
    final r = MessageBubbleStyle.bubbleRadius(context);
    final secondary = fg.withValues(alpha: isSelf ? 0.85 : 0.65);
    final iconBg = isSelf
        ? Colors.white.withValues(alpha: 0.22)
        : const Color(0xFFE8F1FF);
    final iconFg = isSelf ? Colors.white : FlareThemeTokens.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cap = FlareImDesign.messageBubbleMaxWidthForScreen(
          context,
          isSelf: isSelf,
        );
        final parentMax = constraints.maxWidth;
        final maxW = parentMax.isFinite && parentMax > 0
            ? math.min(parentMax, cap)
            : cap;
        final minW = math.min(FlareImDesign.messageBubbleMinWidth, maxW);

        return ConstrainedBox(
          constraints: BoxConstraints(minWidth: minW, maxWidth: maxW),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(r),
              border: Border.all(color: border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: _iconBox,
                  height: _iconBox,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: _fileGlyph(filename, color: iconFg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        filename,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: FlareImDesign.messageBubbleFontSize,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: fg,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _sizeOrPlaceholder(),
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.2,
                                color: secondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelf &&
                              footerTimeText != null &&
                              footerTimeText!.isNotEmpty) ...[
                            Text(
                              footerTimeText!,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.2,
                                color: secondary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _inlineStatus(
                              context,
                              meta: secondary,
                              status: messageStatus,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _sizeOrPlaceholder() {
    if (size != null) return _formatFileSize(size!);
    if ((localPath ?? '').trim().isNotEmpty || (url ?? '').trim().isNotEmpty) {
      return '附件';
    }
    return '文件';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  Widget _fileGlyph(String name, {required Color color}) {
    final ext = name.toLowerCase().split('.').last;
    if (ext == 'pdf') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.picture_as_pdf_outlined, size: 26, color: color),
          Text(
            'PDF',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
        ],
      );
    }
    return Icon(Icons.insert_drive_file_outlined, size: 28, color: color);
  }

  Widget _inlineStatus(
    BuildContext context, {
    required Color meta,
    required MessageStatus? status,
  }) {
    final s = status;
    if (s == null) return const SizedBox.shrink();
    switch (s) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.2, color: meta),
        );
      case MessageStatus.sent:
      case MessageStatus.delivered:
        return Icon(Icons.check, size: 15, color: meta);
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 15, color: meta);
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline,
          size: 15,
          color: FlareThemeTokens.error,
        );
    }
  }
}
