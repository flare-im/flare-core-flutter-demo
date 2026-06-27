import 'dart:math' as math;

import 'package:flare_call_kit/flare_call_kit.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

// 通知视图：飞书式会话内灰条（进群、禁言等系统提示），居中、浅底、无卡片描边。
class NotificationView extends StatelessWidget {
  /// 飞书类 IM 常用灰底提示色
  static const Color _feishuTipBg = Color(0xFFF2F3F5);
  static const Color _feishuTipFg = Color(0xFF86909C);

  static const double _maxOuterWidth = 320;
  static const double _radius = 6;

  final NotificationContent content;

  const NotificationView({super.key, required this.content});

  /// 合并标题与正文：正文优先；标题为泛化「系统通知」时不重复展示。
  String _displayText() {
    final t = (content.title ?? '').trim();
    final b = (content.body ?? '').trim();
    if (b.isNotEmpty) {
      if (t.isEmpty || t == '系统通知') return b;
      return '$t：$b';
    }
    if (t.isNotEmpty) return t;
    return '通知';
  }

  @override
  Widget build(BuildContext context) {
    if ((content.notificationType ?? '').trim().toLowerCase() ==
        'call_signal') {
      final meta = parseCallSignalNoticeUiMeta(
        body: (content.body ?? '').trim(),
        data: content.data,
      );
      if (meta == null) {
        return const SizedBox.shrink();
      }
      return CallNoticeTile(
        icon: meta.icon == 'video'
            ? Icons.videocam_rounded
            : Icons.call_rounded,
        text: meta.text,
        durationText: meta.durationText,
      );
    }
    final text = _displayText();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cap = constraints.maxWidth.isFinite
            ? math.min(constraints.maxWidth, _maxOuterWidth)
            : _maxOuterWidth;

        return Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: cap),
            child: Semantics(
              label: text,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? FlareDarkThemeTokens.bgTertiary
                      : _feishuTipBg,
                  borderRadius: BorderRadius.circular(_radius),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? FlareDarkThemeTokens.textSecondary
                          : _feishuTipFg,
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
}
