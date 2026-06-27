import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/infrastructure/media/network_image_policy.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/media_viewer/image_preview_modal.dart';
import 'package:flare_im/interface/widgets/message/message_style.dart';
import 'package:flare_im/interface/widgets/message/views/media_inline.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

// 图片消息：底栏尺寸与时间；可选说明与己方状态徽标。
class ImageView extends StatelessWidget {
  final String url;
  final int? width;
  final int? height;
  final int? sizeBytes;
  final String? caption;
  final bool isSelf;
  final MessageStatus? messageStatus;
  final String? footerTimeText;

  const ImageView({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.sizeBytes,
    this.caption,
    required this.isSelf,
    this.messageStatus,
    this.footerTimeText,
  });

  static const double _maxDisplayWidth = 240;
  static const double _defaultDisplayHeight = 168;

  static String _formatOriginalLabel(int? bytes) {
    if (bytes == null || bytes <= 0) return '原图';
    if (bytes < 1024) return '原图 ${bytes}B';
    if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      final s = kb < 10 ? kb.toStringAsFixed(1) : kb.toStringAsFixed(0);
      return '原图 ${s}KB';
    }
    final mb = bytes / (1024 * 1024);
    final s = mb < 10 ? mb.toStringAsFixed(1) : mb.toStringAsFixed(0);
    return '原图 ${s}MB';
  }

  @override
  Widget build(BuildContext context) {
    final capTrim = caption?.trim();
    final captionText = (capTrim != null && capTrim.isNotEmpty)
        ? capTrim
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : _maxDisplayWidth;
        final displayW = maxW.clamp(120.0, _maxDisplayWidth);
        final ratio = (width != null && height != null && width! > 0)
            ? height! / width!
            : null;
        final displayH = ratio != null
            ? (displayW * ratio).clamp(100.0, 280.0)
            : _defaultDisplayHeight;

        if (captionText != null) {
          return _captionLayout(
            context,
            displayW: displayW,
            displayH: displayH,
            captionText: captionText,
          );
        }
        return _footerBarLayout(
          context,
          displayW: displayW,
          displayH: displayH,
        );
      },
    );
  }

  Widget _captionLayout(
    BuildContext context, {
    required double displayW,
    required double displayH,
    required String captionText,
  }) {
    final fg = isSelf
        ? MessageBubbleStyle.selfBubbleForeground(context)
        : MessageBubbleStyle.otherBubbleForeground(context);
    final meta = _metaColor(context);
    final r = MessageBubbleStyle.bubbleRadius(context);

    return SizedBox(
      width: displayW,
      child: Container(
        width: displayW,
        decoration: MessageBubbleStyle.bubbleDecoration(
          context,
          isSelf: isSelf,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(r),
                    topRight: Radius.circular(r),
                  ),
                  child: GestureDetector(
                    onTap: () => ImagePreviewModal.show(context, imageUrl: url),
                    child: SizedBox(
                      width: displayW,
                      height: displayH,
                      child: _imageBody(context, displayW, displayH),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 10, isSelf ? 88 : 12, 10),
                  child: Text(
                    captionText,
                    style: TextStyle(
                      color: fg,
                      fontSize: FlareImDesign.messageBubbleFontSize,
                      height: FlareImDesign.messageBubbleTextHeight,
                    ),
                  ),
                ),
              ],
            ),
            if (isSelf && messageStatus != null)
              Positioned(
                right: 10,
                bottom: 10,
                child: _captionStatusBadge(
                  context,
                  meta: meta,
                  timeText: footerTimeText,
                  status: messageStatus!,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _footerBarLayout(
    BuildContext context, {
    required double displayW,
    required double displayH,
  }) {
    final footerBg = _footerBarBackground(context);
    final footerFg = _footerBarForeground(context);
    final meta = _metaColor(context);

    return SizedBox(
      width: displayW,
      child: Container(
        width: displayW,
        decoration: MessageBubbleStyle.bubbleDecoration(
          context,
          isSelf: isSelf,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: () => ImagePreviewModal.show(context, imageUrl: url),
              child: SizedBox(
                width: displayW,
                height: displayH,
                child: _imageBody(context, displayW, displayH),
              ),
            ),
            Container(
              width: displayW,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: footerBg,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatOriginalLabel(sizeBytes),
                      style: TextStyle(
                        color: footerFg,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelf) ...[
                    if (footerTimeText != null &&
                        footerTimeText!.isNotEmpty) ...[
                      Text(
                        footerTimeText!,
                        style: TextStyle(
                          color: footerFg.withValues(alpha: 0.92),
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    _inlineStatus(context, meta: meta, status: messageStatus),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _footerBarBackground(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (isSelf) {
      return dark
          ? Colors.black.withValues(alpha: 0.22)
          : Colors.black.withValues(alpha: 0.14);
    }
    return dark
        ? Colors.white.withValues(alpha: 0.06)
        : FlareThemeTokens.bgTertiary;
  }

  Color _footerBarForeground(BuildContext context) {
    if (isSelf) {
      return MessageBubbleStyle.selfBubbleForeground(
        context,
      ).withValues(alpha: 0.95);
    }
    return MessageBubbleStyle.otherBubbleForeground(context);
  }

  Color _metaColor(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return FlareDarkThemeTokens.textSecondary.withValues(alpha: 0.95);
    }
    return isSelf
        ? FlareImDesign.messageBubbleSenderMeta
        : FlareImDesign.messageBubbleReceiverMeta;
  }

  Widget _imageBody(BuildContext context, double w, double h) {
    if (isLocalFileLikePath(url)) {
      final path = url.startsWith('file://')
          ? Uri.parse(url).toFilePath()
          : url;
      return Image.file(
        File(path),
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => MediaInlineUnsupported(
          width: w,
          height: h,
          icon: Icons.broken_image_outlined,
          label: '图片加载失败',
        ),
      );
    }
    if (!isHttpOrHttpsUrl(url)) {
      return MediaInlineUnsupported(
        width: w,
        height: h,
        icon: Icons.hide_image_outlined,
        label: '无法显示本地路径图片',
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: w,
      height: h,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        width: w,
        height: h,
        color: FlareThemeTokens.messageMediaPlaceholderBg,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => Container(
        width: w,
        height: h,
        color: FlareThemeTokens.messageMediaPlaceholderBg,
        child: const Icon(
          Icons.error_outline,
          color: FlareThemeTokens.textSecondary,
        ),
      ),
    );
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
        return const SizedBox.shrink();
    }
  }

  Widget _captionStatusBadge(
    BuildContext context, {
    required Color meta,
    required String? timeText,
    required MessageStatus status,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (timeText != null && timeText.isNotEmpty) ...[
              Text(
                timeText,
                style: TextStyle(
                  color: meta,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 5),
            ],
            _inlineStatus(context, meta: meta, status: status),
          ],
        ),
      ),
    );
  }
}
