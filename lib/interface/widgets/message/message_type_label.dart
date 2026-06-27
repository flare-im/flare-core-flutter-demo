import 'package:flare_im/domain/value_objects/message_content.dart';

/// 与 `flare.common.v1.MessageType`（proto wire）及解码后 [MessageContent.contentType] 对齐的**简短中文类型名**，
/// 用于合并转发条目角标、会话摘要等；后续可换为 l10n。
///
/// [messageTypeWire] 来自 `ForwardItem.messageType` / 消息 `messageType`；为 null 或 0 时回退到 [content]。
String messageTypeShortLabel(int? messageTypeWire, MessageContent content) {
  if (messageTypeWire != null && messageTypeWire != 0) {
    switch (messageTypeWire) {
      case 1:
        return '文本';
      case 2:
        return '图片';
      case 3:
        return '视频';
      case 4:
        return '语音';
      case 5:
        return '文件';
      case 6:
        return '位置';
      case 7:
        return '名片';
      case 8:
        return '贴纸';
      case 9:
        return '表情';
      case 11:
        return '链接';
      case 12:
        return '转发';
      case 13:
        return '小程序';
      case 14:
        return '话题';
      case 15:
        return '回复';
      case 30:
        return '富文本';
      case 32:
        return '图组';
      case 60:
        return '系统';
      case 61:
        return '通知';
      case 80:
        return '投票';
      case 81:
        return '任务';
      case 82:
        return '日程';
      case 83:
        return '公告';
      case 100:
        return '自定义';
      default:
        return '类型 $messageTypeWire';
    }
  }
  return messageTypeShortLabelFromContentType(content.contentType);
}

/// 仅根据 `contentType` 解析简短标签；无 wire 或与 proto 不一致时使用。
String messageTypeShortLabelFromContentType(String contentType) {
  switch (contentType) {
    case 'text':
      return '文本';
    case 'image':
      return '图片';
    case 'video':
      return '视频';
    case 'audio':
      return '语音';
    case 'file':
      return '文件';
    case 'location':
      return '位置';
    case 'card':
      return '名片';
    case 'sticker':
      return '贴纸';
    case 'emoji':
      return '表情';
    case 'link_card':
      return '链接';
    case 'forward':
      return '转发';
    case 'mini_program':
      return '小程序';
    case 'quote':
      return '回复';
    case 'rich_text':
    case 'rich_doc':
      return '富文本';
    case 'vote':
      return '投票';
    case 'task':
      return '任务';
    case 'schedule':
      return '日程';
    case 'announcement':
      return '公告';
    case 'notification':
      return '通知';
    case 'image_group':
      return '图组';
    case 'placeholder':
      return '占位';
    case 'system':
      return '系统';
    case 'thread':
      return '话题';
    case 'custom':
      return '自定义';
    default:
      return '消息';
  }
}
