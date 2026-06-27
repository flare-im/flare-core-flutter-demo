import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/message/message_style.dart';
import 'package:flare_im/interface/widgets/message/plain_text_emoji_rich.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

// 引用回复：上方灰蓝引用条（左蓝竖线 + 昵称 + 摘要），下方为回复正文，右下时间与送达态。
class QuoteView extends StatelessWidget {
  static const Color _quoteBarBlue = Color(0xFF1A73E8);
  static const Color _quotePanelBgLight = Color(0xFFF0F4F8);
  static const double _quoteRadius = 8;
  static const double _quoteBarWidth = 4;

  final String? quotedTextPreview;
  final String? quotedSenderName;
  final MessageContent content;
  final bool isSelf;
  final MessageStatus? messageStatus;
  final String? footerTimeText;

  const QuoteView({
    super.key,
    required this.quotedTextPreview,
    required this.content,
    required this.isSelf,
    this.quotedSenderName,
    this.messageStatus,
    this.footerTimeText,
  });

  Color _quotePanelBg(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return FlareDarkThemeTokens.bubbleOther;
    }
    return _quotePanelBgLight;
  }

  Widget? _statusWidget(Color meta) {
    final s = messageStatus;
    if (!isSelf || s == null) return null;
    switch (s) {
      case MessageStatus.sending:
        return SizedBox(
          width: 11,
          height: 11,
          child: CircularProgressIndicator(strokeWidth: 1.2, color: meta),
        );
      case MessageStatus.sent:
      case MessageStatus.delivered:
        return Icon(Icons.check, size: 14, color: meta);
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 14, color: meta);
      case MessageStatus.failed:
        return null;
    }
  }

  Color _metaColor(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return FlareDarkThemeTokens.textSecondary.withValues(alpha: 0.9);
    }
    return isSelf
        ? FlareImDesign.messageBubbleSenderMeta
        : FlareImDesign.messageBubbleReceiverMeta;
  }

  Widget _replyBody(BuildContext context, Color fg, Color secondaryFg) {
    if (content is TextContent) {
      final t = (content as TextContent).text;
      return PlainTextEmojiRich(
        text: t,
        style: TextStyle(
          color: fg,
          fontSize: FlareImDesign.messageBubbleFontSize,
          height: FlareImDesign.messageBubbleTextHeight,
        ),
        unknownBracketStyle: TextStyle(
          color: secondaryFg,
          fontSize: FlareImDesign.messageBubbleFontSize,
          height: FlareImDesign.messageBubbleTextHeight,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    return Text(
      content.previewText,
      style: TextStyle(
        color: fg,
        fontSize: FlareImDesign.messageBubbleFontSize,
        height: FlareImDesign.messageBubbleTextHeight,
      ),
    );
  }

  Widget _footerRow(BuildContext context, Color meta) {
    final time = footerTimeText?.trim();
    final status = _statusWidget(meta);
    if ((time == null || time.isEmpty) && status == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(
        top: FlareImDesign.messageBubbleFooterGapTop,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (time != null && time.isNotEmpty)
            Text(
              time,
              style: TextStyle(
                fontSize: FlareImDesign.messageBubbleTimestampFontSize,
                height: 1.2,
                color: meta,
              ),
            ),
          if (time != null && time.isNotEmpty && status != null)
            const SizedBox(width: FlareImDesign.messageBubbleInlineMetaGap),
          ?status,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fg = isSelf
        ? MessageBubbleStyle.selfBubbleForeground(context)
        : MessageBubbleStyle.otherBubbleForeground(context);
    final quoteFg = Theme.of(context).brightness == Brightness.dark
        ? FlareDarkThemeTokens.textSecondary
        : const Color(0xFF4E5969);
    final sender = (quotedSenderName ?? '').trim();
    final preview = (quotedTextPreview ?? '').trim();
    final meta = _metaColor(context);

    final hasQuoteStrip = sender.isNotEmpty || preview.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FlareImDesign.messageBubblePaddingH,
        vertical: FlareImDesign.messageBubblePaddingV,
      ),
      decoration: MessageBubbleStyle.bubbleDecoration(context, isSelf: isSelf),
      child: Column(
        // 避免 stretch + 子树内 Row/Expanded 在水平无界约束下无法 layout
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasQuoteStrip)
            DecoratedBox(
              decoration: BoxDecoration(
                color: _quotePanelBg(context),
                borderRadius: BorderRadius.circular(_quoteRadius),
                border: const Border(
                  left: BorderSide(color: _quoteBarBlue, width: _quoteBarWidth),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (sender.isNotEmpty) ...[
                      Text(
                        sender,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: _quoteBarBlue,
                        ),
                      ),
                      if (preview.isNotEmpty) const SizedBox(height: 4),
                    ],
                    if (preview.isNotEmpty)
                      PlainTextEmojiRich(
                        text: preview,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: quoteFg,
                        ),
                        unknownBracketStyle: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: quoteFg.withValues(alpha: 0.85),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (hasQuoteStrip) const SizedBox(height: 8),
          _replyBody(
            context,
            fg,
            isSelf
                ? fg.withValues(alpha: 0.88)
                : FlareThemeTokens.textSecondary,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _footerRow(context, meta),
          ),
        ],
      ),
    );
  }
}
