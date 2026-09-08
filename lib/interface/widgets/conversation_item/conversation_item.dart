import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/application/providers/conversation_state_provider.dart';
import 'package:flare_im/application/providers/im_outbound_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/domain/entities/conversation.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/infrastructure/mappers/storage_preview_format.dart';
import 'package:flare_im/infrastructure/media/composer_static_asset_image.dart';
import 'package:flare_im/infrastructure/media/emoji_pack_i18n.dart';
import 'package:flare_im/infrastructure/media/network_image_policy.dart';
import 'package:flare_im/infrastructure/media/pack_asset_resolver.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/message/plain_text_emoji_rich.dart';
import 'package:flare_im/shared/i18n/flare_messages.dart';
import 'package:flare_im/shared/layout/workbench_layout.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flare_im_ui/flare_im_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

/// 会话列表项（设计稿：圆形头像 + 首字母淡色底、标题/时间、摘要 + 紫未读角标）
class ConversationItem extends ConsumerWidget {
  static const double _avatarSize = 54;

  final Conversation conversation;

  const ConversationItem({super.key, required this.conversation});

  String _lineTitle(Conversation c, [FlareMessages? m]) {
    final t = c.displayTitle.trim();
    if (t.isNotEmpty) return t;
    final id = c.conversationId.trim();
    if (id.isEmpty) return m?.t('conversation.untitled') ?? '会话';
    return id.length > 18 ? '${id.substring(0, 14)}…' : id;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(flareMessagesProvider);
    final titleText = _lineTitle(conversation, messages);
    final selected = ref.watch(
      selectedConversationProvider.select(
        (value) => value?.conversationId == conversation.conversationId,
      ),
    );
    void openConversation() {
      unawaited(_openConversation(context, ref));
    }

    // 通用外壳（头像 / 标题 / 时间 / 未读 / 静音图标 / 置顶点）交给 kit 的
    // FlareConversationRow（四端一致）；表情/贴纸内联富预览、@我 / 草稿 / 群昵称
    // 前缀由 app 通过 previewSpansBuilder 注入，kit 不感知资源系统。
    final data = ConversationRowData(
      id: conversation.conversationId,
      title: titleText,
      avatarUrl: isHttpOrHttpsUrl(conversation.avatarUrl)
          ? conversation.avatarUrl
          : null,
      timestampLabel: _formatTime(conversation.updatedAt, messages),
      unreadCount: conversation.unreadCount,
      pinned: conversation.isPinned,
      muted: conversation.isMuted,
    );

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: _semanticsLabel(messages, titleText, selected: selected),
      hint: messages.t('conversation.openA11y'),
      onTap: openConversation,
      child: Slidable(
        key: ValueKey('conversation-${conversation.conversationId}'),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.46,
          children: [
            SlidableAction(
              onPressed: (_) => ref
                  .read(imOutboundProvider)
                  .conversationPin(
                    conversation.conversationId,
                    !conversation.isPinned,
                  ),
              backgroundColor: FlareImDesign.brandPurple,
              foregroundColor: Colors.white,
              icon: conversation.isPinned
                  ? Icons.push_pin
                  : Icons.push_pin_outlined,
              label: conversation.isPinned
                  ? messages.t('conversation.unpin')
                  : messages.t('conversation.pin'),
            ),
            SlidableAction(
              onPressed: (_) => ref
                  .read(imOutboundProvider)
                  .conversationDelete(conversation.conversationId),
              backgroundColor: FlareImDesign.destructive,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline_rounded,
              label: messages.t('conversation.delete'),
            ),
          ],
        ),
        child: FlareConversationRow(
          item: data,
          avatarSize: _avatarSize,
          active: selected,
          onSelect: openConversation,
          onAction: () => _showConversationMenu(context, ref),
          previewSpansBuilder: (rowContext, base) =>
              _previewSpans(rowContext, base, messages),
        ),
      ),
    );
  }

  /// 组装最后一条消息预览的富文本 span：草稿 / @我 前缀 + 群昵称前缀 +
  /// 表情/贴纸内联缩略图，供 kit [FlareConversationRow.previewSpansBuilder] 渲染。
  List<InlineSpan> _previewSpans(
    BuildContext context,
    TextStyle base,
    FlareMessages messages,
  ) {
    final draft = conversation.draft;
    if (draft != null && draft.isNotEmpty) {
      final draftStyle = base.copyWith(
        color: FlareThemeTokens.conversationListDraftAccent,
        fontWeight: FontWeight.w500,
      );
      return [
        TextSpan(text: messages.conversation.draftPrefix, style: draftStyle),
        ...plainTextEmojiInlineSpans(
          context,
          text: draft,
          style: draftStyle,
          secondaryForeground: FlareThemeTokens.textSecondary,
          inlineEmojiEm: 1.72,
          localeTag: messages.locale.code,
        ),
      ];
    }

    final prefix = <InlineSpan>[];
    if (conversation.isMentioned) {
      prefix.add(TextSpan(
        text: messages.t('conversation.mentionPrefix'),
        style: base.copyWith(
          color: FlareThemeTokens.conversationListMentionAccent,
          fontWeight: FontWeight.w600,
        ),
      ));
    }

    final media = _mediaPreviewSpans(context, base, messages);
    if (media != null) return [...prefix, ...media];
    return [...prefix, ..._previewSpanChildren(context, base, messages)];
  }

  String _semanticsLabel(
    FlareMessages messages,
    String titleText, {
    required bool selected,
  }) {
    final parts = <String>[messages.t('conversation.a11yConv').replaceAll('{title}', titleText)];
    if (selected) parts.add(messages.t('conversation.selected'));
    if (conversation.isPinned) parts.add(messages.t('conversation.pinnedA11y'));
    if (conversation.hasUnread) {
      final count = conversation.unreadCount > 99
          ? '99+'
          : conversation.unreadCount.toString();
      parts.add(messages.t('conversation.unreadCount').replaceAll('{count}', count));
    }
    final preview = _semanticsPreview(messages);
    if (preview.isNotEmpty) parts.add(preview);
    return parts.join('，');
  }

  String _semanticsPreview(FlareMessages messages) {
    final draft = conversation.draft?.trim();
    if (draft != null && draft.isNotEmpty) {
      return '${messages.conversation.draftPrefix}$draft';
    }
    final preview = formatStoragePreview(
      conversation.lastMessagePreview ?? '',
      locale: messages.locale.code,
    ).trim();
    if (preview.isNotEmpty) return preview;
    return messages.conversation.noMessagePreview;
  }

  List<InlineSpan> _previewSpanChildren(
    BuildContext context,
    TextStyle baseStyle,
    FlareMessages messages,
  ) {
    final c = conversation;
    final d = c.draft;
    if (d != null && d.isNotEmpty) {
      return [
        TextSpan(text: messages.conversation.draftPrefix, style: baseStyle),
        ...plainTextEmojiInlineSpans(
          context,
          text: d,
          style: baseStyle,
          secondaryForeground: FlareThemeTokens.textSecondary,
          inlineEmojiEm: 1.72,
          localeTag: messages.locale.code,
        ),
      ];
    }
    final raw = c.lastMessagePreview ?? '';
    final t = formatStoragePreview(raw, locale: messages.locale.code).trim();
    if (t.isNotEmpty && t != ' ') {
      if (c.conversationType == ConversationType.group &&
          c.lastMessage != null) {
        final nick = c.lastMessage!.senderDisplayName.trim().isNotEmpty
            ? c.lastMessage!.senderDisplayName.trim()
            : c.lastMessage!.senderName.trim();
        if (nick.isNotEmpty) {
          return [
            TextSpan(text: '$nick: ', style: baseStyle),
            ...plainTextEmojiInlineSpans(
              context,
              text: t,
              style: baseStyle,
              secondaryForeground: FlareThemeTokens.textSecondary,
              inlineEmojiEm: 1.72,
              localeTag: messages.locale.code,
            ),
          ];
        }
      }
      return plainTextEmojiInlineSpans(
        context,
        text: t,
        style: baseStyle,
        secondaryForeground: FlareThemeTokens.textSecondary,
        inlineEmojiEm: 1.72,
        localeTag: messages.locale.code,
      );
    }
    return [
      TextSpan(text: messages.conversation.noMessagePreview, style: baseStyle),
    ];
  }

  /// 纯表情 / 贴纸消息：内联缩略图 + 文案标签（作为 [WidgetSpan] 融入单行富预览）。
  /// 非该类消息返回 `null`，回退到文本 span。
  List<InlineSpan>? _mediaPreviewSpans(
    BuildContext context,
    TextStyle base,
    FlareMessages messages,
  ) {
    final content = conversation.lastMessage?.content;
    final rawPreview = conversation.lastMessagePreview ?? '';
    final stickerContent = content is StickerContent ? content : null;
    final emojiKey = content is EmojiContent
        ? content.emoji.trim()
        : storagePreviewEmojiKey(rawPreview);
    final isSticker =
        stickerContent != null || storagePreviewIsSticker(rawPreview);

    if (!isSticker && (emojiKey == null || emojiKey.isEmpty)) return null;

    final prefix = _groupPreviewPrefix();
    final label = isSticker
        ? messages.conversation.previewSticker
        : EmojiPackI18n.packLabel(emojiKey!, locale: messages.locale.code);
    final thumb = isSticker
        ? _stickerPreviewThumb(stickerContent, messages)
        : _emojiPreviewThumb(emojiKey!, messages);

    return [
      if (prefix.isNotEmpty) TextSpan(text: prefix, style: base),
      WidgetSpan(alignment: PlaceholderAlignment.middle, child: thumb),
      const WidgetSpan(child: SizedBox(width: 5)),
      TextSpan(text: label, style: base),
    ];
  }

  String _groupPreviewPrefix() {
    if (conversation.conversationType != ConversationType.group ||
        conversation.lastMessage == null) {
      return '';
    }
    final nick = conversation.lastMessage!.senderDisplayName.trim().isNotEmpty
        ? conversation.lastMessage!.senderDisplayName.trim()
        : conversation.lastMessage!.senderName.trim();
    return nick.isEmpty ? '' : '$nick: ';
  }

  Widget _emojiPreviewThumb(String key, FlareMessages messages) {
    return ComposerStaticAssetImage(
      assetPath: PackAssetResolver.emojiPackAssetPath(key),
      width: 20,
      height: 20,
      fit: BoxFit.contain,
      decodeSize: 64,
      error: _previewFallbackIcon(Icons.emoji_emotions_outlined),
    );
  }

  Widget _stickerPreviewThumb(StickerContent? content, FlareMessages messages) {
    final assetPath = content == null
        ? null
        : PackAssetResolver.stickerAssetPath(
            stickerId: content.stickerId,
            packageId: content.packageId,
          );
    if (assetPath != null) {
      return ComposerStaticAssetImage(
        assetPath: assetPath,
        width: 22,
        height: 22,
        fit: BoxFit.contain,
        decodeSize: 72,
        error: _previewFallbackIcon(Icons.sticky_note_2_outlined),
      );
    }
    final url = content?.url?.trim() ?? '';
    if (isHttpOrHttpsUrl(url)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 22,
          height: 22,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) =>
              _previewFallbackIcon(Icons.sticky_note_2_outlined),
        ),
      );
    }
    return _previewFallbackIcon(Icons.sticky_note_2_outlined);
  }

  Widget _previewFallbackIcon(IconData icon) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: FlareImDesign.brandPurple.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: FlareImDesign.brandPurple.withValues(alpha: 0.22),
        ),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 13, color: FlareImDesign.brandPurple),
    );
  }

  void _showConversationMenu(BuildContext context, WidgetRef ref) {
    final messages = ref.read(flareMessagesProvider);
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                conversation.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin,
              ),
              title: Text(conversation.isPinned ? messages.t('conversation.unpin') : messages.t('conversation.pin')),
              onTap: () {
                ref
                    .read(imOutboundProvider)
                    .conversationPin(
                      conversation.conversationId,
                      !conversation.isPinned,
                    );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: Text(messages.t('conversation.syncThis')),
              onTap: () async {
                Navigator.pop(context);
                await ref
                    .read(imOutboundProvider)
                    .conversationSync(conversation.conversationId);
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(messages.t('conversation.syncedThis'))));
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: FlareImDesign.destructive,
              ),
              title: Text(
                messages.t('conversation.deleteConv'),
                style: const TextStyle(color: FlareImDesign.destructive),
              ),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(messages.t('conversation.deleteConv')),
                    content: Text(messages.t('conversation.deleteConfirm')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(messages.t('conversation.cancel')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(messages.t('conversation.confirm')),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  ref
                      .read(imOutboundProvider)
                      .conversationDelete(conversation.conversationId);
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time, FlareMessages m) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return m.t('conversation.yesterday');
    } else if (diff.inDays < 7) {
      final weekdays = m.t('conversation.weekdays').split(',');
      return weekdays[time.weekday - 1];
    } else {
      return '${time.month}/${time.day}';
    }
  }

  Future<void> _openConversation(BuildContext context, WidgetRef ref) async {
    final im = ref.read(imOutboundProvider);
    var target = conversation;

    if (conversation.conversationType == ConversationType.group) {
      final memberIds = _memberIdsForCanonicalGroupOpen(ref, conversation);
      if (memberIds.length >= 2) {
        try {
          final resolved = await im.conversationOpenGroupChat(
            memberIds,
            displayName: conversation.displayTitle,
          );
          final resolvedId = resolved?.conversationId.trim() ?? '';
          if (resolved != null && resolvedId.isNotEmpty) {
            target = resolved;
          }
        } catch (error, stackTrace) {
          debugPrint(
            'canonical group resolve failed '
            'conversation=${conversation.conversationId}: $error\n$stackTrace',
          );
        }
      }
    }

    if (!context.mounted) return;
    im.conversationSetSelected(target);
    navigateToChat(context, target.conversationId);
  }

  List<String> _memberIdsForCanonicalGroupOpen(
    WidgetRef ref,
    Conversation conversation,
  ) {
    final ids = <String>{
      for (final id in conversation.memberUserIds)
        if (id.trim().isNotEmpty) id.trim(),
      ..._memberIdsFromDisplayText(conversation.displayName),
      ..._memberIdsFromDisplayText(conversation.conversationId),
    };
    final self = ref.read(currentUserProvider)?.userId.trim() ?? '';
    if (self.isNotEmpty) ids.add(self);
    return ids.toList(growable: false)..sort();
  }

  Set<String> _memberIdsFromDisplayText(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return const {};

    var text = raw;
    final usersMatch = RegExp(
      r'users\s*[:：](.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (usersMatch != null) {
      text = usersMatch.group(1) ?? '';
    } else {
      final parenMatch = RegExp(r'[（(]([^()（）]+)[）)]').firstMatch(text);
      if (parenMatch != null) {
        text = parenMatch.group(1) ?? '';
      }
    }

    final parts = text
        .split(RegExp(r'[\s,，、;；|/]+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toSet();
    return parts.length >= 2 ? parts : const {};
  }
}

/// 按 [conversationId] 订阅 [conversationProvider] 单行切片，配合 [SliverList] 做局部刷新。
class ConversationListSliverItem extends ConsumerWidget {
  const ConversationListSliverItem({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(
      conversationProvider.select(
        (list) => conversationById(list, conversationId),
      ),
    );
    if (c == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ConversationItem(conversation: c),
    );
  }
}
