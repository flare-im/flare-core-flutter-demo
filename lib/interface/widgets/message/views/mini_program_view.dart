import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/infrastructure/media/network_image_policy.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/message/message_style.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

// 小程序卡片。
///
/// 有 [thumbnailUrl] 时顶部封面 + 底部叠字标题；无图时展示明确「小程序」标识与 [title]。
/// 外框与聊天气泡统一；宽度随内容且不超过父级（≤72% 屏宽）。
class MiniProgramView extends StatelessWidget {
  final bool isSelf;
  final String appId;
  final String? title;
  final String? thumbnailUrl;
  final String? description;
  final MessageStatus? messageStatus;
  final String? footerTimeText;

  const MiniProgramView({
    super.key,
    required this.isSelf,
    required this.appId,
    this.title,
    this.thumbnailUrl,
    this.description,
    this.messageStatus,
    this.footerTimeText,
  });

  static const double _coverHeight = 132;

  String _titleLine() {
    final t = title?.trim();
    if (t != null && t.isNotEmpty) return t;
    return '小程序';
  }

  String? _descriptionLine() {
    final d = description?.trim();
    if (d == null || d.isEmpty) return null;
    return d;
  }

  Color _bodyStripBackground(BuildContext context) {
    if (isSelf) {
      return Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.white;
    }
    return Colors.transparent;
  }

  Color _titleColor(BuildContext context) {
    if (isSelf) return FlareThemeTokens.textPrimary;
    return MessageBubbleStyle.otherBubbleForeground(context);
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final readIconColor = light
        ? FlareImDesign.messageBubbleSenderFill
        : FlareThemeTokens.primary;

    final desc = _descriptionLine();
    final hasDesc = desc != null;
    final thumbLine = thumbnailUrl?.trim() ?? '';
    final showCover = thumbLine.isNotEmpty && isHttpOrHttpsUrl(thumbLine);

    final hasFooterTime =
        footerTimeText != null && footerTimeText!.trim().isNotEmpty;
    const metaColor = FlareThemeTokens.textSecondary;
    const hPad = FlareImDesign.messageLinkCardHorizontalPadding;

    return LayoutBuilder(
      builder: (context, constraints) {
        final rawMax = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : FlareImDesign.messageRichCardFallbackMaxWidth;
        final innerTextMax = math.max(
          FlareImDesign.messageRichCardMinTextWidth,
          rawMax - hPad * 2,
        );
        final thumbW = showCover
            ? math.min(
                FlareImDesign.messageLinkCardThumbnailPreferredWidth,
                rawMax,
              )
            : 0.0;
        final bubbleR = MessageBubbleStyle.bubbleRadius(context);

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: rawMax),
          child: IntrinsicWidth(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(bubbleR),
                onTap: () {
                  final hint = appId.trim().isNotEmpty
                      ? '打开小程序（$appId）功能开发中'
                      : '打开小程序功能开发中';
                  ScaffoldMessenger.maybeOf(
                    context,
                  )?.showSnackBar(SnackBar(content: Text(hint)));
                },
                child: Ink(
                  decoration: MessageBubbleStyle.bubbleDecoration(
                    context,
                    isSelf: isSelf,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(bubbleR),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showCover)
                          SizedBox(
                            width: thumbW,
                            height: _coverHeight,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: thumbLine,
                                  fit: BoxFit.cover,
                                  width: thumbW,
                                  placeholder: (context, _) => Container(
                                    color: FlareThemeTokens
                                        .messageMediaPlaceholderBg,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, _, _) => Container(
                                    color: FlareThemeTokens
                                        .messageMediaPlaceholderBg,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 36,
                                      color: FlareThemeTokens.textSecondary,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  height: 52,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.55),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: hPad,
                                  right: hPad,
                                  bottom: 10,
                                  child: Text(
                                    _titleLine(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 6,
                                          color: Color(0x66000000),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            color: FlareThemeTokens.bgTertiary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: hPad,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.widgets_outlined,
                                  size: 18,
                                  color: FlareThemeTokens.primary,
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: FlareThemeTokens.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '小程序',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                      color: FlareThemeTokens.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!showCover)
                          Container(
                            color: _bodyStripBackground(context),
                            padding: EdgeInsets.fromLTRB(
                              hPad,
                              10,
                              hPad,
                              hasDesc ? 6 : 8,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: innerTextMax,
                              ),
                              child: Text(
                                _titleLine(),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                  color: _titleColor(context),
                                ),
                              ),
                            ),
                          ),
                        if (hasDesc)
                          Container(
                            color: _bodyStripBackground(context),
                            padding: EdgeInsets.fromLTRB(
                              hPad,
                              showCover ? 10 : 0,
                              hPad,
                              8,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: innerTextMax,
                              ),
                              child: Text(
                                desc,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: metaColor,
                                ),
                              ),
                            ),
                          ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: FlareThemeTokens.borderPrimary.withValues(
                            alpha: 0.45,
                          ),
                        ),
                        Container(
                          color: _bodyStripBackground(context),
                          padding: const EdgeInsets.symmetric(
                            horizontal: hPad,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '点击打开小程序 →',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: FlareThemeTokens.primary,
                                ),
                              ),
                              if (isSelf &&
                                  (hasFooterTime || messageStatus != null))
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (hasFooterTime)
                                      Text(
                                        footerTimeText!.trim(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          height: 1.2,
                                          fontWeight: FontWeight.w500,
                                          color: metaColor,
                                        ),
                                      ),
                                    if (hasFooterTime && messageStatus != null)
                                      const SizedBox(width: 6),
                                    if (messageStatus != null)
                                      _statusIcon(
                                        messageStatus!,
                                        readIconColor,
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statusIcon(MessageStatus status, Color readColor) {
    switch (status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.4,
            color: FlareThemeTokens.textSecondary,
          ),
        );
      case MessageStatus.sent:
      case MessageStatus.delivered:
        return const Icon(
          Icons.check,
          size: 16,
          color: FlareThemeTokens.textSecondary,
        );
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 16, color: readColor);
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline,
          size: 16,
          color: FlareThemeTokens.error,
        );
    }
  }
}
