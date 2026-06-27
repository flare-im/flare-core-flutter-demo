import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/interface/widgets/message/views/announcement_view.dart';
import 'package:flare_im/interface/widgets/message/views/audio_view.dart';
import 'package:flare_im/interface/widgets/message/views/card_view.dart';
import 'package:flare_im/interface/widgets/message/views/emoji_view.dart';
import 'package:flare_im/interface/widgets/message/views/file_view.dart';
import 'package:flare_im/interface/widgets/message/views/forward_view.dart';
import 'package:flare_im/interface/widgets/message/views/image_group_view.dart';
import 'package:flare_im/interface/widgets/message/views/image_view.dart';
import 'package:flare_im/interface/widgets/message/views/link_card_view.dart';
import 'package:flare_im/interface/widgets/message/views/location_view.dart';
import 'package:flare_im/interface/widgets/message/views/mini_program_view.dart';
import 'package:flare_im/interface/widgets/message/views/notification_view.dart';
import 'package:flare_im/interface/widgets/message/views/placeholder_view.dart';
import 'package:flare_im/interface/widgets/message/views/quote_view.dart';
import 'package:flare_im/interface/widgets/message/views/schedule_view.dart';
import 'package:flare_im/interface/widgets/message/views/sticker_view.dart';
import 'package:flare_im/interface/widgets/message/views/task_view.dart';
import 'package:flare_im/interface/widgets/message/views/text_view.dart';
import 'package:flare_im/interface/widgets/message/views/video_view.dart';
import 'package:flare_im/interface/widgets/message/views/vote_view.dart';
import 'package:flutter/material.dart';

// 按 [MessageContent] 分发各类型子视图。
class ContentView extends StatelessWidget {
  final MessageContent content;
  final bool isSelf;

  /// 己方文本消息气泡内送达/已读（时间由列表飞书式分隔条展示）
  final MessageStatus? messageStatus;

  /// 图片 / 视频 / 语音 / 文件气泡旁或底栏简短时间 `HH:mm`（由列表传入）
  final String? mediaFooterTimeText;

  /// 引用消息：由会话列表根据 `quotedMessageId` / `quotedSenderId` 解析出的被引用方展示名（优先于无展示名的纯 id）。
  final String? quotedSenderResolvedName;

  /// 文本气泡底部（与正文同一圆角容器内），如反应条（飞书式）。
  final Widget? bubbleFooter;

  const ContentView({
    super.key,
    required this.content,
    required this.isSelf,
    this.messageStatus,
    this.mediaFooterTimeText,
    this.quotedSenderResolvedName,
    this.bubbleFooter,
  });

  @override
  Widget build(BuildContext context) {
    switch (content) {
      case TextContent(:final text):
        return TextView(
          text: text,
          isSelf: isSelf,
          messageStatus: isSelf ? messageStatus : null,
          bubbleFooter: bubbleFooter,
        );
      case RichDocContent(:final plainText):
        return TextView(
          text: plainText.trim().isNotEmpty ? plainText.trim() : '[富文本]',
          isSelf: isSelf,
          messageStatus: isSelf ? messageStatus : null,
          bubbleFooter: bubbleFooter,
        );
      case ImageContent(
        :final url,
        :final width,
        :final height,
        :final size,
        :final description,
      ):
        return ImageView(
          url: url,
          width: width,
          height: height,
          sizeBytes: size,
          caption: description,
          isSelf: isSelf,
          messageStatus: isSelf ? messageStatus : null,
          footerTimeText: mediaFooterTimeText,
        );
      case ImageGroupContent(:final imageUrls, :final description):
        return ImageGroupView(
          isSelf: isSelf,
          imageUrls: imageUrls,
          description: description,
          messageStatus: isSelf ? messageStatus : null,
          footerTimeText: mediaFooterTimeText,
        );
      case VideoContent(
        :final url,
        :final thumbnailUrl,
        :final width,
        :final height,
        :final duration,
        :final description,
      ):
        return VideoView(
          url: url,
          thumbnailUrl: thumbnailUrl,
          width: width,
          height: height,
          durationSec: duration,
          caption: description,
          isSelf: isSelf,
          messageStatus: isSelf ? messageStatus : null,
          footerTimeText: mediaFooterTimeText,
        );
      case AudioContent(:final url, :final localPath, :final duration):
        return AudioView(
          url: url,
          localPath: localPath,
          durationSec: duration,
          isSelf: isSelf,
          messageStatus: isSelf ? messageStatus : null,
          footerTimeText: mediaFooterTimeText,
        );
      case FileContent(
        :final url,
        :final localPath,
        :final filename,
        :final size,
      ):
        return FileView(
          url: url,
          localPath: localPath,
          filename: filename,
          size: size,
          isSelf: isSelf,
          messageStatus: isSelf ? messageStatus : null,
          footerTimeText: mediaFooterTimeText,
        );
      case LocationContent(
        :final latitude,
        :final longitude,
        :final address,
        :final title,
        :final zoom,
        :final snapshotUrl,
        :final snapshotLocalPath,
      ):
        return LocationView(
          latitude: latitude,
          longitude: longitude,
          address: address,
          title: title,
          zoom: zoom,
          snapshotUrl: snapshotUrl,
          snapshotLocalPath: snapshotLocalPath,
          isSelf: isSelf,
          messageStatus: isSelf ? messageStatus : null,
        );
      case EmojiContent(:final emoji):
        return EmojiView(emoji: emoji, isSelf: isSelf);
      case final StickerContent sticker:
        return StickerView(sticker: sticker, isSelf: isSelf);
      case final QuoteContent quote:
        final explicit = (quote.quotedSenderName ?? '').trim();
        final resolved = (quotedSenderResolvedName ?? '').trim();
        final quotedLabel = explicit.isNotEmpty
            ? explicit
            : (resolved.isNotEmpty ? resolved : null);
        return QuoteView(
          quotedTextPreview: quote.quotedTextPreview,
          quotedSenderName: quotedLabel,
          content: quote.content,
          isSelf: isSelf,
          messageStatus: isSelf ? messageStatus : null,
          footerTimeText: mediaFooterTimeText,
        );
      case ForwardContent(:final forwardTitle, :final items):
        return ForwardView(
          forwardTitle: forwardTitle,
          items: items,
          isSelf: isSelf,
          messageStatus: isSelf ? messageStatus : null,
          footerTimeText: mediaFooterTimeText,
          embedBuilder: (context, content, {required asOutgoingBubble}) =>
              ContentView(
                content: content,
                isSelf: asOutgoingBubble,
                messageStatus: null,
                mediaFooterTimeText: null,
                quotedSenderResolvedName: null,
              ),
        );
      case final CardContent card:
        return CardView(
          isSelf: isSelf,
          id: card.id,
          title: card.title,
          subtitle: card.subtitle,
          avatar: card.avatar,
          messageStatus: isSelf ? messageStatus : null,
          footerTimeText: mediaFooterTimeText,
        );
      case final LinkCardContent link:
        return LinkCardView(
          isSelf: isSelf,
          title: link.title,
          url: link.url,
          summary: link.summary,
          siteName: link.siteName,
          thumbnailUrl: link.thumbnailUrl,
          messageStatus: isSelf ? messageStatus : null,
        );
      case final MiniProgramContent mp:
        return MiniProgramView(
          isSelf: isSelf,
          appId: mp.appId,
          title: mp.title,
          thumbnailUrl: mp.thumbnailUrl,
          description: mp.description,
          messageStatus: isSelf ? messageStatus : null,
          footerTimeText: mediaFooterTimeText,
        );
      case final NotificationContent notification:
        return NotificationView(content: notification);
      case VoteContent(
        :final voteId,
        :final headline,
        :final options,
        :final metadata,
      ):
        return VoteView(
          isSelf: isSelf,
          voteId: voteId,
          headline: headline,
          options: options,
          metadata: metadata,
          messageStatus: isSelf ? messageStatus : null,
          footerTimeText: mediaFooterTimeText,
        );
      case TaskContent(
        :final taskId,
        :final title,
        :final detail,
        :final metadata,
        :final participantUserIds,
      ):
        return TaskView(
          taskId: taskId,
          title: title,
          detail: detail,
          metadata: metadata,
          participantUserIds: participantUserIds,
        );
      case ScheduleContent(
        :final scheduleId,
        :final title,
        :final timeRange,
        :final metadata,
        :final participantUserIds,
      ):
        return ScheduleView(
          scheduleId: scheduleId,
          title: title,
          timeRange: timeRange,
          metadata: metadata,
          participantUserIds: participantUserIds,
        );
      case AnnouncementContent(
        :final announcementId,
        :final headline,
        :final body,
        :final metadata,
      ):
        return AnnouncementView(
          announcementId: announcementId,
          headline: headline,
          body: body,
          metadata: metadata,
          footerTimeText: mediaFooterTimeText,
        );
      case PlaceholderMessageContent(:final fallbackText):
        return PlaceholderView(isSelf: isSelf, fallbackText: fallbackText);
    }
  }
}
