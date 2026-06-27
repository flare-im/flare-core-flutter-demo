import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/message/message_style.dart';
import 'package:flare_im/interface/widgets/message/plain_text_emoji_rich.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

// 文本气泡：Markdown / 表情 / 送达与已读布局。
class TextView extends StatelessWidget {
  final String text;
  final bool isSelf;
  final MessageStatus? messageStatus;

  /// 与正文同一气泡容器底部（如反应），飞书式一体化。
  final Widget? bubbleFooter;

  const TextView({
    super.key,
    required this.text,
    required this.isSelf,
    this.messageStatus,
    this.bubbleFooter,
  });

  static const double _inlineEmojiEm = 1.72;

  static EdgeInsets _bubblePadding() => const EdgeInsets.symmetric(
    horizontal: FlareImDesign.messageBubblePaddingH,
    vertical: FlareImDesign.messageBubblePaddingV,
  );

  static double get _fontSize => FlareImDesign.messageBubbleFontSize;
  static double get _textHeight => FlareImDesign.messageBubbleTextHeight;

  String? _localeTag(BuildContext context) {
    return Localizations.maybeLocaleOf(context)?.toLanguageTag();
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

  Color _statusColor(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return FlareDarkThemeTokens.textSecondary.withValues(alpha: 0.9);
    }
    return FlareImDesign.messageBubbleSenderMeta;
  }

  Widget _bubbleChrome(
    BuildContext context, {
    required Widget body,
    required int Function(double maxTextWidth) measureLines,
  }) {
    final meta = _statusColor(context);
    final status = _statusWidget(meta);
    final footer = bubbleFooter;

    Widget stackCore() {
      if (status == null) {
        return IntrinsicWidth(child: body);
      }
      // 不用 [LayoutBuilder]：其父级在宽约束较大时会把可用宽一直传到子树，叠上
      // [CrossAxisAlignment.stretch] 会把己方多行气泡拉满整行；改为按设计上限算 inner 宽，
      // 与外层 [ConstrainedBox(maxWidth: messageBubbleMaxWidthForScreen)] 一致。
      final maxBubble = FlareImDesign.messageBubbleMaxWidthForScreen(
        context,
        isSelf: isSelf,
      );
      const padH = FlareImDesign.messageBubblePaddingH;
      final innerMax = (maxBubble - 2 * padH).clamp(8.0, maxBubble);
      const gap = FlareImDesign.messageBubbleInlineMetaGap;
      const reserve = FlareImDesign.messageBubbleStatusReserveWidth;
      final textMax = (innerMax - reserve - gap).clamp(8.0, innerMax);
      final lines = measureLines(textMax);
      if (lines <= 1) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: textMax),
              child: body,
            ),
            const SizedBox(width: gap),
            status,
          ],
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: innerMax),
            child: Align(alignment: Alignment.centerRight, child: body),
          ),
          const SizedBox(height: FlareImDesign.messageBubbleStatusSeparateGap),
          Align(alignment: Alignment.centerRight, child: status),
        ],
      );
    }

    // 反应条不再锁成「正文宽度」：用 [IntrinsicWidth] 取 [Wrap] 的单行固有宽，
    // 与正文同列后气泡宽 = max(正文, 反应单行)，仍由外层 [ConstrainedBox] 封顶。
    final chromeChild = footer == null
        ? stackCore()
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isSelf
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              stackCore(),
              Padding(
                padding: const EdgeInsets.only(
                  top: FlareImDesign.messageBubbleFooterGapTop,
                ),
                child: Align(
                  alignment: isSelf
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: IntrinsicWidth(child: footer),
                ),
              ),
            ],
          );

    return Container(
      decoration: MessageBubbleStyle.bubbleDecoration(context, isSelf: isSelf),
      padding: _bubblePadding(),
      child: chromeChild,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fg = isSelf
        ? MessageBubbleStyle.selfBubbleForeground(context)
        : MessageBubbleStyle.otherBubbleForeground(context);
    final secondary = isSelf
        ? FlareImDesign.messageBubbleSenderMeta
        : FlareImDesign.messageBubbleReceiverMeta;
    final locale = _localeTag(context);

    final plan = buildPlainTextEmojiLayoutPlan(
      context,
      text: text,
      textStyle: TextStyle(color: fg, fontSize: _fontSize, height: _textHeight),
      secondaryForeground: secondary,
      inlineEmojiEm: _inlineEmojiEm,
      localeTag: locale,
      stickerLikeMaxSide: FlareImDesign.messageStickerLikeAssetMaxSide,
      inlineOnly: false,
    );

    return _bubbleChrome(
      context,
      body: plan.body,
      measureLines: plan.measureLines,
    );
  }
}
