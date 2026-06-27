import 'dart:math' as math;

import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/message/message_style.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

// 语音消息。
///
/// 己方：蓝色胶囊条（麦克风 + 波形 + 秒数），右侧灰字时间与送达/已读图标（参考设计图一）。
/// 对方：浅色描边胶囊条，深色前景。
class AudioView extends StatelessWidget {
  final String? url;
  final String? localPath;
  final int? durationSec;
  final String? messageId;
  final bool isSelf;
  final MessageStatus? messageStatus;
  final String? footerTimeText;

  const AudioView({
    super.key,
    this.url,
    this.localPath,
    this.durationSec,
    this.messageId,
    required this.isSelf,
    this.messageStatus,
    this.footerTimeText,
  });

  static const double _pillMinWidth = 200;
  static const double _pillHeight = 46;
  static const double _pillMaxWidth = 280;

  /// 有时长（秒）时返回展示文案；否则不显示占位秒数。
  static String? formatDurationSeconds(int? sec) {
    if (sec == null || sec <= 0) return null;
    if (sec < 60) return '$sec"';
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  int get _waveSeed => Object.hash(
    url ?? '',
    localPath ?? '',
    durationSec ?? 0,
    messageId ?? '',
  );

  @override
  Widget build(BuildContext context) {
    final pill = _voicePill(context);
    final hasFooterTime =
        footerTimeText != null && footerTimeText!.trim().isNotEmpty;

    if (!isSelf) {
      if (!hasFooterTime) return pill;
      final light = Theme.of(context).brightness == Brightness.light;
      final timeColor = light
          ? FlareThemeTokens.textSecondary
          : FlareThemeTokens.textSecondary.withValues(alpha: 0.9);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(child: pill),
          const SizedBox(width: 10),
          Text(
            footerTimeText!.trim(),
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: timeColor,
            ),
          ),
        ],
      );
    }

    if (!hasFooterTime && messageStatus == null) return pill;

    final light = Theme.of(context).brightness == Brightness.light;
    final timeColor = light
        ? FlareThemeTokens.textSecondary
        : FlareThemeTokens.textSecondary.withValues(alpha: 0.9);
    final readIconColor = light
        ? FlareImDesign.messageBubbleSenderFill
        : FlareThemeTokens.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(child: pill),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (hasFooterTime)
              Text(
                footerTimeText!.trim(),
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: timeColor,
                ),
              ),
            if (hasFooterTime && messageStatus != null)
              const SizedBox(height: 3),
            if (messageStatus != null)
              _outsideStatusIcon(messageStatus!, readIconColor),
          ],
        ),
      ],
    );
  }

  Widget _voicePill(BuildContext context) {
    final bg = isSelf
        ? MessageBubbleStyle.selfBubbleBackground(context)
        : MessageBubbleStyle.otherBubbleBackground(context);
    final fg = isSelf
        ? MessageBubbleStyle.selfBubbleForeground(context)
        : MessageBubbleStyle.otherBubbleForeground(context);
    final border = MessageBubbleStyle.bubbleBorder(context, isSelf: isSelf);
    final inactive = fg.withValues(alpha: isSelf ? 0.45 : 0.35);
    final active = fg.withValues(alpha: isSelf ? 1.0 : 0.85);
    final durLabel = formatDurationSeconds(durationSec);

    return LayoutBuilder(
      builder: (context, constraints) {
        final rawMax = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : _pillMaxWidth;
        final maxW = math.min(_pillMaxWidth, rawMax);
        // 与外侧 Row 并排时间/状态时，父级会变窄；min 不得超过 max，避免 RenderFlex 溢出。
        final minW = math.min(_pillMinWidth, maxW);
        return ConstrainedBox(
          constraints: BoxConstraints(minWidth: minW, maxWidth: maxW),
          child: Container(
            height: _pillHeight,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(_pillHeight / 2),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Icon(Icons.mic_none_rounded, size: 22, color: fg),
                const SizedBox(width: 10),
                Expanded(
                  child: _WaveformBars(
                    seed: _waveSeed,
                    activeColor: active,
                    inactiveColor: inactive,
                    progress: 0.45,
                  ),
                ),
                if (durLabel != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    durLabel,
                    style: TextStyle(
                      color: fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _outsideStatusIcon(MessageStatus status, Color readColor) {
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

/// 示意波形条（占位；后续可接播放进度）。
class _WaveformBars extends StatelessWidget {
  const _WaveformBars({
    required this.seed,
    required this.activeColor,
    required this.inactiveColor,
    required this.progress,
  });

  final int seed;
  final Color activeColor;
  final Color inactiveColor;
  final double progress;

  static const int _count = 7;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_count, (i) {
          final h = 6.0 + ((seed >> (i * 4)) & 0xf) * 1.15;
          final clamped = h.clamp(6.0, 22.0);
          final t = (i + 0.5) / _count;
          final isActive = t <= progress;
          return Container(
            width: 3,
            height: clamped,
            decoration: BoxDecoration(
              color: isActive ? activeColor : inactiveColor,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}
