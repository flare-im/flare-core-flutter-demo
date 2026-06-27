import 'package:event_bus/event_bus.dart';
import 'package:flare_im/domain/entities/conversation.dart';
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/entities/user.dart';
import 'package:flutter/foundation.dart';

/// 全局 IM 事件总线：SDK 只 [fire]，[ImEventToStoreBridge] 写 Riverpod。
final EventBus imEventBus = EventBus();

@immutable
final class ConversationUpdateEvent {
  const ConversationUpdateEvent({this.conversationId});
  final String? conversationId;
}

@immutable
final class ConversationListViewSnapshotEvent {
  const ConversationListViewSnapshotEvent(this.conversations);
  final List<Conversation> conversations;
}

@immutable
final class CoreViewDeltaOp<T> {
  const CoreViewDeltaOp({
    required this.op,
    required this.key,
    required this.index,
    this.fromIndex,
    this.item,
  });

  final String op;
  final String key;
  final int index;
  final int? fromIndex;
  final T? item;
}

@immutable
final class ConversationListViewDeltaEvent {
  const ConversationListViewDeltaEvent({required this.ops, this.totalUnread});

  final List<CoreViewDeltaOp<Conversation>> ops;
  final int? totalUnread;
}

@immutable
final class TimelineViewSnapshotEvent {
  const TimelineViewSnapshotEvent({
    required this.conversationId,
    required this.messages,
    required this.hasMore,
  });

  final String conversationId;
  final List<Message> messages;
  final bool hasMore;
}

@immutable
final class TimelineViewDeltaEvent {
  const TimelineViewDeltaEvent({
    required this.conversationId,
    required this.ops,
    this.hasMore,
  });

  final String conversationId;
  final List<CoreViewDeltaOp<Message>> ops;
  final bool? hasMore;
}

@immutable
final class IncomingMessagesEvent {
  const IncomingMessagesEvent(this.messages);

  final List<Message> messages;
}

/// 对端已读回执（`im://message_read_receipt` / SDK `read_receipt`），与 Tauri `applyReadReceipt` 对齐。
@immutable
final class MessageReadReceiptEvent {
  const MessageReadReceiptEvent({
    required this.conversationId,
    required this.readSeq,
    this.readerUserId,
  });

  final String conversationId;
  final int readSeq;

  /// 产生已读的用户；与己方不同时，己方发送的消息升级为 [MessageStatus.read]（双勾）。
  final String? readerUserId;
}

@immutable
final class UnreadUpdateEvent {
  const UnreadUpdateEvent({
    required this.conversationId,
    required this.unreadCount,
  });
  final String conversationId;
  final int unreadCount;
}

@immutable
final class TypingEvent {
  const TypingEvent({
    required this.conversationId,
    required this.userId,
    required this.isTyping,
  });
  final String conversationId;
  final String userId;
  final bool isTyping;
}

@immutable
final class RecallMessageEvent {
  const RecallMessageEvent({
    required this.conversationId,
    required this.messageId,
  });
  final String conversationId;
  final String messageId;
}

/// 消息表情反应增删（SDK `reaction_changed` / proto `ReactionAction`：1=ADD，2=REMOVE）。
@immutable
final class MessageReactionChangedEvent {
  const MessageReactionChangedEvent({
    required this.conversationId,
    required this.serverMsgId,
    required this.userId,
    required this.emoji,
    required this.action,
  });

  final String conversationId;
  final String serverMsgId;
  final String userId;
  final String emoji;
  final int action;
}

@immutable
final class MessageSendAckEvent {
  const MessageSendAckEvent(this.ack);
  final Map<String, dynamic> ack;
}

@immutable
final class SdkMessageSendFailedEvent {
  const SdkMessageSendFailedEvent(this.payload);
  final Map<String, dynamic> payload;
}

@immutable
final class SdkLifecycleUpdatedEvent {
  const SdkLifecycleUpdatedEvent(this.payload);
  final Map<String, dynamic> payload;
}

@immutable
final class SdkConnectionUpdatedEvent {
  const SdkConnectionUpdatedEvent(this.payload);
  final Map<String, dynamic> payload;
}

@immutable
final class SdkSyncUpdatedEvent {
  const SdkSyncUpdatedEvent(this.payload);
  final Map<String, dynamic> payload;
}

@immutable
final class SdkProgressUpdatedEvent {
  const SdkProgressUpdatedEvent(this.payload);
  final Map<String, dynamic> payload;
}

@immutable
final class SdkCapabilityUpdatedEvent {
  const SdkCapabilityUpdatedEvent(this.payload);
  final Map<String, dynamic> payload;
}

@immutable
final class UserInfoUpdateEvent {
  const UserInfoUpdateEvent(this.user);
  final User user;
}

@immutable
final class PresenceUpdateEvent {
  const PresenceUpdateEvent({required this.userId, required this.isOnline});
  final String userId;
  final bool isOnline;
}

@immutable
final class ConnectionChangedEvent {
  const ConnectionChangedEvent();
}

@immutable
final class CallSignalEvent {
  const CallSignalEvent(this.payload);
  final Map<String, dynamic> payload;
}
