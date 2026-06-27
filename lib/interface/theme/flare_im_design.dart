import 'dart:math' as math;

import 'package:flare_im/shared/theme/app_theme.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

/// 应用内 UI 常量：CloudChat 风格品牌紫 + 登录渐变头 + 会话列表扁平白底。
abstract final class FlareImDesign {
  // —— 品牌紫（与 [FlareThemeTokens.primary] 一致）——
  static const Color brandPurple = FlareThemeTokens.primary;
  static const Color brandPurpleHover = FlareThemeTokens.primaryHover;
  static const Color brandPurpleActive = FlareThemeTokens.primaryActive;

  /// 登录页渐变（上 → 下）
  static const Color loginGradientTop = Color(0xFF7E57FF);
  static const Color loginGradientBottom = Color(0xFF9F7AEA);

  /// 登录头图上的主文案
  static const Color loginHeaderOnGradient = Color(0xFFFFFFFF);
  static const Color loginHeaderSlogan = Color(0xE6FFFFFF);

  /// 表单区「信息」图标色（浅紫）
  static const Color loginInfoIconTint = Color(0xFFA78BFA);

  // —— 全局 ——
  static const Color background = FlareThemeTokens.bgSecondary;
  static const Color foreground = FlareThemeTokens.textPrimary;
  static const Color card = FlareThemeTokens.bgPrimary;
  static const Color primary = FlareThemeTokens.primary;
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color border = FlareThemeTokens.borderPrimary;
  static const Color muted = FlareThemeTokens.bgTertiary;
  static const Color mutedForeground = FlareThemeTokens.textSecondary;
  static const Color secondary = FlareThemeTokens.bgHover;
  static const Color destructive = FlareThemeTokens.error;
  static const Color danger = FlareThemeTokens.error;
  static const Color presenceOnline = FlareThemeTokens.success;

  static const Color bubbleSelf = FlareThemeTokens.bubbleSelf;
  static const Color bubbleSelfForeground = FlareThemeTokens.textPrimary;
  static const Color bubbleOther = FlareThemeTokens.bubbleOther;

  // —— 聊天列表画布（极浅紫灰底）——
  static const Color chatMessageListCanvas = FlareThemeTokens.chatCanvas;

  // —— 会话消息气泡（左白底浅灰边 / 右品牌紫无底边，角 16）——
  /// 发送方气泡填充
  static const Color messageBubbleSenderFill = FlareThemeTokens.primary;

  /// 发送方气泡主文案
  static const Color messageBubbleSenderForeground = Color(0xFFFFFFFF);

  /// 发送方气泡内时间、已读双勾等（半透明白）
  static const Color messageBubbleSenderMeta = Color(0xCCFFFFFF);

  /// 接收方气泡填充
  static const Color messageBubbleReceiverFill = Color(0xFFFFFFFF);

  /// 接收方气泡主文案（深灰，非纯黑）
  static const Color messageBubbleReceiverForeground = Color(0xFF1F2937);

  /// 接收方气泡描边
  static const Color messageBubbleReceiverBorder = Color(0xFFE5E7EB);

  /// 接收方描边宽度（设计约 0.5–1px）
  static const double messageBubbleReceiverBorderWidth = 1;

  /// 接收方气泡内时间等
  static const Color messageBubbleReceiverMeta = Color(0xFF9CA3AF);

  /// 己方气泡下方状态行（非文本消息等仍用气泡外提示时）
  static const Color messageBubbleSelfStatusCaption =
      FlareThemeTokens.primaryHover;

  /// 圆角（设计稿 12–16，取 16）
  static const double messageBubbleCornerRadius = 16;

  /// 水平内边距
  static const double messageBubblePaddingH = 14;

  /// 垂直内边距（略紧，短消息不那么「方」）
  static const double messageBubblePaddingV = 9;

  /// 正文与时间块之间的间距（仅分栏布局时用；默认时间与正文同行）
  static const double messageBubbleFooterGapTop = 6;

  /// 同行布局：正文与送达/已读图标之间的水平间距
  static const double messageBubbleInlineMetaGap = 6;

  /// 同行布局：为单勾/双勾预留的横向空间（气泡内不再显示时间）
  static const double messageBubbleStatusReserveWidth = 28;

  /// 多行时状态行与正文间距
  static const double messageBubbleStatusSeparateGap = 4;

  /// 正文字号
  static const double messageBubbleFontSize = 15;

  /// 正文行高系数
  static const double messageBubbleTextHeight = 1.45;

  /// 气泡内右下角时间字号
  static const double messageBubbleTimestampFontSize = 11;

  // —— 气泡最大宽度（与 [ChatScreen] 列表 `SliverPadding` 水平留白一致）——
  /// 相对屏幕宽度的气泡最大比例
  static const double messageBubbleMaxWidthFraction = 0.72;

  /// 列表水平内边距（与 [ChatScreen] 消息列表 `SliverPadding` 左右一致；与 [MessageBubble] 最大宽度计算一致）
  static const double messageBubbleListHorizontalPad = 14;

  /// 对端消息：头像占位宽 + 与气泡间距（36 直径 + 10 间距）
  static const double messageBubblePeerAvatarBlock = 46;

  /// 气泡宽度下限
  static const double messageBubbleMinWidth = 120;

  /// 单条消息气泡内容区最大宽度（与 [MessageBubble] / [messageBubbleContentWidthScope] 一致）。
  ///
  /// 文本 / 表情 / 贴纸 / 引用等在不超过本值的前提下可随内容缩窄（见 [messageContentAllowsBubbleIntrinsicWidth]）；
  /// 己方文本在展示送达/已读等时不套 [IntrinsicWidth]；图音视频与卡片等仅施加上限。
  static double messageBubbleMaxWidthForScreen(
    BuildContext context, {
    required bool isSelf,
  }) {
    final w = MediaQuery.sizeOf(context).width;
    final capByPercent = w * messageBubbleMaxWidthFraction;
    const pad = messageBubbleListHorizontalPad;
    final double slot;
    if (isSelf) {
      slot = w - pad * 2;
    } else {
      slot = w - pad * 2 - messageBubblePeerAvatarBlock;
    }
    return math.max(messageBubbleMinWidth, math.min(capByPercent, slot));
  }

  // —— 富媒体消息卡片（位置 / 链接 / 名片）尺寸 ——
  /// 位置卡片固定展示宽度（实际为 `min(本值, 父级 maxWidth)`）
  static const double messageLocationCardFixedWidth = 264;

  /// 链接卡片缩略图条首选宽度（实际为 `min(本值, 父级 maxWidth)`）
  static const double messageLinkCardThumbnailPreferredWidth = 240;

  /// 链接卡片正文区水平内边距（单侧，双侧合计 ×2）
  static const double messageLinkCardHorizontalPadding = 12;

  /// `LayoutBuilder` 无有效约束时的回退最大宽度（与历史 280 卡片宽一致）
  static const double messageRichCardFallbackMaxWidth = 280;

  /// 链接 / 名片等：正文区最小可用宽度（过窄保护）
  static const double messageRichCardMinTextWidth = 80;

  /// 链接卡片域名行文字区最小宽度
  static const double messageLinkCardDomainRowMinTextWidth = 40;

  /// 链接卡片域名行：地球图标占位 + 与域名间距（约 14 + 5）
  static const double messageLinkCardDomainIconBlock = 19;

  /// 名片卡片：头区水平内边距（单侧）
  static const double messageContactCardHeaderHorizontalPadding = 12;

  /// 名片头像直径（与 [CardView] `_CardAvatar` radius 24 一致）
  static const double messageContactCardAvatarDiameter = 48;

  /// 名片头像与文字列间距
  static const double messageContactCardAvatarToTextGap = 12;

  /// 从父级 `maxWidth` 计算名片标题列上限时的扣减量（左右 padding + 头像 + 间距）
  static double get messageContactCardTextColumnMaxWidthDeduction =>
      messageContactCardHeaderHorizontalPadding * 2 +
      messageContactCardAvatarDiameter +
      messageContactCardAvatarToTextGap;

  /// 会话内「单条仅表情包 / 贴纸级」大图边长上限（与 [StickerView] 一致；动效 WebP 用 [Image.asset]）
  static const double messageStickerLikeAssetMaxSide = 120;

  // —— 登录页 ——
  static const Color loginCanvas = FlareThemeTokens.loginScreenCanvas;
  static const Color loginCard = FlareThemeTokens.loginCardSurface;
  static const Color loginCardBorder = FlareThemeTokens.loginCardBorder;
  static const Color loginTitle = FlareThemeTokens.textPrimary;
  static const Color loginSubtitle = FlareThemeTokens.loginSubtitle;
  static const Color loginHint = FlareThemeTokens.loginHint;
  static const Color loginLogoBg = FlareThemeTokens.loginLogoBackground;
  static const Color loginLogoAccent = FlareThemeTokens.loginLogoAccent;
  static const Color loginCtaBg = FlareThemeTokens.loginCtaBackground;
  static const Color loginCtaFg = FlareThemeTokens.loginCtaForeground;
  static const Color loginInputFill = FlareThemeTokens.loginInputFill;
  static const Color loginInputBorder = FlareThemeTokens.loginInputBorder;

  // —— 会话列表 ——
  static const String conversationListTitle = '消息';

  static const Color mobileCanvas = FlareThemeTokens.conversationListCanvas;
  static const Color mobileDivider = FlareThemeTokens.conversationListDivider;
  static const Color searchStroke =
      FlareThemeTokens.conversationListSearchStroke;

  /// 列表头「搜索」圆形底
  static const Color listHeaderIconCircleBg = Color(0xFFF3F4F6);

  static const Color pinnedTile = FlareThemeTokens.bgPrimary;
  static const Color pinnedAvatar =
      FlareThemeTokens.conversationListPinnedAvatar;
  static const Color listItemStroke = Colors.transparent;
  static const Color listAvatarFallback =
      FlareThemeTokens.conversationListAvatarFallback;
  static const Color draftPreview = FlareThemeTokens.error;

  /// 会话行头像：淡色底 + 深色字（按 id 稳定取色）
  static (Color background, Color foreground) avatarPastelForKey(String key) {
    const pairs = <(Color, Color)>[
      (Color(0xFFDBEAFE), Color(0xFF1D4ED8)),
      (Color(0xFFE9D5FF), Color(0xFF6D28D9)),
      (Color(0xFFFBCFE8), Color(0xFFBE185D)),
      (Color(0xFFD1FAE5), Color(0xFF047857)),
      (Color(0xFFFEF3C7), Color(0xFFB45309)),
      (Color(0xFFE5E7EB), Color(0xFF374151)),
    ];
    if (key.isEmpty) return pairs[0];
    final i = key.hashCode.abs() % pairs.length;
    return pairs[i];
  }

  // —— 深色 ——
  static const Color darkBackground = FlareDarkThemeTokens.bgPrimary;
  static const Color darkForeground = FlareDarkThemeTokens.textPrimary;
  static const Color darkCard = FlareDarkThemeTokens.bgSecondary;
  static const Color darkBorder = FlareDarkThemeTokens.borderPrimary;
  static const Color darkMutedFg = FlareDarkThemeTokens.textSecondary;
  static const Color darkBubbleSelf = FlareDarkThemeTokens.bubbleSelf;
  static const Color darkBubbleOther = FlareDarkThemeTokens.bubbleOther;

  static ThemeData lightTheme() => AppTheme.light();

  static ThemeData darkTheme() => AppTheme.dark();
}
