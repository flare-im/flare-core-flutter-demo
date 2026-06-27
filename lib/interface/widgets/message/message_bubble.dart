import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/infrastructure/media/composer_static_asset_image.dart';
import 'package:flare_im/infrastructure/media/network_image_policy.dart';
import 'package:flare_im/infrastructure/media/pack_asset_resolver.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/message/content_view.dart';
import 'package:flare_im/interface/widgets/message/message_long_press_menu.dart';
import 'package:flare_im/interface/widgets/message/message_style.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

String _imageBubbleFooterClock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

bool _videoWithCaption(MessageContent content) {
  if (content is! VideoContent) return false;
  final d = content.description?.trim();
  return d != null && d.isNotEmpty;
}

final RegExp _reactionBracketKey = RegExp(r'^\[([^\]]+)\]$');

/// 与 Tauri `MessageBubble.vue`：`senderDisplayName || senderName || senderId`
String _senderLabelForAvatar(Message m) {
  final d = m.senderDisplayName.trim();
  if (d.isNotEmpty) return d;
  final n = m.senderName.trim();
  if (n.isNotEmpty) return n;
  return m.senderId.trim();
}

/// 与 Tauri：`senderAvatar || extra.avatarUrl`
String _effectiveAvatarUrl(Message m) {
  final a = m.senderAvatar.trim();
  if (a.isNotEmpty) return a;
  final v = m.extra['avatarUrl']?.trim();
  if (v != null && v.isNotEmpty) return v;
  return '';
}

String _avatarInitialGlyph(Message m) {
  final label = _senderLabelForAvatar(m);
  if (label.isEmpty) return '?';
  return label.characters.first.toString();
}

/// 文本气泡内 / 媒体下方的反应条布局（飞书：文本与反应同容器，媒体下独立一行、无悬浮叠层）。
enum _ReactionRowPlacement {
  /// 在文本气泡圆角容器底部，与正文同一底色体系。
  textBubbleInterior,

  /// 在图片等气泡下方，扁平条、略间距。
  belowAttachment,
}

// 消息气泡：头像、内容区、送达状态、回应条。
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool showAvatar;
  final String currentUserId;
  final VoidCallback? onRecall;
  final Future<void> Function()? onDeleteForEveryone;
  final Future<void> Function()? onDeleteForSelf;
  final bool showDeleteForEveryoneOption;
  final VoidCallback? onEdit;
  final void Function(String emoji)? onReaction;
  final void Function(String emoji)? onRemoveReaction;
  final VoidCallback? onCopy;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onMultiSelect;
  final VoidCallback? onMark;
  final VoidCallback? onPinToggle;
  final VoidCallback? onPinForSelf;
  final String pinToggleLabel;

  /// 发送失败（己方文本）时点「重发」
  final VoidCallback? onResend;

  /// 引用消息：列表根据被引用 id 解析出的发送方展示名（可选）
  final String? quotedSenderResolvedName;

  const MessageBubble({
    super.key,
    required this.message,
    this.showAvatar = true,
    this.currentUserId = '',
    this.onRecall,
    this.onDeleteForEveryone,
    this.onDeleteForSelf,
    this.showDeleteForEveryoneOption = false,
    this.onEdit,
    this.onReaction,
    this.onRemoveReaction,
    this.onCopy,
    this.onReply,
    this.onForward,
    this.onMultiSelect,
    this.onMark,
    this.onPinToggle,
    this.onPinForSelf,
    this.pinToggleLabel = '置顶消息',
    this.onResend,
    this.quotedSenderResolvedName,
  });

  @override
  Widget build(BuildContext context) {
    final isSelf =
        currentUserId.isNotEmpty && message.senderId == currentUserId;
    final isNotification = message.content is NotificationContent;
    final showFailureResend =
        !isNotification &&
        isSelf &&
        !message.isRecalled &&
        message.status == MessageStatus.failed;

    final hasReactions =
        message.reactions != null && message.reactions!.isNotEmpty;
    final isText = message.content is TextContent;
    final placement = isText
        ? _ReactionRowPlacement.textBubbleInterior
        : _ReactionRowPlacement.belowAttachment;
    final reactionStrip = hasReactions && !message.isRecalled
        ? _MessageReactionRow(
            reactions: message.reactions!,
            currentUserId: currentUserId,
            isSelf: isSelf,
            placement: placement,
            onAdd: onReaction,
            onRemove: onRemoveReaction,
          )
        : null;
    final textBubbleFooter = isText ? reactionStrip : null;
    final showReactionsBelowAttachment = !isText && reactionStrip != null;

    Widget innerBubble() {
      if (message.isRecalled) return _recalledBubble(context);
      return ContentView(
        content: message.content,
        isSelf: isSelf,
        messageStatus: message.status,
        mediaFooterTimeText:
            message.content is ImageContent ||
                message.content is ImageGroupContent ||
                message.content is VideoContent ||
                message.content is AudioContent ||
                message.content is FileContent ||
                message.content is CardContent ||
                message.content is MiniProgramContent ||
                message.content is VoteContent ||
                message.content is ForwardContent ||
                message.content is AnnouncementContent
            ? _imageBubbleFooterClock(message.timestamp)
            : null,
        quotedSenderResolvedName: quotedSenderResolvedName,
        bubbleFooter: textBubbleFooter,
      );
    }

    Widget bubbleBlock() {
      final core = innerBubble();
      if (!showReactionsBelowAttachment) return core;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isSelf
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          core,
          Padding(padding: const EdgeInsets.only(top: 6), child: reactionStrip),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isSelf
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSelf && !isNotification) ...[
            showAvatar
                ? Builder(
                    builder: (context) {
                      final light =
                          Theme.of(context).brightness == Brightness.light;
                      final pastel = FlareImDesign.avatarPastelForKey(
                        message.senderId,
                      );
                      final avatarUrl = _effectiveAvatarUrl(message);
                      final hasNetworkAvatar =
                          avatarUrl.isNotEmpty && isHttpOrHttpsUrl(avatarUrl);
                      return CircleAvatar(
                        radius: 18,
                        backgroundColor: light ? pastel.$1 : null,
                        foregroundColor: light ? pastel.$2 : null,
                        backgroundImage: hasNetworkAvatar
                            ? CachedNetworkImageProvider(
                                avatarUrl,
                                errorListener: (_) {},
                              )
                            : null,
                        child: !hasNetworkAvatar
                            ? Text(
                                _avatarInitialGlyph(message),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                      );
                    },
                  )
                : const SizedBox(width: 36),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: isNotification
                  ? CrossAxisAlignment.center
                  : (isSelf
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isSelf &&
                    !isNotification &&
                    showAvatar &&
                    _senderLabelForAvatar(message).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 4),
                    child: Text(
                      _senderLabelForAvatar(message),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).brightness == Brightness.light
                            ? FlareImDesign.mutedForeground
                            : FlareThemeTokens.textSecondary,
                      ),
                    ),
                  ),
                GestureDetector(
                  onLongPress: () {
                    unawaited(
                      showMessageLongPressMenu(
                        context,
                        onPickReaction: onReaction,
                        onReply: onReply,
                        onForward: onForward,
                        onRecall: onRecall,
                        onMultiSelect: onMultiSelect,
                        onMark: onMark,
                        onPinToggle: onPinToggle,
                        onPinForSelf: onPinForSelf,
                        pinLabel: pinToggleLabel,
                        onCopy: onCopy,
                        onEdit: onEdit,
                        onDeleteForSelf: onDeleteForSelf,
                        onDeleteForEveryone: onDeleteForEveryone,
                        showDeleteForEveryoneOption:
                            showDeleteForEveryoneOption,
                      ),
                    );
                  },
                  child: isNotification
                      ? Center(
                          child: messageBubbleContentWidthScope(
                            context: context,
                            isSelf: false,
                            content: message.content,
                            messageStatus: message.status,
                            child: bubbleBlock(),
                          ),
                        )
                      : Align(
                          alignment: isSelf
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: showFailureResend
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _MessageSendFailureResend(
                                      onTap: () {
                                        if (onResend != null) {
                                          onResend!();
                                        } else {
                                          ScaffoldMessenger.maybeOf(
                                            context,
                                          )?.showSnackBar(
                                            const SnackBar(
                                              content: Text('该消息类型暂不支持重发'),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    messageBubbleContentWidthScope(
                                      context: context,
                                      isSelf: isSelf,
                                      content: message.content,
                                      messageStatus: message.status,
                                      child: bubbleBlock(),
                                    ),
                                  ],
                                )
                              : messageBubbleContentWidthScope(
                                  context: context,
                                  isSelf: isSelf,
                                  content: message.content,
                                  messageStatus: message.status,
                                  child: bubbleBlock(),
                                ),
                        ),
                ),
                if (isSelf &&
                    !message.isRecalled &&
                    message.content is! NotificationContent &&
                    message.content is! TextContent &&
                    message.content is! CardContent &&
                    message.content is! ImageContent &&
                    message.content is! ImageGroupContent &&
                    message.content is! AudioContent &&
                    message.content is! FileContent &&
                    message.content is! LocationContent &&
                    message.content is! LinkCardContent &&
                    message.content is! MiniProgramContent &&
                    message.content is! VoteContent &&
                    message.content is! ForwardContent &&
                    !_videoWithCaption(message.content))
                  _selfStatusLine(context, message),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 己方消息状态：置于气泡下方右对齐；失败态由气泡旁的 [_MessageSendFailureResend] 承担，此处不再重复「发送失败」。
  Widget _selfStatusLine(BuildContext context, Message message) {
    final caption = _selfStatusCaption(message.status);
    if (caption == null) return const SizedBox.shrink();
    final light = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.only(top: 5, right: 2),
      child: Text(
        caption,
        style: TextStyle(
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w500,
          color: light
              ? FlareImDesign.messageBubbleSelfStatusCaption
              : FlareThemeTokens.textSecondary.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  String? _selfStatusCaption(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return '发送中…';
      case MessageStatus.failed:
        return null;
      case MessageStatus.read:
        return '已读';
      case MessageStatus.sent:
      case MessageStatus.delivered:
        return null;
    }
  }

  Widget _recalledBubble(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final r = MessageBubbleStyle.bubbleRadius(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FlareImDesign.messageBubblePaddingH,
        vertical: FlareImDesign.messageBubblePaddingV,
      ),
      decoration: BoxDecoration(
        color: light
            ? FlareImDesign.messageBubbleReceiverFill
            : FlareThemeTokens.bgHover,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(
          color: light
              ? FlareImDesign.messageBubbleReceiverBorder
              : FlareThemeTokens.borderPrimary,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_outlined,
            size: 16,
            color: light
                ? FlareImDesign.messageBubbleReceiverMeta
                : FlareThemeTokens.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            '消息已撤回',
            style: TextStyle(
              color: light
                  ? FlareImDesign.messageBubbleReceiverMeta
                  : FlareThemeTokens.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// 反应条：飞书式扁平胶囊「表情 + 人数」，无描边、无重阴影；文本在气泡内，媒体在下方独立一行。
class _MessageReactionRow extends StatelessWidget {
  const _MessageReactionRow({
    required this.reactions,
    required this.currentUserId,
    required this.isSelf,
    required this.placement,
    this.onAdd,
    this.onRemove,
  });

  final List<Reaction> reactions;
  final String currentUserId;
  final bool isSelf;
  final _ReactionRowPlacement placement;
  final void Function(String emoji)? onAdd;
  final void Function(String emoji)? onRemove;

  bool get _inTextBubble =>
      placement == _ReactionRowPlacement.textBubbleInterior;

  BoxDecoration _pillDecoration(BuildContext context, bool iReacted) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (_inTextBubble) {
      if (isSelf) {
        final base = dark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.2);
        final fill = iReacted
            ? Color.alphaBlend(
                Colors.white.withValues(alpha: dark ? 0.14 : 0.12),
                base,
              )
            : base;
        return BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(999),
        );
      }
      final base = dark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.05);
      final fill = iReacted
          ? Color.alphaBlend(
              FlareThemeTokens.primary.withValues(alpha: dark ? 0.2 : 0.08),
              base,
            )
          : base;
      return BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      );
    }
    final base = dark
        ? FlareDarkThemeTokens.bgTertiary
        : FlareThemeTokens.bgTertiary;
    final fill = iReacted
        ? Color.alphaBlend(
            FlareThemeTokens.primary.withValues(alpha: dark ? 0.18 : 0.09),
            base,
          )
        : base;
    return BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999));
  }

  Color _countColor(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (_inTextBubble && isSelf) {
      return Colors.white.withValues(alpha: dark ? 0.88 : 0.92);
    }
    if (_inTextBubble) {
      return dark
          ? FlareDarkThemeTokens.textSecondary
          : FlareThemeTokens.textPrimary.withValues(alpha: 0.72);
    }
    return dark
        ? FlareDarkThemeTokens.textSecondary
        : FlareThemeTokens.textPrimary.withValues(alpha: 0.7);
  }

  @override
  Widget build(BuildContext context) {
    final me = currentUserId.trim();
    final gap = _inTextBubble ? 4.0 : 5.0;
    // 间距用首项外的左 padding，避免 [Wrap.spacing] 不参与 intrinsic 宽计算导致
    // [IntrinsicWidth] 过窄、反应提前换行。
    return Wrap(
      direction: Axis.horizontal,
      alignment: isSelf ? WrapAlignment.end : WrapAlignment.start,
      runAlignment: isSelf ? WrapAlignment.end : WrapAlignment.start,
      spacing: 0,
      runSpacing: 4,
      children: [
        for (var i = 0; i < reactions.length; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : gap),
            child: _reactionChip(context, reactions[i], me),
          ),
      ],
    );
  }

  Widget _reactionChip(BuildContext context, Reaction r, String me) {
    final iReacted = me.isNotEmpty && r.userIds.contains(me);
    final canTap =
        (iReacted && onRemove != null) || (!iReacted && onAdd != null);
    final n = r.count > 0 ? r.count : r.userIds.length;
    final padH = _inTextBubble ? 6.0 : 7.0;
    final padV = _inTextBubble ? 2.0 : 3.0;
    final fontSize = _inTextBubble ? 11.5 : 12.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canTap
            ? () {
                if (iReacted) {
                  onRemove?.call(r.emoji);
                } else {
                  onAdd?.call(r.emoji);
                }
              }
            : null,
        borderRadius: BorderRadius.circular(999),
        splashColor: (_inTextBubble && isSelf)
            ? Colors.white.withValues(alpha: 0.12)
            : FlareThemeTokens.primary.withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: _pillDecoration(context, iReacted),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _reactionEmojiVisual(r.emoji, compact: _inTextBubble),
              SizedBox(width: n >= 10 ? 4 : 3),
              Text(
                '$n',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: _countColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reactionEmojiVisual(String emoji, {required bool compact}) {
    final side = compact ? 17.0 : 18.0;
    final m = _reactionBracketKey.firstMatch(emoji.trim());
    if (m != null) {
      final path = PackAssetResolver.emojiPackAssetPath(m.group(1)!);
      return SizedBox(
        width: side,
        height: side,
        child: ComposerStaticAssetImage(
          assetPath: path,
          fit: BoxFit.contain,
          decodeSize: 48,
          error: Text(emoji, style: TextStyle(fontSize: compact ? 11 : 12)),
        ),
      );
    }
    return Text(
      emoji,
      style: TextStyle(fontSize: compact ? 13 : 14, height: 1.05),
    );
  }
}

/// 红圆感叹号 +「重发」，贴在己方失败气泡旁（可点击重发）。
class _MessageSendFailureResend extends StatelessWidget {
  const _MessageSendFailureResend({required this.onTap});

  final VoidCallback onTap;

  static const Color _red = FlareThemeTokens.error;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: _red,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  '!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '重发',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _red,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
