import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

/// 会话列表项（设计稿：圆形头像 + 首字母淡色底、标题/时间、摘要 + 紫未读角标）
class ConversationItem extends ConsumerWidget {
  static const double _avatarSize = 54;

  final Conversation conversation;
  final bool pinnedStyle;

  const ConversationItem({
    super.key,
    required this.conversation,
    required this.pinnedStyle,
  });

  String _lineTitle(Conversation c) {
    final t = c.displayTitle.trim();
    if (t.isNotEmpty) return t;
    final id = c.conversationId.trim();
    if (id.isEmpty) return '会话';
    return id.length > 18 ? '${id.substring(0, 14)}…' : id;
  }

  String _initialsForTitle(String title) {
    final t = title.trim();
    if (t.isEmpty) return '?';
    final parts = t.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final a = parts[0].characters.first;
      final b = parts[1].characters.first;
      return '$a$b';
    }
    final chars = t.characters;
    if (chars.length >= 2) return chars.take(2).string;
    return chars.first;
  }

  String _pastelKey(Conversation c) {
    final id = c.conversationId.trim();
    if (id.isNotEmpty) return id;
    return _lineTitle(c);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleText = _lineTitle(conversation);
    final messages = ref.watch(flareMessagesProvider);
    final hasDraft =
        conversation.draft != null && conversation.draft!.isNotEmpty;
    final (pastelBg, pastelFg) = FlareImDesign.avatarPastelForKey(
      _pastelKey(conversation),
    );

    return Slidable(
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
            label: conversation.isPinned ? '取消置顶' : '置顶',
          ),
          SlidableAction(
            onPressed: (_) => ref
                .read(imOutboundProvider)
                .conversationDelete(conversation.conversationId),
            backgroundColor: FlareImDesign.destructive,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: '删除',
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(imOutboundProvider).conversationSetSelected(conversation);
            navigateToChat(context, conversation.conversationId);
          },
          onLongPress: () => _showConversationMenu(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipOval(
                      child:
                          conversation.avatarUrl.isNotEmpty &&
                              isHttpOrHttpsUrl(conversation.avatarUrl)
                          ? CachedNetworkImage(
                              imageUrl: conversation.avatarUrl,
                              width: _avatarSize,
                              height: _avatarSize,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  _avatarFallback(
                                    titleText,
                                    pastelBg,
                                    pastelFg,
                                  ),
                            )
                          : _avatarFallback(titleText, pastelBg, pastelFg),
                    ),
                    if (pinnedStyle && conversation.isPinned)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: FlareImDesign.card,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: FlareImDesign.mobileDivider,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.push_pin,
                            size: 9,
                            color: FlareThemeTokens.conversationListPinLabel,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                if (conversation.isPinned && !pinnedStyle)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.push_pin_outlined,
                                      size: 14,
                                      color: FlareImDesign.mutedForeground,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    titleText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: conversation.hasUnread
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: FlareThemeTokens.textPrimary,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(conversation.updatedAt),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: FlareImDesign.mutedForeground,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _previewRichText(
                              context,
                              hasDraft: hasDraft,
                              messages: messages,
                            ),
                          ),
                          if (conversation.hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 22,
                                minHeight: 22,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                              ),
                              decoration: BoxDecoration(
                                color: FlareThemeTokens
                                    .conversationListUnreadBadgeBg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                conversation.unreadCount > 99
                                    ? '99+'
                                    : conversation.unreadCount.toString(),
                                style: const TextStyle(
                                  color: FlareThemeTokens
                                      .conversationListUnreadBadgeFg,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    return [TextSpan(text: messages.conversation.noMessagePreview, style: baseStyle)];
  }

  Widget _previewRichText(
    BuildContext context, {
    required bool hasDraft,
    required FlareMessages messages,
  }) {
    final baseStyle = TextStyle(
      fontSize: 14,
      fontWeight: hasDraft ? FontWeight.w500 : FontWeight.w400,
      color: hasDraft
          ? FlareThemeTokens.conversationListDraftAccent
          : FlareImDesign.mutedForeground,
      height: 1.35,
    );
    final mediaPreview = hasDraft
        ? null
        : _mediaPreview(context, baseStyle, messages);
    final children = mediaPreview == null
        ? _previewSpanChildren(context, baseStyle, messages)
        : const <InlineSpan>[];
    final body = mediaPreview ??
        Text.rich(
          TextSpan(style: baseStyle, children: children),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );

    if (conversation.isMuted) {
      return Row(
        children: [
          const Icon(
            Icons.notifications_off_outlined,
            size: 14,
            color: FlareImDesign.mutedForeground,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: body,
          ),
        ],
      );
    }

    if (conversation.isMentioned) {
      if (mediaPreview != null) {
        return Row(
          children: [
            Text(
              '@我 ',
              style: baseStyle.copyWith(
                color: FlareThemeTokens.conversationListMentionAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            Expanded(child: mediaPreview),
          ],
        );
      }
      return Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            TextSpan(
              text: '@我 ',
              style: baseStyle.copyWith(
                color: FlareThemeTokens.conversationListMentionAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            ...children,
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return body;
  }

  Widget? _mediaPreview(
    BuildContext context,
    TextStyle baseStyle,
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prefix.isNotEmpty)
          Flexible(
            flex: 0,
            child: Text(prefix, maxLines: 1, overflow: TextOverflow.ellipsis, style: baseStyle),
          ),
        if (isSticker)
          _stickerPreviewThumb(stickerContent, messages)
        else
          _emojiPreviewThumb(emojiKey!, messages),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: baseStyle,
          ),
        ),
      ],
    );
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

  Widget _stickerPreviewThumb(
    StickerContent? content,
    FlareMessages messages,
  ) {
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

  Widget _avatarFallback(String title, Color bg, Color fg) {
    return Container(
      width: _avatarSize,
      height: _avatarSize,
      color: bg,
      alignment: Alignment.center,
      child: Text(
        _initialsForTitle(title),
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: fg,
          height: 1,
        ),
      ),
    );
  }

  void _showConversationMenu(BuildContext context, WidgetRef ref) {
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
              title: Text(conversation.isPinned ? '取消置顶' : '置顶'),
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
              title: const Text('同步此会话'),
              onTap: () async {
                Navigator.pop(context);
                await ref
                    .read(imOutboundProvider)
                    .conversationSync(conversation.conversationId);
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已同步会话')));
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: FlareImDesign.destructive,
              ),
              title: const Text(
                '删除会话',
                style: TextStyle(color: FlareImDesign.destructive),
              ),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('删除会话'),
                    content: const Text('确定要删除此会话吗?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('确定'),
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[time.weekday - 1];
    } else {
      return '${time.month}/${time.day}';
    }
  }
}

/// 按 [conversationId] 订阅 [conversationProvider] 单行切片，配合 [SliverList] 做局部刷新。
class ConversationListSliverItem extends ConsumerWidget {
  const ConversationListSliverItem({
    super.key,
    required this.conversationId,
    required this.pinnedSection,
  });

  final String conversationId;
  final bool pinnedSection;

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
      child: ConversationItem(conversation: c, pinnedStyle: pinnedSection),
    );
  }
}
