import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/infrastructure/media/network_image_policy.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/media_viewer/video_player_modal.dart';
import 'package:flare_im/interface/widgets/message/message_style.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

// 视频消息。
///
/// - 无描述：封面四边圆角，整卡为气泡样式；送达状态由列表在气泡外展示。
/// - 有描述：仅封面上圆角，下接说明行（左文案，右时间 + 状态）。
/// - 有无描述共用同一 [displayW]，外层 [SizedBox] 固定宽度，避免 [Column] intrinsic 导致宽窄不一致。
class VideoView extends StatelessWidget {
  final String url;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final int? durationSec;
  final String? caption;
  final bool isSelf;
  final MessageStatus? messageStatus;
  final String? footerTimeText;

  const VideoView({
    super.key,
    required this.url,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.durationSec,
    this.caption,
    required this.isSelf,
    this.messageStatus,
    this.footerTimeText,
  });

  static const double _maxDisplayWidth = 240;
  static const double _defaultDisplayHeight = 168;

  static String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '0:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final capTrim = caption?.trim();
    final captionText = (capTrim != null && capTrim.isNotEmpty)
        ? capTrim
        : null;
    final r = MessageBubbleStyle.bubbleRadius(context);

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
          return _withCaptionLayout(
            context,
            displayW: displayW,
            displayH: displayH,
            captionText: captionText,
            radius: r,
          );
        }
        return _soloThumbLayout(
          context,
          displayW: displayW,
          displayH: displayH,
        );
      },
    );
  }

  Widget _soloThumbLayout(
    BuildContext context, {
    required double displayW,
    required double displayH,
  }) {
    return SizedBox(
      width: displayW,
      child: Container(
        width: displayW,
        decoration: MessageBubbleStyle.bubbleDecoration(
          context,
          isSelf: isSelf,
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: displayW,
          height: displayH,
          child: _thumbStack(context, displayW, displayH),
        ),
      ),
    );
  }

  Widget _withCaptionLayout(
    BuildContext context, {
    required double displayW,
    required double displayH,
    required String captionText,
    required double radius,
  }) {
    final fg = isSelf
        ? MessageBubbleStyle.selfBubbleForeground(context)
        : MessageBubbleStyle.otherBubbleForeground(context);
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
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(radius),
                topRight: Radius.circular(radius),
              ),
              child: SizedBox(
                width: displayW,
                height: displayH,
                child: _thumbStack(context, displayW, displayH),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      captionText,
                      style: TextStyle(
                        color: fg,
                        fontSize: FlareImDesign.messageBubbleFontSize,
                        height: FlareImDesign.messageBubbleTextHeight,
                      ),
                    ),
                  ),
                  if (isSelf && messageStatus != null) ...[
                    const SizedBox(width: 8),
                    if (footerTimeText != null && footerTimeText!.isNotEmpty)
                      Text(
                        footerTimeText!,
                        style: TextStyle(
                          color: fg.withValues(alpha: 0.75),
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    if (footerTimeText != null && footerTimeText!.isNotEmpty)
                      const SizedBox(width: 6),
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

  Color _metaColor(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return FlareDarkThemeTokens.textSecondary.withValues(alpha: 0.95);
    }
    return isSelf
        ? FlareImDesign.messageBubbleSenderMeta
        : FlareImDesign.messageBubbleReceiverMeta;
  }

  Widget _thumbStack(BuildContext context, double w, double h) {
    final playable = isHttpOrHttpsUrl(url) || isLocalFileLikePath(url);
    final thumb = thumbnailUrl?.trim() ?? '';
    final thumbHttp = thumb.isNotEmpty && isHttpOrHttpsUrl(thumb);
    final thumbLocal = thumb.isNotEmpty && isLocalFileLikePath(thumb);

    Widget posterChild() {
      if (thumbHttp) {
        return CachedNetworkImage(
          imageUrl: thumb,
          width: w,
          height: h,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: w,
            height: h,
            color: FlareThemeTokens.messageMediaPlaceholderBg,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => const ColoredBox(
            color: FlareThemeTokens.messageMediaPlaceholderBg,
            child: Icon(
              Icons.videocam_outlined,
              size: 48,
              color: FlareThemeTokens.textSecondary,
            ),
          ),
        );
      }
      if (thumbLocal) {
        final path = thumb.startsWith('file://')
            ? Uri.parse(thumb).toFilePath()
            : thumb;
        return Image.file(
          File(path),
          width: w,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const ColoredBox(
            color: FlareThemeTokens.messageMediaPlaceholderBg,
            child: Icon(
              Icons.videocam_outlined,
              size: 48,
              color: FlareThemeTokens.textSecondary,
            ),
          ),
        );
      }
      return ColoredBox(
        color: const Color(0xFF1A1A1A),
        child: Icon(
          Icons.videocam_outlined,
          size: 48,
          color: Colors.white.withValues(alpha: 0.45),
        ),
      );
    }

    return GestureDetector(
      onTap: playable
          ? () => VideoPlayerModal.show(
              context,
              videoUrl: url,
              posterUrl: thumbnailUrl,
            )
          : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          posterChild(),
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                size: 40,
                color: Colors.black.withValues(alpha: 0.82),
              ),
            ),
          ),
          if (durationSec != null && durationSec! > 0)
            Positioned(
              left: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  child: Text(
                    _formatDuration(durationSec),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
        ],
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
}
