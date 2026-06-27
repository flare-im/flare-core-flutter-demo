import 'dart:math' as math;

import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/message/business_system/system_feature_bridge.dart';
import 'package:flare_im/interface/widgets/message/message_style.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

/// 投票消息卡片：仅作业务系统入口，真实投票在 App 内完成；不展示百分比或结果条。
///
/// 视觉综合「发起投票」头区 + 左侧强调条 + 编号选项胶囊 + 底栏说明与 CTA。
class VoteView extends StatelessWidget {
  final bool isSelf;
  final String? voteId;
  final String? headline;
  final List<String> options;
  final Map<String, String> metadata;
  final MessageStatus? messageStatus;
  final String? footerTimeText;

  const VoteView({
    super.key,
    required this.isSelf,
    this.voteId,
    this.headline,
    this.options = const [],
    this.metadata = const {},
    this.messageStatus,
    this.footerTimeText,
  });

  static const double _accentWidth = 4;

  /// 较链接卡略紧，适配移动端一屏展示更多内容。
  static const double _hPad = 10;
  static const double _optionRadius = 14;

  String _titleLine() {
    final h = headline?.trim();
    if (h != null && h.isNotEmpty) return h;
    return '投票';
  }

  String? _metaPick(String key) {
    final v = metadata[key]?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  /// 标题下方副文案：参与人展示等（业务侧通过 metadata 下发）。
  String? _participantLine() {
    final direct = _metaPick('participants') ?? _metaPick('participantNames');
    if (direct != null) return '参与人 · $direct';
    return null;
  }

  /// 选项数说明（引导到业务 App）。
  String? _optionsHintLine() {
    if (options.isEmpty) return null;
    return '共 ${options.length} 个选项 · 在 App 内完成选择';
  }

  /// 卡片最底部灰字：如「23 人参与 · 已截止」。
  String? _footerStatusLine() {
    final custom = _metaPick('footer') ?? _metaPick('statusLine');
    if (custom != null) return custom;

    final count =
        _metaPick('participantCount') ??
        _metaPick('participantsCount') ??
        _metaPick('count');
    final status =
        _metaPick('status') ?? _metaPick('voteStatus') ?? _metaPick('state');
    final parts = <String>[];
    if (count != null && count.isNotEmpty) {
      parts.add('$count 人参与');
    }
    if (status != null && status.isNotEmpty) {
      parts.add(status);
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  Color _stripBackground(BuildContext context) {
    if (isSelf) {
      return Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.white;
    }
    return Colors.transparent;
  }

  Color _titleColor(BuildContext context) {
    if (isSelf) return FlareThemeTokens.textPrimary;
    return MessageBubbleStyle.otherBubbleForeground(context);
  }

  Color _optionFill(BuildContext context) {
    if (isSelf) {
      return FlareThemeTokens.primary.withValues(alpha: 0.1);
    }
    return FlareThemeTokens.bgTertiary;
  }

  void _openVote() {
    openSystemFeature(voteId);
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final readIconColor = light
        ? FlareImDesign.messageBubbleSenderFill
        : FlareThemeTokens.primary;

    final title = _titleLine();
    final participantLine = _participantLine();
    final optionsHint = _optionsHintLine();
    final footerLine = _footerStatusLine();
    final canOpen = voteId != null && voteId!.trim().isNotEmpty;
    final hasFooterTime =
        footerTimeText != null && footerTimeText!.trim().isNotEmpty;
    const metaColor = FlareThemeTokens.textSecondary;
    final bubbleR = MessageBubbleStyle.bubbleRadius(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final rawMax = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : FlareImDesign.messageRichCardFallbackMaxWidth;
        final innerTextMax = math.max(
          FlareImDesign.messageRichCardMinTextWidth,
          rawMax - _accentWidth - _hPad * 2,
        );

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: rawMax),
          child: IntrinsicWidth(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(bubbleR),
                onTap: () {
                  if (canOpen) {
                    _openVote();
                  } else {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(content: Text('暂无法打开投票（缺少 voteId）')),
                    );
                  }
                },
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
                            width: _accentWidth,
                            color: FlareThemeTokens.primary,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  color: _stripBackground(context),
                                  padding: const EdgeInsets.fromLTRB(
                                    _hPad,
                                    7,
                                    _hPad,
                                    6,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.bar_chart_rounded,
                                        size: 17,
                                        color: FlareThemeTokens.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '发起投票',
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.25,
                                          fontWeight: FontWeight.w600,
                                          color: _titleColor(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: FlareThemeTokens.borderPrimary
                                      .withValues(alpha: 0.45),
                                ),
                                Container(
                                  color: _stripBackground(context),
                                  padding: const EdgeInsets.fromLTRB(
                                    _hPad,
                                    8,
                                    _hPad,
                                    6,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: innerTextMax,
                                        ),
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 15,
                                            height: 1.3,
                                            fontWeight: FontWeight.w700,
                                            color: _titleColor(context),
                                          ),
                                        ),
                                      ),
                                      if (participantLine != null) ...[
                                        const SizedBox(height: 4),
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: innerTextMax,
                                          ),
                                          child: Text(
                                            participantLine,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              height: 1.3,
                                              color: metaColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (optionsHint != null) ...[
                                        const SizedBox(height: 3),
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: innerTextMax,
                                          ),
                                          child: Text(
                                            optionsHint,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              height: 1.3,
                                              color: metaColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (options.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        for (var i = 0; i < options.length; i++)
                                          Padding(
                                            padding: EdgeInsets.only(
                                              bottom: i == options.length - 1
                                                  ? 0
                                                  : 5,
                                            ),
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxWidth: innerTextMax,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  SizedBox(
                                                    width: 22,
                                                    child: Text(
                                                      '${i + 1}.',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        height: 1.25,
                                                        color: metaColor,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: DecoratedBox(
                                                      decoration: BoxDecoration(
                                                        color: _optionFill(
                                                          context,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              _optionRadius,
                                                            ),
                                                        border: Border.all(
                                                          color:
                                                              FlareThemeTokens
                                                                  .borderPrimary
                                                                  .withValues(
                                                                    alpha: 0.65,
                                                                  ),
                                                        ),
                                                      ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 5,
                                                            ),
                                                        child: Text(
                                                          options[i],
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            height: 1.28,
                                                            color: _titleColor(
                                                              context,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ] else ...[
                                        const SizedBox(height: 6),
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: innerTextMax,
                                          ),
                                          child: const Text(
                                            '选项与投票请在 App 内完成',
                                            style: TextStyle(
                                              fontSize: 12,
                                              height: 1.35,
                                              color: metaColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (footerLine != null) ...[
                                        const SizedBox(height: 6),
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: innerTextMax,
                                          ),
                                          child: Text(
                                            footerLine,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              height: 1.35,
                                              color:
                                                  FlareThemeTokens.textTertiary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: FlareThemeTokens.borderPrimary
                                      .withValues(alpha: 0.45),
                                ),
                                Container(
                                  color: _stripBackground(context),
                                  padding: const EdgeInsets.fromLTRB(
                                    _hPad,
                                    7,
                                    _hPad,
                                    7,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: canOpen
                                                ? _openVote
                                                : () {
                                                    ScaffoldMessenger.maybeOf(
                                                      context,
                                                    )?.showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          '暂无法打开投票（缺少 voteId）',
                                                        ),
                                                      ),
                                                    );
                                                  },
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Ink(
                                              decoration: BoxDecoration(
                                                color: FlareThemeTokens.primary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: FlareThemeTokens
                                                      .primary
                                                      .withValues(alpha: 0.45),
                                                ),
                                              ),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 6,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '参与投票',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: FlareThemeTokens
                                                          .primary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (isSelf &&
                                          (hasFooterTime ||
                                              messageStatus != null)) ...[
                                        const SizedBox(width: 8),
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
                                    ],
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
