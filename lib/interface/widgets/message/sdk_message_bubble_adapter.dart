import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/application/providers/sdk_provider.dart';
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/interface/widgets/media_viewer/image_preview_modal.dart';
import 'package:flare_im/interface/widgets/media_viewer/video_player_modal.dart';
import 'package:flare_im/interface/widgets/message/message_long_press_menu.dart';
import 'package:flare_im_ui/flare_im_ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SDK-domain to design-kit adapter. Commands stay in the example; visual
/// structure, status, media, tokens, and accessibility stay in the kit.
class SdkMessageBubbleAdapter extends ConsumerWidget {
  const SdkMessageBubbleAdapter({
    super.key,
    required this.message,
    this.showAvatar = true,
    this.currentUserId = '',
    this.onRecall,
    this.onDeleteForEveryone,
    this.onDeleteForSelf,
    this.showDeleteForEveryoneOption = false,
    this.onEdit,
    this.onReaction,
    this.onRemoveReaction,
    this.onCopy,
    this.onReply,
    this.onForward,
    this.onMultiSelect,
    this.onMark,
    this.onPinToggle,
    this.onPinForSelf,
    required this.pinToggleLabel,
    this.onResend,
    this.quotedSenderResolvedName,
  });

  final Message message;
  final bool showAvatar;
  final String currentUserId;
  final VoidCallback? onRecall;
  final Future<void> Function()? onDeleteForEveryone;
  final Future<void> Function()? onDeleteForSelf;
  final bool showDeleteForEveryoneOption;
  final VoidCallback? onEdit;
  final void Function(String emoji)? onReaction;
  final void Function(String emoji)? onRemoveReaction;
  final VoidCallback? onCopy;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onMultiSelect;
  final VoidCallback? onMark;
  final VoidCallback? onPinToggle;
  final VoidCallback? onPinForSelf;
  final String pinToggleLabel;
  final VoidCallback? onResend;
  final String? quotedSenderResolvedName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(flareMessagesProvider).chat;
    final presentation = _toPresentation(message);
    final self = message.senderId == currentUserId;
    return Column(
      crossAxisAlignment: self
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        ui.FlareMessageBubble(
          message: presentation,
          currentUserId: currentUserId,
          conversationKind: showAvatar
              ? ui.FlareConversationKind.group
              : ui.FlareConversationKind.single,
          rowPresentation: ui.FlareMessageRowPresentation(
            showAvatar: showAvatar && !self,
            reserveAvatarSpace: showAvatar && !self,
            showSenderName: showAvatar && !self,
          ),
          onLongPress: message.isRecalled
              ? null
              : (_) => showMessageLongPressMenu(
                  context,
                  onPickReaction: onReaction,
                  onReply: onReply,
                  onForward: onForward,
                  onRecall: onRecall,
                  onMultiSelect: onMultiSelect,
                  onMark: onMark,
                  onPinToggle: onPinToggle,
                  onPinForSelf: onPinForSelf,
                  pinLabel: pinToggleLabel,
                  onCopy: onCopy,
                  onEdit: onEdit,
                  onDeleteForSelf: onDeleteForSelf,
                  onDeleteForEveryone: onDeleteForEveryone,
                  showDeleteForEveryoneOption: showDeleteForEveryoneOption,
                  i18n: i18n,
                ),
          onMediaAction: (_, content) async {
            if (content is ui.FlareImageContent && content.url.isNotEmpty) {
              ImagePreviewModal.show(context, imageUrl: content.url);
            } else if (content is ui.FlareVideoContent) {
              await VideoPlayerModal.show(
                context,
                videoUrl: content.url,
                posterUrl: content.poster,
              );
            } else if (content is ui.FlareAudioContent) {
              await VideoPlayerModal.show(
                context,
                videoUrl: content.url,
                audioOnly: true,
              );
            } else if (content is ui.FlareFileContent) {
              try {
                final source = Uri.parse(content.url);
                final path = await ref
                    .read(sdkWrapperProvider)
                    .downloadFileToDownloads(
                      downloadKey: presentation.id,
                      displayFileName: content.name,
                      sourcePath: source.scheme == 'file'
                          ? source.toFilePath()
                          : source.scheme.isEmpty
                          ? content.url
                          : null,
                      sourceUrl:
                          source.scheme == 'http' || source.scheme == 'https'
                          ? content.url
                          : null,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: ui.FlareToast(
                        message: '已保存：$path',
                        variant: ui.FlareToastVariant.success,
                      ),
                    ),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: ui.FlareToast(
                        message: '文件下载失败，请重试',
                        variant: ui.FlareToastVariant.error,
                      ),
                    ),
                  );
                }
              }
            }
          },
          onResend: onResend == null ? null : (_) => onResend!(),
        ),
        if (!message.isRecalled && (message.reactions?.isNotEmpty ?? false))
          ui.FlareReactionSummary(
            reactions: message.reactions!
                .map(
                  (reaction) => ui.FlareReactionGroup(
                    emoji: reaction.emoji,
                    count: reaction.count,
                    reactedBySelf: reaction.userIds.contains(currentUserId),
                  ),
                )
                .toList(),
            hideAdd: true,
            onToggle: (emoji) {
              final selected = message.reactions!.any(
                (reaction) =>
                    reaction.emoji == emoji &&
                    reaction.userIds.contains(currentUserId),
              );
              if (selected) {
                onRemoveReaction?.call(emoji);
              } else {
                onReaction?.call(emoji);
              }
            },
          ),
      ],
    );
  }

  ui.FlareMessageData _toPresentation(Message value) {
    final senderName = value.senderDisplayName.trim().isNotEmpty
        ? value.senderDisplayName.trim()
        : value.senderName.trim().isNotEmpty
        ? value.senderName.trim()
        : value.senderId;
    return ui.FlareMessageData(
      id: value.timelineKey.isNotEmpty
          ? value.timelineKey
          : value.serverId.isNotEmpty
          ? value.serverId
          : value.clientMsgId,
      senderId: value.senderId,
      senderName: senderName,
      senderAvatarUrl: value.senderAvatar.trim().isEmpty
          ? value.extra['avatarUrl']
          : value.senderAvatar,
      content: value.isRecalled
          ? const ui.FlareNotificationContent('Message recalled')
          : _toContent(value.content),
      timeLabel:
          '${value.timestamp.hour.toString().padLeft(2, '0')}:${value.timestamp.minute.toString().padLeft(2, '0')}',
      status: switch (value.status) {
        MessageStatus.sending => ui.FlareMessageDeliveryStatus.sending,
        MessageStatus.sent => ui.FlareMessageDeliveryStatus.sent,
        MessageStatus.delivered => ui.FlareMessageDeliveryStatus.delivered,
        MessageStatus.read => ui.FlareMessageDeliveryStatus.read,
        MessageStatus.failed => ui.FlareMessageDeliveryStatus.failed,
      },
      edited: value.isEdited,
    );
  }

  ui.FlareMessageContent _toContent(MessageContent content) {
    return switch (content) {
      TextContent(:final text) => ui.FlareTextContent(text),
      ImageContent(
        :final url,
        :final localPath,
        :final width,
        :final height,
        :final description,
      ) =>
        ui.FlareImageContent(
          url: url.isNotEmpty ? url : localPath ?? '',
          width: width?.toDouble(),
          height: height?.toDouble(),
          alt: description,
        ),
      VideoContent(
        :final url,
        :final localPath,
        :final thumbnailUrl,
        :final duration,
      ) =>
        ui.FlareVideoContent(
          url: url.isNotEmpty ? url : localPath ?? '',
          poster: thumbnailUrl,
          durationSec: duration ?? 0,
        ),
      AudioContent(:final url, :final localPath, :final duration) =>
        ui.FlareAudioContent(
          url: url.isNotEmpty ? url : localPath ?? '',
          durationSec: duration ?? 0,
        ),
      FileContent(:final url, :final localPath, :final filename, :final size) =>
        ui.FlareFileContent(
          name: filename,
          url: url.isNotEmpty ? url : localPath ?? '',
          sizeBytes: size ?? 0,
        ),
      LocationContent(
        :final title,
        :final address,
        :final latitude,
        :final longitude,
      ) =>
        ui.FlareLocationContent(
          name: title ?? address ?? 'Location',
          address: address ?? '',
          latitude: latitude,
          longitude: longitude,
        ),
      StickerContent(
        :final url,
        :final packageId,
        :final stickerId,
        :final width,
        :final height,
      ) =>
        ui.FlareStickerContent(
          url: url ?? '',
          packageId: packageId,
          stickerId: stickerId,
          width: width?.toDouble(),
          height: height?.toDouble(),
        ),
      EmojiContent(:final emoji) => ui.FlareEmojiContent(emoji),
      CardContent(:final title, :final subtitle, :final avatar) =>
        ui.FlareCardContent(
          title: title ?? content.previewText,
          subtitle: subtitle,
          imageUrl: avatar,
        ),
      LinkCardContent(
        :final url,
        :final title,
        :final summary,
        :final thumbnailUrl,
      ) =>
        ui.FlareLinkCardContent(
          url: url,
          title: title ?? url,
          description: summary,
          imageUrl: thumbnailUrl,
        ),
      NotificationContent() => ui.FlareNotificationContent(content.previewText),
      final VoteContent c => ui.FlarePollContent(
        id: c.voteId ?? '',
        title: c.headline ?? content.previewText,
        options: c.options,
      ),
      final TaskContent c => ui.FlareTaskContent(
        id: c.taskId ?? '',
        title: c.title ?? content.previewText,
        detail: c.detail ?? '',
        done: c.metadata['done'] == 'true',
      ),
      final ScheduleContent c => ui.FlareCalendarContent(
        id: c.scheduleId ?? '',
        title: c.title ?? content.previewText,
        timeRange: c.timeRange ?? '',
      ),
      final MiniProgramContent c => ui.FlareMiniAppContent(
        appId: c.appId,
        title: c.title ?? c.appId,
        pagePath: c.pagePath ?? '',
        thumbnailUrl: c.thumbnailUrl,
        description: c.description,
      ),
      final AnnouncementContent c => ui.FlareAnnouncementContent(
        id: c.announcementId ?? '',
        title: c.headline ?? content.previewText,
        body: c.body ?? '',
      ),
      _ => ui.FlareGenericContent(
        contentType: content.contentType,
        label: content.previewText,
      ),
    };
  }
}
