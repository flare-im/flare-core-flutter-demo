import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/infrastructure/media/network_image_policy.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/message/message_style.dart';
import 'package:flare_im/interface/widgets/message/plain_text_emoji_rich.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// 链接卡片。
///
/// 仅当消息携带合法 [thumbnailUrl] 时展示顶部预览图；无缩略图时不占上方区域。
/// 下方为域名行 + 标题 + 摘要；统一气泡样式；不展示时间；送达状态仅己方显示。
class LinkCardView extends StatelessWidget {
  final bool isSelf;
  final String? title;
  final String url;
  final String? summary;
  final String? siteName;
  final String? thumbnailUrl;
  final MessageStatus? messageStatus;

  const LinkCardView({
    super.key,
    required this.isSelf,
    required this.url,
    this.title,
    this.summary,
    this.siteName,
    this.thumbnailUrl,
    this.messageStatus,
  });

  static const double _previewHeight = 132;

  String _domainLine() {
    final u = Uri.tryParse(url.trim());
    if (u != null && u.host.isNotEmpty) return u.host;
    final sn = siteName?.trim();
    if (sn != null && sn.isNotEmpty) return sn;
    return '链接';
  }

  String _titleLine() {
    final t = title?.trim();
    if (t != null && t.isNotEmpty) return t;
    return _domainLine();
  }

  Future<void> _openLink(BuildContext context) async {
    final u = Uri.tryParse(url.trim());
    if (u == null || (u.scheme != 'http' && u.scheme != 'https')) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('无法打开链接')));
      return;
    }
    final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('无法打开链接')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final readIconColor = light
        ? FlareImDesign.messageBubbleSenderFill
        : FlareThemeTokens.primary;

    final desc = summary?.trim() ?? '';
    final hasSummary = desc.isNotEmpty;

    final thumbCandidate = thumbnailUrl?.trim();
    final thumbUrl =
        (thumbCandidate != null &&
            thumbCandidate.isNotEmpty &&
            isHttpOrHttpsUrl(thumbCandidate))
        ? thumbCandidate
        : null;

    const domainColor = FlareThemeTokens.textSecondary;
    final titleColor = _titleColor(context);
    const metaSize = 12.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final rawMax = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : FlareImDesign.messageRichCardFallbackMaxWidth;
        const innerPadTotal =
            FlareImDesign.messageLinkCardHorizontalPadding * 2;
        final innerTextMax = math.max(
          FlareImDesign.messageRichCardMinTextWidth,
          rawMax - innerPadTotal,
        );
        final thumbW = thumbUrl != null
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
                onTap: () => _openLink(context),
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
                        if (thumbUrl != null)
                          SizedBox(
                            width: thumbW,
                            height: _previewHeight,
                            child: CachedNetworkImage(
                              imageUrl: thumbUrl,
                              fit: BoxFit.cover,
                              width: thumbW,
                              placeholder: (context, _) => Container(
                                width: thumbW,
                                color:
                                    FlareThemeTokens.messageMediaPlaceholderBg,
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
                                width: thumbW,
                                color:
                                    FlareThemeTokens.messageMediaPlaceholderBg,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  size: 36,
                                  color: FlareThemeTokens.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        Container(
                          color: _infoStripBackground(context),
                          padding: const EdgeInsets.fromLTRB(
                            FlareImDesign.messageLinkCardHorizontalPadding,
                            10,
                            FlareImDesign.messageLinkCardHorizontalPadding,
                            10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.public_outlined,
                                    size: 14,
                                    color: domainColor,
                                  ),
                                  const SizedBox(width: 5),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: math.max(
                                        FlareImDesign
                                            .messageLinkCardDomainRowMinTextWidth,
                                        innerTextMax -
                                            FlareImDesign
                                                .messageLinkCardDomainIconBlock,
                                      ),
                                    ),
                                    child: Text(
                                      _domainLine(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: metaSize,
                                        height: 1.25,
                                        color: domainColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: innerTextMax,
                                ),
                                child: PlainTextEmojiRich(
                                  text: _titleLine(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                    color: titleColor,
                                  ),
                                  unknownBracketStyle: const TextStyle(
                                    fontSize: 15,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                    color: domainColor,
                                  ),
                                ),
                              ),
                              if (hasSummary) ...[
                                const SizedBox(height: 6),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: innerTextMax,
                                  ),
                                  child: PlainTextEmojiRich(
                                    text: desc,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: FlareThemeTokens.textSecondary,
                                    ),
                                    unknownBracketStyle: const TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: FlareThemeTokens.textTertiary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                              if (isSelf && messageStatus != null) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: _statusIcon(
                                    messageStatus!,
                                    readIconColor,
                                  ),
                                ),
                              ],
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

  Color _infoStripBackground(BuildContext context) {
    if (isSelf) {
      return Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.white;
    }
    return Colors.transparent;
  }

  Color _titleColor(BuildContext context) {
    if (isSelf) {
      return FlareThemeTokens.textPrimary;
    }
    return MessageBubbleStyle.otherBubbleForeground(context);
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
