import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/infrastructure/media/network_image_policy.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/message/message_style.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

// 名片 / 联系人卡片。
///
/// 上：浅底头像区（姓名 + 副标题）；下：白底「发送名片」与己方时间/送达状态；外框与聊天气泡统一。
class CardView extends StatelessWidget {
  final bool isSelf;
  final String id;
  final String? title;
  final String? subtitle;
  final String? avatar;
  final MessageStatus? messageStatus;
  final String? footerTimeText;

  const CardView({
    super.key,
    required this.isSelf,
    required this.id,
    this.title,
    this.subtitle,
    this.avatar,
    this.messageStatus,
    this.footerTimeText,
  });

  String _nameLine() {
    final t = title?.trim();
    if (t != null && t.isNotEmpty) return t;
    return id;
  }

  String? _subtitleLine() {
    final s = subtitle?.trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  Color _headerBackground(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return Colors.white.withValues(alpha: 0.08);
    }
    return const Color(0xFFE8EEF9);
  }

  Color _footerBackground(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (isSelf) {
      if (dark) return Colors.white.withValues(alpha: 0.12);
      return Colors.white;
    }
    if (dark) {
      return Colors.white.withValues(alpha: 0.06);
    }
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final readIconColor = light
        ? FlareImDesign.messageBubbleSenderFill
        : FlareThemeTokens.primary;

    final name = _nameLine();
    final sub = _subtitleLine();
    final hasFooterTime =
        footerTimeText != null && footerTimeText!.trim().isNotEmpty;
    const metaColor = FlareThemeTokens.textSecondary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final rawMax = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : FlareImDesign.messageRichCardFallbackMaxWidth;
        final textMax = math.max(
          FlareImDesign.messageRichCardMinTextWidth,
          rawMax - FlareImDesign.messageContactCardTextColumnMaxWidthDeduction,
        );

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: rawMax),
          child: IntrinsicWidth(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: MessageBubbleStyle.bubbleDecoration(
                context,
                isSelf: isSelf,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: _headerBackground(context),
                    padding: const EdgeInsets.all(
                      FlareImDesign.messageContactCardHeaderHorizontalPadding,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CardAvatar(name: name, avatarUrl: avatar, cardId: id),
                        const SizedBox(
                          width:
                              FlareImDesign.messageContactCardAvatarToTextGap,
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: textMax),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                  color: isSelf
                                      ? FlareThemeTokens.textPrimary
                                      : MessageBubbleStyle.otherBubbleForeground(
                                          context,
                                        ),
                                ),
                              ),
                              if (sub != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  sub,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: metaColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
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
                    color: _footerBackground(context),
                    padding: const EdgeInsets.symmetric(
                      horizontal: FlareImDesign
                          .messageContactCardHeaderHorizontalPadding,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '发送名片',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                            color: metaColor,
                          ),
                        ),
                        if (isSelf && (hasFooterTime || messageStatus != null))
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
                                _statusIcon(messageStatus!, readIconColor),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
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

class _CardAvatar extends StatelessWidget {
  const _CardAvatar({required this.name, this.avatarUrl, required this.cardId});

  final String name;
  final String? avatarUrl;
  final String cardId;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final url = avatarUrl?.trim();
    final imageUrl = (url != null && url.isNotEmpty && isHttpOrHttpsUrl(url))
        ? url
        : null;

    const d = FlareImDesign.messageContactCardAvatarDiameter;

    if (imageUrl != null) {
      return CircleAvatar(
        radius: d / 2,
        backgroundColor: FlareThemeTokens.bgTertiary,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: d,
            height: d,
            fit: BoxFit.cover,
            placeholder: (context, _) => Container(
              width: d,
              height: d,
              color: FlareThemeTokens.messageMediaPlaceholderBg,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, _, _) => _fallbackLetter(context, light),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: d / 2,
      backgroundColor: light
          ? FlareImDesign.avatarPastelForKey(
              cardId.isNotEmpty ? cardId : name,
            ).$1
          : FlareThemeTokens.bgTertiary,
      foregroundColor: light
          ? FlareImDesign.avatarPastelForKey(
              cardId.isNotEmpty ? cardId : name,
            ).$2
          : FlareThemeTokens.textPrimary,
      child: Text(
        name.isNotEmpty ? name.characters.first.toString() : '?',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _fallbackLetter(BuildContext context, bool light) {
    final pastel = FlareImDesign.avatarPastelForKey(
      cardId.isNotEmpty ? cardId : name,
    );
    return Container(
      width: FlareImDesign.messageContactCardAvatarDiameter,
      height: FlareImDesign.messageContactCardAvatarDiameter,
      color: light ? pastel.$1 : FlareThemeTokens.bgTertiary,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name.characters.first.toString() : '?',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: light ? pastel.$2 : FlareThemeTokens.textPrimary,
        ),
      ),
    );
  }
}
