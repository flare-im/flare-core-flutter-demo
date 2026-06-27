import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/application/bus/event_bus.dart';
import 'package:flare_im/application/providers/active_chat_stack_provider.dart';
import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/application/providers/conversation_state_provider.dart';
import 'package:flare_im/application/providers/im_sync_state_provider.dart';
import 'package:flare_im/application/providers/message_state_provider.dart';
import 'package:flare_im/application/providers/sdk_provider.dart';
import 'package:flare_im/application/providers/sdk_runtime_status_provider.dart';
import 'package:flare_im/infrastructure/mappers/sdk_model_mapper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 订阅 [imEventBus] 并写入 Riverpod（唯一「总线 → Store」入口）。
class ImEventToStoreBridge extends ConsumerStatefulWidget {
  const ImEventToStoreBridge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ImEventToStoreBridge> createState() =>
      _ImEventToStoreBridgeState();
}

class _ImEventToStoreBridgeState extends ConsumerState<ImEventToStoreBridge>
    with WidgetsBindingObserver {
  final List<StreamSubscription<dynamic>> _subs = [];
  String? _lastLoadedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subs.add(
      imEventBus.on<ConversationListViewSnapshotEvent>().listen(
        _onConversationListViewSnapshot,
      ),
    );
    _subs.add(
      imEventBus.on<ConversationListViewDeltaEvent>().listen(
        _onConversationListViewDelta,
      ),
    );
    _subs.add(
      imEventBus.on<TimelineViewSnapshotEvent>().listen(
        _onTimelineViewSnapshot,
      ),
    );
    _subs.add(
      imEventBus.on<TimelineViewDeltaEvent>().listen(_onTimelineViewDelta),
    );
    _subs.add(
      imEventBus.on<IncomingMessagesEvent>().listen(_onIncomingMessages),
    );
    _subs.add(
      imEventBus.on<ConversationUpdateEvent>().listen(_onConversationUpdate),
    );
    _subs.add(imEventBus.on<UnreadUpdateEvent>().listen(_onUnreadUpdate));
    _subs.add(
      imEventBus.on<MessageReadReceiptEvent>().listen(_onMessageReadReceipt),
    );
    _subs.add(imEventBus.on<MessageSendAckEvent>().listen(_onMessageSendAck));
    _subs.add(imEventBus.on<RecallMessageEvent>().listen(_onRecallMessage));
    _subs.add(
      imEventBus.on<MessageReactionChangedEvent>().listen(
        _onMessageReactionChanged,
      ),
    );
    _subs.add(imEventBus.on<TypingEvent>().listen(_onTyping));
    _subs.add(imEventBus.on<UserInfoUpdateEvent>().listen(_onUserInfo));
    _subs.add(imEventBus.on<PresenceUpdateEvent>().listen(_onPresence));
    _subs.add(imEventBus.on<ConnectionChangedEvent>().listen(_onConnection));
    _subs.add(
      imEventBus.on<SdkLifecycleUpdatedEvent>().listen(_onSdkLifecycleUpdated),
    );
    _subs.add(
      imEventBus.on<SdkConnectionUpdatedEvent>().listen(
        _onSdkConnectionUpdated,
      ),
    );
    _subs.add(imEventBus.on<SdkSyncUpdatedEvent>().listen(_onSdkSyncUpdated));
    _subs.add(
      imEventBus.on<SdkProgressUpdatedEvent>().listen(_onSdkProgressUpdated),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userId = ref.read(currentUserProvider)?.userId.trim() ?? '';
      if (userId.isNotEmpty) {
        _lastLoadedUserId = userId;
        unawaited(_setHeartbeatAppState(core.HeartbeatAppState.foreground));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_setHeartbeatAppState(core.HeartbeatAppState.foreground));
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_setHeartbeatAppState(core.HeartbeatAppState.background));
    }
  }

  void _onConversationListViewSnapshot(ConversationListViewSnapshotEvent e) {
    ref.read(conversationProvider.notifier).applyCoreSnapshot(e.conversations);
    debugPrint(
      'flare app view.conversation_list.snapshot count=${e.conversations.length} '
      'first=${e.conversations.isEmpty ? '' : e.conversations.first.conversationId} '
      'preview=${e.conversations.isEmpty ? '' : e.conversations.first.lastMessagePreview}',
    );
    ref
        .read(sdkRuntimeStatusProvider.notifier)
        .markReady(conversationCount: ref.read(conversationProvider).length);
  }

  void _onConversationListViewDelta(ConversationListViewDeltaEvent e) {
    ref.read(conversationProvider.notifier).applyCoreDelta(e.ops);
    debugPrint(
      'flare app view.conversation_list.delta ops=${e.ops.length} '
      'count=${ref.read(conversationProvider).length}',
    );
    ref
        .read(sdkRuntimeStatusProvider.notifier)
        .markReady(conversationCount: ref.read(conversationProvider).length);
  }

  void _onTimelineViewSnapshot(TimelineViewSnapshotEvent e) {
    final cid = e.conversationId.trim();
    if (cid.isEmpty) return;
    ref.read(messageProvider(cid).notifier).applyCoreSnapshot(e.messages);
    debugPrint(
      'flare app view.timeline.snapshot cid=$cid count=${e.messages.length} '
      'lastSeq=${e.messages.isEmpty ? 0 : e.messages.last.seq}',
    );
    _markForegroundConversationReadIfVisible(cid);
  }

  void _onTimelineViewDelta(TimelineViewDeltaEvent e) {
    final cid = e.conversationId.trim();
    if (cid.isEmpty) return;
    ref.read(messageProvider(cid).notifier).applyCoreDelta(e.ops);
    debugPrint('flare app view.timeline.delta cid=$cid ops=${e.ops.length}');
    _markForegroundConversationReadIfVisible(cid);
  }

  void _onIncomingMessages(IncomingMessagesEvent e) {
    final conversationIds = <String>{};
    for (final message in e.messages) {
      final cid = message.conversationId.trim();
      if (cid.isEmpty) continue;
      conversationIds.add(cid);
    }
    final fg = ref.read(foregroundChatConversationIdProvider)?.trim() ?? '';
    for (final cid in conversationIds) {
      _markForegroundConversationReadIfVisible(cid);
    }
    if (conversationIds.isNotEmpty) {
      debugPrint(
        'flare app incoming_messages cids=${conversationIds.join(',')} '
        'foreground=$fg',
      );
    }
  }

  void _onConversationUpdate(ConversationUpdateEvent e) {
    debugPrint(
      'flare app conversation_update cid=${e.conversationId?.trim() ?? 'all'}',
    );
  }

  void _onUnreadUpdate(UnreadUpdateEvent e) {
    final cid = e.conversationId.trim();
    if (cid.isEmpty) return;
    if ((ref.read(foregroundChatConversationIdProvider)?.trim() ?? '') == cid) {
      _markForegroundConversationReadIfVisible(cid);
      return;
    }
    ref
        .read(conversationProvider.notifier)
        .applyUnreadPatch(cid, e.unreadCount);
  }

  void _onMessageReadReceipt(MessageReadReceiptEvent e) {
    final cid = e.conversationId.trim();
    if (cid.isEmpty || e.readSeq <= 0) return;
    ref
        .read(messageProvider(cid).notifier)
        .applyReadReceipt(readSeq: e.readSeq, readerUserId: e.readerUserId);
    ref.read(conversationProvider.notifier).applyPeerReadSeq(cid, e.readSeq);
  }

  void _onMessageSendAck(MessageSendAckEvent e) {
    final cid = '${e.ack['conversationId'] ?? ''}'.trim();
    if (cid.isEmpty) return;
    ref.read(messageProvider(cid).notifier).applySendAck(e.ack);
  }

  void _onRecallMessage(RecallMessageEvent e) {
    final cid = e.conversationId.trim();
    final messageId = e.messageId.trim();
    if (cid.isEmpty || messageId.isEmpty) return;
    ref.read(messageProvider(cid).notifier).applyRecallNotice(messageId);
  }

  void _onMessageReactionChanged(MessageReactionChangedEvent e) {
    final cid = e.conversationId.trim();
    if (cid.isEmpty) return;
    ref
        .read(messageProvider(cid).notifier)
        .applyReactionChanged(
          serverMsgId: e.serverMsgId,
          userId: e.userId,
          emoji: e.emoji,
          action: e.action,
        );
  }

  void _onTyping(TypingEvent e) {
    ref
        .read(typingMapProvider.notifier)
        .applyTypingEvent(
          conversationId: e.conversationId,
          userId: e.userId,
          isTyping: e.isTyping,
        );
  }

  void _onUserInfo(UserInfoUpdateEvent e) {
    ref.read(userDirectoryProvider.notifier).upsert(e.user);
    final self = ref.read(currentUserProvider);
    if (self != null && self.userId == e.user.userId) {
      unawaited(ref.read(currentUserProvider.notifier).refresh());
    }
  }

  void _onPresence(PresenceUpdateEvent e) {
    ref.read(presenceMapProvider.notifier).setOnline(e.userId, e.isOnline);
  }

  void _onConnection(ConnectionChangedEvent _) {
    unawaited(ref.read(connectionStateProvider.notifier).refresh());
  }

  void _onSdkLifecycleUpdated(SdkLifecycleUpdatedEvent e) {
    ref.read(sdkRuntimeStatusProvider.notifier).applyLifecycle(e.payload);
  }

  void _onSdkConnectionUpdated(SdkConnectionUpdatedEvent e) {
    ref.read(sdkRuntimeStatusProvider.notifier).applyConnection(e.payload);
  }

  void _onSdkSyncUpdated(SdkSyncUpdatedEvent e) {
    ref.read(sdkRuntimeStatusProvider.notifier).applySync(e.payload);
    final event = '${e.payload['event'] ?? ''}';
    debugPrint('sdk sync event=$event payload=${e.payload}');
  }

  void _onSdkProgressUpdated(SdkProgressUpdatedEvent e) {
    final event = '${e.payload['event'] ?? ''}';
    final operation = '${e.payload['operation'] ?? ''}'.trim();
    if (event != 'sync_progress' && !operation.contains('sync')) return;

    final current = (e.payload['current'] as num?)?.toInt() ?? 0;
    final total = (e.payload['total'] as num?)?.toInt() ?? 0;
    final progress = total > 0 ? (current * 100 / total).round() : current;
    ref.read(sdkRuntimeStatusProvider.notifier).applySync({
      'event': 'progress',
      'task': operation.isEmpty ? 'sync' : operation,
      'progress': progress.clamp(0, 100),
    });
  }

  Future<void> _openConversationListView({required String reason}) async {
    try {
      final sdk = ref.read(sdkWrapperProvider);
      if (!sdk.isInitialized) return;
      final response = await sdk
          .openConversationListView(conversationLimit: 100)
          .timeout(const Duration(seconds: 3));
      if (!mounted) return;
      final snapshot = response.snapshot;
      final data = snapshot.data;
      if (snapshot.viewType != 'conversationList' ||
          data is! core.HomeTimelineSnapshot) {
        return;
      }
      ref
          .read(conversationProvider.notifier)
          .applyCoreSnapshot(
            SdkModelMapper.conversationsFromCoreHomeTimeline(data),
          );
      ref
          .read(sdkRuntimeStatusProvider.notifier)
          .markReady(conversationCount: ref.read(conversationProvider).length);
      debugPrint(
        'flare app openConversationListView ok reason=$reason '
        'count=${ref.read(conversationProvider).length}',
      );
    } catch (e, st) {
      debugPrint('openConversationListView failed ($reason): $e\n$st');
    }
  }

  void _markForegroundConversationReadIfVisible(String conversationId) {
    final cid = conversationId.trim();
    if (cid.isEmpty) return;
    final fg = ref.read(foregroundChatConversationIdProvider)?.trim() ?? '';
    if (fg != cid) return;
    unawaited(ref.read(messageProvider(cid).notifier).markFullyReadAtTop());
  }

  Future<void> _setHeartbeatAppState(core.HeartbeatAppState appState) async {
    try {
      final sdk = ref.read(sdkWrapperProvider);
      if (!sdk.isInitialized) return;
      await sdk.setHeartbeatAppState(appState);
    } catch (e, st) {
      debugPrint('setHeartbeatAppState failed (${appState.name}): $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserProvider, (prev, next) {
      if (next != null) {
        final userId = next.userId.trim();
        if (userId.isNotEmpty && userId != _lastLoadedUserId) {
          _lastLoadedUserId = userId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(_openConversationListView(reason: 'current_user'));
            unawaited(_setHeartbeatAppState(core.HeartbeatAppState.foreground));
          });
        }
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _lastLoadedUserId = null;
        ref.read(activeChatStackProvider.notifier).clear();
        ref.read(conversationProvider.notifier).clear();
        ref.read(typingMapProvider.notifier).clearAll();
        ref.read(userDirectoryProvider.notifier).clearAll();
        ref.read(presenceMapProvider.notifier).clearAll();
        ref.read(sdkRuntimeStatusProvider.notifier).reset();
        ref.read(selectedConversationProvider.notifier).state = null;
      });
    });
    return widget.child;
  }
}
