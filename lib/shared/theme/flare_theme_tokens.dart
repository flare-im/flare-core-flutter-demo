// 基础 token 对齐自 kit flare-im-design/tokens/tokens.json（三端单一真源）。
// 品牌/语义色 + app 复合 token(login*/conversationList*/composer* 等)保留;
// 中性色阶/圆角已收敛到 kit,消除与 iOS/Android 的漂移。

import 'package:flutter/material.dart';

abstract final class FlareThemeTokens {
  static const Color primary = Color(0xFF7C3AED);
  static const Color primaryHover = Color(0xFF6D28D9);
  static const Color primaryActive = Color(0xFF5B21B6);

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF6D5DF6);

  static const Color robot = Color(0xFF64748B);
  static const Color important = Color(0xFFF59E0B);
  static const Color pinned = Color(0xFF7C3AED);

  static const Color bgPrimary = Color(0xFFFFFFFF);
  static const Color bgSecondary = Color(0xFFF6F5FB);
  static const Color bgTertiary = Color(0xFFF3F1F9);
  static const Color bgHover = Color(0xFFF1EEF8);
  static const Color bgSelected = Color(0xFFF1EAFF);
  static const Color bgDisabled = Color(0xFFF3F1F9);

  static const Color textPrimary = Color(0xFF15131C);
  static const Color textSecondary = Color(0xFF6B6780);
  static const Color textTertiary = Color(0xFFA7A2B4);
  static const Color textDisabled = Color(0xFFCCC8D8);
  static const Color textLink = Color(0xFF7C3AED);
  static const Color textLinkHover = Color(0xFF6D28D9);

  static const Color borderPrimary = Color(0xFFE9E6F1);
  static const Color borderSecondary = Color(0xFFF0EDF7);
  static const Color borderHover = Color(0xFFDAD5E7);
  static const Color borderSelected = Color(0xFF7C3AED);

  static const Color bubbleSelf = Color(0xFF7C3AED);
  static const Color bubbleOther = Color(0xFFECE5FF);
  static const Color bubbleRobot = Color(0xFFF4F0FF);
  static const Color bubbleSystem = Color(0xFFF3F1F9);

  static const Color loginScreenCanvas = Color(0xFFFFFFFF);
  static const Color loginLogoBackground = Color(0xFFFFFFFF);
  static const Color loginLogoAccent = Color(0xFF7C3AED);
  static const Color loginCardSurface = Color(0xFFFFFFFF);
  static const Color loginCardBorder = Color(0xFFE7E9EE);
  static const Color loginSubtitle = Color(0xFF6B7280);
  static const Color loginHint = Color(0xFFA3A7AE);
  static const Color loginCtaBackground = Color(0xFF7C3AED);
  static const Color loginCtaForeground = Color(0xFFFFFFFF);
  static const Color loginInputBorder = Color(0xFFE5E5E5);
  static const Color loginInputFill = Color(0xFFF5F6F8);

  static const double radiusXs = 3;
  static const double radiusSm = 6;
  static const double radiusMd = 8;
  static const double radiusLg = 10;
  static const double radiusXl = 14;
  static const double radius2xl = 18;
  static const double radiusFull = 999;

  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 12;
  static const double spacingLg = 16;
  static const double spacingXl = 20;
  static const double spacing2xl = 24;

  static const Color conversationListCanvas = Color(0xFFFFFFFF);
  static const Color conversationListDivider = Color(0xFFEEF0F4);
  static const Color conversationListSearchStroke = Color(0xFFE9D5FF);
  static const Color conversationListPinnedBorder = Color(0x8CC4B5FD);
  static const Color conversationListPinnedTile = Color(0xFFF5F3FF);
  static const Color conversationListPinnedAvatar = Color(0xFFEDE9FE);
  static const Color conversationListItemStroke = Color(0xFFE3EAF5);
  static const Color conversationListAvatarFallback = Color(0xFFE8EEF8);
  static const Color conversationListPinLabel = Color(0xFF7C3AED);
  static const Color conversationListDraftAccent = Color(0xFFEA580C);
  static const Color conversationListMentionAccent = Color(0xFFEA580C);
  static const Color conversationListQuoteWarning = Color(0xFFD48806);
  static const Color conversationListOnlineDot = Color(0xFF16A34A);
  static const Color conversationListUnreadBadgeBg = Color(0xFF7C3AED);
  static const Color conversationListUnreadBadgeFg = Color(0xFFFFFFFF);

  static const Color composerToolbarIcon = Color(0xFF6B7280);
  static const Color composerSendBackground = Color(0xFF7C3AED);
  static const Color composerSendForeground = Color(0xFFFFFFFF);
  static const Color composerSendDisabledBg = Color(0xFFE8EAEF);
  static const Color composerSendDisabledFg = Color(0xFFB0B5BF);
  static const Color composerReplyStripBg = Color(0xFFF5F5F5);
  static const Color composerReplyStripBorder = Color(0x0F000000);
  static const Color composerReplyStripLabel = Color(0xFF646A73);
  static const Color composerReplyStripPreview = Color(0xFF8F959E);
  static const Color composerReplyStripClose = Color(0xFF86909C);
  static const Color composerReplyStripSep = Color(0xFFE0E0E0);

  static const Color messageReadReceipt = Color(0xFF7C3AED);
  static const Color messageStatusMuted = Color(0xFF6B7280);
  static const Color messageMediaPlaceholderBg = Color(0xFFF2F3F5);
  static const Color messageVideoPlayOverlay = Color(0x8F000000);

  static const Color chatCanvas = Color(0xFFF7F6FB);
  static const Color chatSelfBubbleFill = Color(0xFF7C3AED);
  static const Color chatConnectionBannerBg = Color(0xFFF3E8FF);
  static const Color chatConnectionBannerFg = Color(0xFF5B21B6);
}

abstract final class FlareDarkThemeTokens {
  static const Color bgPrimary = Color(0xFF1B1922);
  static const Color bgSecondary = Color(0xFF131019);
  static const Color bgTertiary = Color(0xFF232030);
  static const Color bgHover = Color(0x0FFFFFFF);
  static const Color bgSelected = Color(0x337C3AED);

  static const Color textPrimary = Color(0xF0FFFFFF);
  static const Color textSecondary = Color(0x9EFFFFFF);
  static const Color textTertiary = Color(0x66FFFFFF);
  static const Color textLink = Color(0xFFC4B5FD);

  static const Color borderPrimary = Color(0x1AFFFFFF);
  static const Color borderSecondary = Color(0x14FFFFFF);
  static const Color borderSelected = Color(0xFFA78BFA);

  static const Color bubbleSelf = Color(0xFF8B5CF6);
  static const Color bubbleOther = Color(0xFF241D33);
  static const Color bubbleRobot = Color(0xFF2B2340);
}
