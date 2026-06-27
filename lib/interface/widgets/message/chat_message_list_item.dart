import 'dart:async';

import 'package:flare_im/application/providers/im_outbound_provider.dart';
import 'package:flare_im/application/providers/message_state_provider.dart';
import 'package:flare_im/application/selectors/message_list_view_model.dart';
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/interface/widgets/message/message.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 在已加载会话消息中查找被引用方展示名（先按 `quotedMessageId` 命中，再按 `quotedSenderId`）。
void _runReaction(BuildContext context, Future<void> Function() fn) {
  unawaited(() async {
    try {
      await fn();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('反应失败：$e')));
    }
  }());
}

String? _resolveQuotedSenderFromMessageList(
  List<Message> list,
  QuoteContent quote,
) {
  final qid = quote.quotedMessageId.trim();
  if (qid.isNotEmpty) {
    for (final m in list) {
      if (m.serverId.isEmpty || m.serverId != qid) continue;
      final d = m.senderDisplayName.trim();
      if (d.isNotEmpty) return d;
      final n = m.senderName.trim();
      if (n.isNotEmpty) return n;
      return null;
    }
  }
  final sid = (quote.quotedSenderId ?? '').trim();
  if (sid.isEmpty) return null;
  for (final m in list) {
    if (m.senderId != sid) continue;
    final d = m.senderDisplayName.trim();
    if (d.isNotEmpty) return d;
    final n = m.senderName.trim();
    if (n.isNotEmpty) return n;
  }
  return null;
}

/// 单条聊天行：独立 Widget + [messageProvider] 的 [select]，仅该行数据变化时重建。
class ChatMessageListItem extends ConsumerWidget {
  const ChatMessageListItem({
    super.key,
    required this.conversationId,
    required this.messageKey,
    required this.currentUserId,
    required this.onEditOwnText,
    this.onStartReply,
    this.multiSelectMode = false,
    this.multiSelectSelected = false,
    this.onToggleMultiSelect,
    this.onStartMultiSelect,
  });

  final String conversationId;
  final String messageKey;
  final String currentUserId;
  final Future<void> Function(Message message) onEditOwnText;
  final void Function(String messageKey)? onStartReply;
  final bool multiSelectMode;
  final bool multiSelectSelected;
  final VoidCallback? onToggleMultiSelect;
  final void Function(String messageKey)? onStartMultiSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(
      messageProvider(
        conversationId,
      ).select((list) => messageRowViewModelForKey(list, messageKey)),
    );
    if (vm == null) return const SizedBox.shrink();

    final im = ref.read(imOutboundProvider);
    final message = vm.message;
    final me = currentUserId;
    final isSelf = me.isNotEmpty && message.senderId == me;
    final isNotification = message.content is NotificationContent;
    final canReply =
        !isNotification &&
        !message.isRecalled &&
        (message.serverId.trim().isNotEmpty ||
            message.clientMsgId.trim().isNotEmpty);
    final pinned = messagePinnedFromExtra(message);
    final copyable = messageCopyPlainText(message) != null;

    final String? quotedSenderResolved = message.content is QuoteContent
        ? ref.watch(
            messageProvider(conversationId).select(
              (list) => _resolveQuotedSenderFromMessageList(
                list,
                message.content as QuoteContent,
              ),
            ),
          )
        : null;

    final bubble = MessageBubble(
      message: message,
      showAvatar: vm.showAvatar,
      currentUserId: me,
      quotedSenderResolvedName: quotedSenderResolved,
      onCopy: copyable ? () => copyMessageToClipboard(context, message) : null,
      onReply: canReply && onStartReply != null
          ? () => onStartReply!(messageKey)
          : null,
      onForward: () {
        final id = message.serverId.trim().isNotEmpty
            ? message.serverId.trim()
            : message.clientMsgId.trim();
        if (id.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('发送中，暂不可转发')));
          return;
        }
        unawaited(() async {
          try {
            await im.chatForwardMessages(
              conversationId,
              messageIds: [id],
              merge: false,
              title: '转发消息',
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('已转发到当前会话')));
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('转发失败：$e')));
          }
        }());
      },
      onMultiSelect: onStartMultiSelect != null
          ? () => onStartMultiSelect!(messageKey)
          : null,
      onMark: message.serverId.isNotEmpty
          ? () {
              unawaited(() async {
                try {
                  await im.chatMarkMessageImportant(message.serverId);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已标记为重要')));
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('标记失败：$e')));
                }
              }());
            }
          : null,
      onPinToggle: message.serverId.isNotEmpty
          ? () {
              if (pinned) {
                im.chatUnpinMessage(message.serverId);
              } else {
                im.chatPinMessage(message.serverId);
              }
            }
          : null,
      onPinForSelf: message.serverId.isNotEmpty && !pinned
          ? () => im.chatPinMessageForSelf(message.serverId)
          : null,
      pinToggleLabel: pinned ? '取消置顶' : '置顶消息',
      onResend:
          isSelf &&
              message.isFailed &&
              message.content is TextContent &&
              message.clientMsgId.trim().isNotEmpty
          ? () => im.chatResendFailedText(conversationId, message.clientMsgId)
          : null,
      // 己方消息：第二排固定显示「撤回」；不可撤回时点按提示（与稿式三格一致）。
      onRecall: isSelf
          ? () {
              if (message.isRecalled) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('消息已撤回')));
                return;
              }
              if (message.serverId.trim().isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('发送中，请稍后再试撤回')));
                return;
              }
              if (!message.canRecall) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已超过可撤回时间')));
                return;
              }
              im.chatRecall(conversationId, message.serverId);
            }
          : null,
      onDeleteForEveryone: message.serverId.isNotEmpty
          ? () async =>
                im.chatDeleteByServerId(conversationId, message.serverId)
          : null,
      onDeleteForSelf: message.serverId.isNotEmpty
          ? () async => im.chatDeleteForSelf(conversationId, message.serverId)
          : null,
      showDeleteForEveryoneOption: isSelf && message.serverId.isNotEmpty,
      onEdit:
          isSelf &&
              message.canEdit &&
              (message.content is TextContent ||
                  message.content is RichDocContent)
          ? () => onEditOwnText(message)
          : null,
      onReaction: message.serverId.isNotEmpty && !message.isRecalled
          ? (emoji) => _runReaction(
              context,
              () => im.chatAddReaction(conversationId, message.serverId, emoji),
            )
          : null,
      onRemoveReaction: message.serverId.isNotEmpty && !message.isRecalled
          ? (emoji) => _runReaction(
              context,
              () => im.chatRemoveReaction(
                conversationId,
                message.serverId,
                emoji,
              ),
            )
          : null,
    );

    final column = Column(
      children: [
        if (vm.showTime) _ChatTimeDivider(time: message.timestamp),
        bubble,
      ],
    );

    if (!multiSelectMode) {
      return column;
    }

    return InkWell(
      onTap: onToggleMultiSelect,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, right: 4),
            child: Checkbox(
              value: multiSelectSelected,
              onChanged: (_) => onToggleMultiSelect?.call(),
            ),
          ),
          Expanded(child: column),
        ],
      ),
    );
  }
}

class _ChatTimeDivider extends StatelessWidget {
  const _ChatTimeDivider({required this.time});

  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: light
                ? const Color(0xFFEDEEF0)
                : FlareThemeTokens.bgTertiary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _formatFeishuStyleDividerTime(time),
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              color: FlareThemeTokens.textSecondary.withValues(
                alpha: light ? 0.88 : 0.9,
              ),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// 飞书式：当日仅 `HH:mm`；昨天带「昨天」；同年 `M月d日`；跨年带年份。
  String _formatFeishuStyleDividerTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final yesterday = today.subtract(const Duration(days: 1));
    String two(int n) => n.toString().padLeft(2, '0');
    final hm = '${two(time.hour)}:${two(time.minute)}';
    if (day == today) return hm;
    if (day == yesterday) return '昨天 $hm';
    if (time.year == now.year) return '${time.month}月${time.day}日 $hm';
    return '${time.year}年${time.month}月${time.day}日 $hm';
  }
}
