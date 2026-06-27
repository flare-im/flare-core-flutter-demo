import 'dart:math' as math;

import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/infrastructure/mappers/storage_preview_format.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/message/message_style.dart';
import 'package:flare_im/interface/widgets/message/message_type_label.dart';
import 'package:flare_im/interface/widgets/message/plain_text_emoji_rich.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

/// 内嵌渲染单条快照（由 [ContentView] 注入，避免循环 import）。
typedef ForwardEmbedBuilder =
    Widget Function(
      BuildContext context,
      MessageContent content, {
      required bool asOutgoingBubble,
    });

// 转发消息（合并或单条）。
///
/// * 仅 1 条：若有附言，附言与内嵌内容共处于同一气泡内（附言在上、胶囊样式）。
/// * 多条：「聊天记录」摘要卡，最多预览 4 条；点击打开详情底部页（类 PC 列表）。
class ForwardView extends StatelessWidget {
  static const int _compactPreviewLimit = 4;
  static const int _previewCharLimit = 56;
  static const double _accentWidth = 4;

  final String forwardTitle;
  final List<ForwardSnapshotItem> items;
  final bool isSelf;
  final MessageStatus? messageStatus;
  final String? footerTimeText;
  final ForwardEmbedBuilder embedBuilder;

  const ForwardView({
    super.key,
    required this.forwardTitle,
    required this.items,
    required this.isSelf,
    required this.embedBuilder,
    this.messageStatus,
    this.footerTimeText,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _emptyPlaceholder(context);
    }
    if (items.length == 1) {
      return _SingleForwardBody(
        forwardTitle: forwardTitle,
        item: items.first,
        isSelf: isSelf,
        embedBuilder: embedBuilder,
      );
    }
    return _MergeForwardCard(
      forwardTitle: forwardTitle,
      items: items,
      isSelf: isSelf,
      messageStatus: messageStatus,
      footerTimeText: footerTimeText,
      embedBuilder: embedBuilder,
    );
  }

  Widget _emptyPlaceholder(BuildContext context) {
    final cap = FlareImDesign.messageBubbleMaxWidthForScreen(
      context,
      isSelf: isSelf,
    );
    final fg = isSelf
        ? MessageBubbleStyle.selfBubbleForeground(context)
        : MessageBubbleStyle.otherBubbleForeground(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: cap),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: MessageBubbleStyle.bubbleDecoration(
          context,
          isSelf: isSelf,
        ),
        child: Text(
          '暂无转发内容',
          style: TextStyle(fontSize: 13, color: fg.withValues(alpha: 0.75)),
        ),
      ),
    );
  }
}

// —— 单条 ————————————————————————————————————————————————————————

class _SingleForwardBody extends StatelessWidget {
  final String forwardTitle;
  final ForwardSnapshotItem item;
  final bool isSelf;
  final ForwardEmbedBuilder embedBuilder;

  const _SingleForwardBody({
    required this.forwardTitle,
    required this.item,
    required this.isSelf,
    required this.embedBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final cap = FlareImDesign.messageBubbleMaxWidthForScreen(
      context,
      isSelf: isSelf,
    );
    final remark = forwardTitle.trim();
    final inner = _coerceSingleContent(item);
    final embedded = embedBuilder(context, inner, asOutgoingBubble: isSelf);

    if (remark.isEmpty) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cap),
        child: embedded,
      );
    }

    final bubbleFg = isSelf
        ? MessageBubbleStyle.selfBubbleForeground(context)
        : MessageBubbleStyle.otherBubbleForeground(context);
    final labelColor = isSelf
        ? bubbleFg.withValues(alpha: 0.72)
        : FlareThemeTokens.textTertiary;
    final bodyColor = isSelf
        ? bubbleFg.withValues(alpha: 0.88)
        : FlareThemeTokens.textSecondary;
    final capsuleBorder = isSelf
        ? bubbleFg.withValues(alpha: 0.28)
        : FlareImDesign.messageBubbleReceiverBorder;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: cap),
      child: Container(
        decoration: MessageBubbleStyle.bubbleDecoration(
          context,
          isSelf: isSelf,
        ),
        padding: const EdgeInsets.fromLTRB(
          FlareImDesign.messageBubblePaddingH,
          FlareImDesign.messageBubblePaddingV,
          FlareImDesign.messageBubblePaddingH,
          FlareImDesign.messageBubblePaddingV,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: capsuleBorder, width: 1),
                ),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: bodyColor,
                    ),
                    children: [
                      TextSpan(
                        text: '附言 ',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                          fontSize: 11,
                        ),
                      ),
                      TextSpan(text: remark),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            embedded,
          ],
        ),
      ),
    );
  }

  MessageContent _coerceSingleContent(ForwardSnapshotItem it) {
    final c = it.content;
    if (c is TextContent) {
      if (c.text.trim().isNotEmpty) return c;
      final plain = (it.plainText ?? '').trim();
      if (plain.isNotEmpty) return TextContent(formatStoragePreview(plain));
      return c;
    }
    return c;
  }
}

// —— 多条卡片 + 详情 ——————————————————————————————————————————————

class _MergeForwardCard extends StatelessWidget {
  final String forwardTitle;
  final List<ForwardSnapshotItem> items;
  final bool isSelf;
  final MessageStatus? messageStatus;
  final String? footerTimeText;
  final ForwardEmbedBuilder embedBuilder;

  const _MergeForwardCard({
    required this.forwardTitle,
    required this.items,
    required this.isSelf,
    required this.embedBuilder,
    this.messageStatus,
    this.footerTimeText,
  });

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final readIconColor = light
        ? FlareImDesign.messageBubbleSenderFill
        : FlareThemeTokens.primary;
    final hasFooterTime =
        footerTimeText != null && footerTimeText!.trim().isNotEmpty;
    final previews = items.take(ForwardView._compactPreviewLimit).toList();
    final total = items.length;
    final more = total - previews.length;
    final remark = forwardTitle.trim();
    final bubbleR = MessageBubbleStyle.bubbleRadius(context);
    final titleFg = isSelf
        ? MessageBubbleStyle.selfBubbleForeground(context)
        : MessageBubbleStyle.otherBubbleForeground(context);
    final metaColor = isSelf
        ? titleFg.withValues(alpha: 0.88)
        : FlareThemeTokens.textSecondary;
    final tertiaryOnBubble = isSelf
        ? titleFg.withValues(alpha: 0.72)
        : FlareThemeTokens.textTertiary;
    final accentBarColor = isSelf
        ? Colors.white.withValues(alpha: 0.42)
        : FlareImDesign.messageBubbleSenderFill;
    final headerIconColor = isSelf
        ? Colors.white.withValues(alpha: 0.95)
        : FlareImDesign.messageBubbleSenderFill;
    final dividerColor = isSelf
        ? Colors.white.withValues(alpha: 0.22)
        : FlareThemeTokens.borderPrimary.withValues(alpha: 0.45);
    const hPad = FlareImDesign.messageLinkCardHorizontalPadding;

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

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(bubbleR),
              onTap: () => _openDetail(context),
              child: Ink(
                decoration: MessageBubbleStyle.bubbleDecoration(
                  context,
                  isSelf: isSelf,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(bubbleR),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: ForwardView._accentWidth,
                          color: accentBarColor,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  hPad,
                                  10,
                                  hPad,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.library_books_outlined,
                                      size: 20,
                                      color: headerIconColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '聊天记录',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: titleFg,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: dividerColor,
                              ),
                              if (remark.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    hPad,
                                    8,
                                    hPad,
                                    0,
                                  ),
                                  child: Text(
                                    '附言 $remark',
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.35,
                                      color: metaColor,
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  hPad,
                                  8,
                                  hPad,
                                  8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (
                                      var i = 0;
                                      i < previews.length;
                                      i++
                                    ) ...[
                                      if (i > 0) const SizedBox(height: 6),
                                      Builder(
                                        builder: (ctx) {
                                          final snippetStyle = TextStyle(
                                            fontSize: 13,
                                            height: 1.35,
                                            color: metaColor,
                                          );
                                          final snippetSecondary = isSelf
                                              ? metaColor.withValues(
                                                  alpha: 0.92,
                                                )
                                              : FlareThemeTokens.textTertiary;
                                          final truncated = _truncateLine(
                                            _itemPreviewLine(previews[i]),
                                            ForwardView._previewCharLimit,
                                          );
                                          return Text.rich(
                                            TextSpan(
                                              style: snippetStyle,
                                              children: [
                                                TextSpan(
                                                  text:
                                                      '${_senderLabel(previews[i])}：',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                ...plainTextEmojiInlineSpans(
                                                  ctx,
                                                  text: truncated,
                                                  style: snippetStyle,
                                                  secondaryForeground:
                                                      snippetSecondary,
                                                ),
                                              ],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          );
                                        },
                                      ),
                                    ],
                                    if (more > 0) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        '还有 $more 条消息…',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: tertiaryOnBubble,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: dividerColor,
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  hPad,
                                  8,
                                  hPad,
                                  10,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '共 $total 条消息',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: tertiaryOnBubble,
                                      ),
                                    ),
                                    if (isSelf &&
                                        (hasFooterTime ||
                                            messageStatus != null))
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (hasFooterTime)
                                            Text(
                                              footerTimeText!.trim(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                height: 1.2,
                                                fontWeight: FontWeight.w500,
                                                color: metaColor,
                                              ),
                                            ),
                                          if (hasFooterTime &&
                                              messageStatus != null)
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
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: hPad,
                                  right: hPad,
                                  bottom: 8,
                                ),
                                child: Text(
                                  '点击查看详情',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelf
                                        ? Colors.white.withValues(alpha: 0.92)
                                        : FlareThemeTokens.primary.withValues(
                                            alpha: 0.9,
                                          ),
                                  ),
                                ),
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

  void _openDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: FlareThemeTokens.bgPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final h = MediaQuery.sizeOf(ctx).height * 0.92;
        final remark = forwardTitle.trim();
        return SizedBox(
          height: h,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '合并转发（${items.length} 条）',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (remark.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: FlareThemeTokens.bgTertiary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: FlareThemeTokens.borderPrimary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Builder(
                      builder: (ctx) {
                        const base = TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: FlareThemeTokens.textSecondary,
                        );
                        return Text.rich(
                          TextSpan(
                            style: base,
                            children: [
                              const TextSpan(
                                text: '附言 ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: FlareThemeTokens.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                              ...plainTextEmojiInlineSpans(
                                ctx,
                                text: remark,
                                style: base,
                                secondaryForeground:
                                    FlareThemeTokens.textTertiary,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 20,
                    color: FlareThemeTokens.borderPrimary.withValues(
                      alpha: 0.35,
                    ),
                  ),
                  itemBuilder: (ctx, index) {
                    final it = items[index];
                    return _ForwardDetailTile(
                      item: it,
                      embedBuilder: embedBuilder,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ForwardDetailTile extends StatelessWidget {
  final ForwardSnapshotItem item;
  final ForwardEmbedBuilder embedBuilder;

  const _ForwardDetailTile({required this.item, required this.embedBuilder});

  @override
  Widget build(BuildContext context) {
    final hueKey = (item.sourceSenderId ?? '').trim().isNotEmpty
        ? item.sourceSenderId!
        : _senderLabel(item);
    final avatarColor = _avatarColor(hueKey);
    final initial = _avatarInitial(item);
    final timeStr = _formatItemTime(item.sentAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: avatarColor,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _senderLabel(item),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timeStr.isNotEmpty)
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 12,
                            color: FlareThemeTokens.textTertiary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F1FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      messageTypeShortLabel(item.messageTypeWire, item.content),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: FlareImDesign.messageBubbleSenderFill,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PlainTextEmojiRich(
          text: _itemPreviewLine(item),
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: FlareThemeTokens.textSecondary,
          ),
          unknownBracketStyle: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: FlareThemeTokens.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (_shouldShowContentEmbed(item.content)) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              color: FlareThemeTokens.bgTertiary.withValues(alpha: 0.6),
              child: embedBuilder(
                context,
                item.content,
                asOutgoingBubble: false,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// —— 工具 —————————————————————————————————————————————————————————

String _senderLabel(ForwardSnapshotItem it) {
  final name = (it.senderName ?? '').trim();
  if (name.isNotEmpty) return name;
  final id = (it.sourceSenderId ?? '').trim();
  if (id.isNotEmpty) {
    return id.length > 12
        ? '${id.substring(0, 6)}…${id.substring(id.length - 4)}'
        : id;
  }
  return '未知发送者';
}

String _itemPreviewLine(ForwardSnapshotItem it) {
  final plain = (it.plainText ?? '').trim();
  if (plain.isNotEmpty) return formatStoragePreview(plain);
  final fromContent = it.content.previewText.trim();
  if (fromContent.isNotEmpty) return fromContent;
  return '[${messageTypeShortLabel(it.messageTypeWire, it.content)}]';
}

String _truncateLine(String s, int maxChars) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.length <= maxChars) return t;
  return '${t.substring(0, math.max(0, maxChars - 1))}…';
}

bool _shouldShowContentEmbed(MessageContent c) {
  if (c is TextContent) return false;
  if (c is ForwardContent) return false;
  return true;
}

String _pad2(int n) => n.toString().padLeft(2, '0');

String _formatItemTime(DateTime? t) {
  if (t == null) return '';
  final now = DateTime.now();
  final sameDay =
      t.year == now.year && t.month == now.month && t.day == now.day;
  if (sameDay) {
    return '${_pad2(t.hour)}:${_pad2(t.minute)}';
  }
  return '${t.month}/${t.day} ${_pad2(t.hour)}:${_pad2(t.minute)}';
}

String _avatarInitial(ForwardSnapshotItem it) {
  final s = _senderLabel(it).trim();
  if (s.isEmpty) return '?';
  final i = s.runes.iterator;
  if (!i.moveNext()) return '?';
  return String.fromCharCode(i.current).toUpperCase();
}

Color _avatarColor(String key) {
  var h = 0;
  for (var i = 0; i < key.length; i++) {
    h = (h * 31 + key.codeUnitAt(i)) & 0x7fffffff;
  }
  return HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.42, 0.52).toColor();
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
