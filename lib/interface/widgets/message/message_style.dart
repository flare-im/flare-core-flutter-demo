import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

/// 聊天气泡与内容区在亮/暗色下的颜色与描边。
/// 亮色发送/接收色来自 [FlareImDesign]（对齐 IM 参考图）；暗色仍用 [FlareDarkThemeTokens]。
abstract final class MessageBubbleStyle {
  static Color selfBubbleBackground(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? FlareDarkThemeTokens.bubbleSelf
        : FlareImDesign.messageBubbleSenderFill;
  }

  static Color selfBubbleForeground(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? FlareDarkThemeTokens.textPrimary
        : FlareImDesign.messageBubbleSenderForeground;
  }

  static Color otherBubbleBackground(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : FlareImDesign.messageBubbleReceiverFill;
  }

  static Color otherBubbleForeground(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? Theme.of(context).colorScheme.onSurface
        : FlareImDesign.messageBubbleReceiverForeground;
  }

  static Color bubbleBorder(BuildContext context, {required bool isSelf}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      if (isSelf) {
        return FlareThemeTokens.borderPrimary.withValues(alpha: 0.35);
      }
      return Theme.of(context).colorScheme.outline.withValues(alpha: 0.35);
    }
    if (isSelf) {
      return Colors.transparent;
    }
    return FlareImDesign.messageBubbleReceiverBorder;
  }

  static double bubbleRadius(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? 20 : FlareImDesign.messageBubbleCornerRadius;
  }

  static BoxDecoration bubbleDecoration(
    BuildContext context, {
    required bool isSelf,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final r = bubbleRadius(context);
    if (dark) {
      return BoxDecoration(
        color: isSelf
            ? selfBubbleBackground(context)
            : otherBubbleBackground(context),
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: bubbleBorder(context, isSelf: isSelf)),
      );
    }
    // 亮色：发送方蓝底无边框，接收方白底浅灰边
    return BoxDecoration(
      color: isSelf
          ? FlareImDesign.messageBubbleSenderFill
          : FlareImDesign.messageBubbleReceiverFill,
      borderRadius: BorderRadius.circular(r),
      border: isSelf
          ? null
          : Border.all(
              color: FlareImDesign.messageBubbleReceiverBorder,
              width: FlareImDesign.messageBubbleReceiverBorderWidth,
            ),
    );
  }
}

/// 仅对「intrinsic 安全」的 [MessageContent] 在 [ConstrainedBox] 外包 [IntrinsicWidth]，使气泡水平方向随内容收缩。
///
/// - 图音视频、文件、合并转发、卡片等子树常含 [LayoutBuilder]，排除。
/// - 己方 [TextContent] 的送达/已读行宽改由 [TextView] 用 [messageBubbleMaxWidthForScreen] 推算，
///   不再使用 [LayoutBuilder]，可与 [IntrinsicWidth] 同用，气泡随内容变宽而非一次撑满上限。
bool messageContentAllowsBubbleIntrinsicWidth(MessageContent content) {
  if (content is TextContent || content is RichDocContent) {
    return true;
  }
  return content is EmojiContent ||
      content is StickerContent ||
      content is QuoteContent;
}

/// 气泡内容区：上限 [FlareImDesign.messageBubbleMaxWidthForScreen]；白名单类型额外 [IntrinsicWidth] 贴内容宽。
Widget messageBubbleContentWidthScope({
  required BuildContext context,
  required bool isSelf,
  required MessageContent content,
  required MessageStatus messageStatus,
  required Widget child,
}) {
  final maxW = FlareImDesign.messageBubbleMaxWidthForScreen(
    context,
    isSelf: isSelf,
  );
  final boxed = ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxW),
    child: child,
  );
  if (!messageContentAllowsBubbleIntrinsicWidth(content)) {
    return boxed;
  }
  return IntrinsicWidth(child: boxed);
}
