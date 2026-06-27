import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/application/providers/conversation_state_provider.dart';
import 'package:flare_im/application/providers/im_outbound_provider.dart';
import 'package:flare_im/application/providers/message_state_provider.dart';
import 'package:flare_im/application/providers/sdk_runtime_status_provider.dart';
import 'package:flare_im/application/providers/service_providers.dart';
import 'package:flare_im/domain/entities/conversation.dart';
import 'package:flare_im/domain/entities/user.dart';
import 'package:flare_im/domain/repositories/i_auth_repository.dart';
import 'package:flare_im/domain/repositories/i_conversation_repository.dart';
import 'package:flare_im/domain/repositories/i_message_repository.dart';
import 'package:flare_im/domain/value_objects/conversation_filter.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/transport_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'authLogin bootstraps conversations when the local list is empty',
    () async {
      final conversation = _conversation('c1');
      final conversationRepo = _FakeConversationRepository(
        listResult: const [],
        bootstrapResult: [conversation],
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          conversationRepositoryProvider.overrideWithValue(conversationRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(imOutboundProvider).authLogin('u1', 'token');

      expect(conversationRepo.bootstrapCalls, 1);
      expect(conversationRepo.listCalls, 0);
      expect(
        container.read(connectionStateProvider),
        ConnectionState.connected,
      );
      expect(container.read(conversationProvider), [conversation]);
    },
  );

  test('authLogin treats an empty core snapshot as a ready inbox', () async {
    final conversationRepo = _FakeConversationRepository(
      listResult: const [],
      bootstrapResult: const [],
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        conversationRepositoryProvider.overrideWithValue(conversationRepo),
      ],
    );
    addTearDown(container.dispose);

    await container.read(imOutboundProvider).authLogin('u1', 'token');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final status = container.read(sdkRuntimeStatusProvider);
    expect(conversationRepo.bootstrapCalls, 1);
    expect(container.read(conversationProvider), isEmpty);
    expect(status.phase, SdkRuntimePhase.ready);
    expect(status.isFailure, isFalse);
    expect(status.detail, '暂无会话，可以发起新会话');
  });

  test('conversationListReload keeps an empty core snapshot ready', () async {
    final conversationRepo = _FakeConversationRepository(
      listResult: const [],
      bootstrapResult: const [],
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        conversationRepositoryProvider.overrideWithValue(conversationRepo),
      ],
    );
    addTearDown(container.dispose);

    await container.read(imOutboundProvider).conversationListReload();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final status = container.read(sdkRuntimeStatusProvider);
    expect(conversationRepo.bootstrapCalls, 1);
    expect(container.read(conversationProvider), isEmpty);
    expect(status.phase, SdkRuntimePhase.ready);
    expect(status.isFailure, isFalse);
    expect(status.detail, '暂无会话，可以发起新会话');
  });

  test(
    'sendText revalidates single chat routing before message build',
    () async {
      final conversation = _conversation(
        '1A7V00JWT0G5255VPD',
        peerUserId: 'u2',
      );
      final conversationRepo = _FakeConversationRepository(
        listResult: [conversation],
        bootstrapResult: [conversation],
        getOneResult: conversation,
      );
      final messageRepo = _FakeMessageRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          conversationRepositoryProvider.overrideWithValue(conversationRepo),
          messageRepositoryProvider.overrideWithValue(messageRepo),
        ],
      );
      addTearDown(container.dispose);

      container.read(conversationProvider.notifier).upsert(conversation);

      await container
          .read(messageProvider(conversation.conversationId).notifier)
          .sendText('hello');

      expect(conversationRepo.getOneSources, ['u2']);
      expect(conversationRepo.getOneTypes, [ConversationType.single]);
      expect(
        messageRepo.createdTextConversationId,
        conversation.conversationId,
      );
      expect(
        messageRepo.sentCoreMessage?.conversationId,
        conversation.conversationId,
      );
    },
  );
}

Conversation _conversation(String id, {String? peerUserId}) {
  final now = DateTime.fromMillisecondsSinceEpoch(1000);
  return Conversation(
    conversationId: id,
    conversationType: ConversationType.single,
    displayName: 'User $id',
    avatarUrl: '',
    updatedAt: now,
    createdAt: now,
    peerUserId: peerUserId,
  );
}

final class _FakeAuthRepository implements IAuthRepository {
  @override
  bool get isSdkInitialized => true;

  @override
  Future<void> initSdk({
    required String wsUrl,
    required SdkTransportMode transportMode,
    required String quicUrl,
    required String tenantId,
    required String tokenSecret,
    required String tokenIssuer,
    required int tokenTtlSecs,
    String? tlsCaCertPath,
    String? dataUrl,
  }) async {}

  @override
  Future<User> login(String userId, String token) async {
    return User(userId: userId, nickname: userId);
  }

  @override
  Future<void> logout() async {}

  @override
  Future<User?> getCurrentUser() async => null;

  @override
  Future<ConnectionState> getConnectionState() async =>
      ConnectionState.connected;

  @override
  Future<String> generateCoreToken(String userId, int expireSeconds) async =>
      'token';

  @override
  Future<String> sdkVersion() async => 'test';
}

final class _FakeConversationRepository implements IConversationRepository {
  _FakeConversationRepository({
    required this.listResult,
    required this.bootstrapResult,
    this.getOneResult,
  });

  final List<Conversation> listResult;
  final List<Conversation> bootstrapResult;
  final Conversation? getOneResult;
  int listCalls = 0;
  int bootstrapCalls = 0;
  final List<String> getOneSources = [];
  final List<ConversationType> getOneTypes = [];

  @override
  Future<List<Conversation>> getConversations({
    ConversationFilter filter = ConversationFilter.all,
    String? keyword,
  }) async {
    listCalls += 1;
    return listResult;
  }

  @override
  Future<List<Conversation>> bootstrapHomeTimeline({
    int conversationLimit = 100,
  }) async {
    bootstrapCalls += 1;
    return bootstrapResult;
  }

  @override
  Future<Conversation?> getConversation(String id) async {
    for (final conversation in [...listResult, ...bootstrapResult]) {
      if (conversation.conversationId == id) return conversation;
    }
    return getOneResult?.conversationId == id ? getOneResult : null;
  }

  @override
  Future<Conversation?> getConversationOne(
    String sourceId,
    ConversationType type,
  ) async {
    getOneSources.add(sourceId);
    getOneTypes.add(type);
    return getOneResult ??
        _conversation('canonical-$sourceId', peerUserId: sourceId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeMessageRepository implements IMessageRepository {
  String? createdTextConversationId;
  core.Message? sentCoreMessage;

  @override
  Future<core.Message> createTextMessage(
    String conversationId,
    String text,
  ) async {
    createdTextConversationId = conversationId;
    return core.Message(
      clientMsgId: 'cm1',
      conversationId: conversationId,
      conversationType: ConversationType.single.value,
      channelId: 'u2',
      senderId: 'u1',
      messageType: 1,
      source: 2,
      status: 1,
      createdAt: 1000,
      clientCreatedAt: 1000,
      content: core.MessageContent(
        contentType: core.MessageContentType.text,
        data: {'text': text},
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> sendCoreMessage(
    core.Message message, {
    MessageSendEventCallback? onProgress,
    MessageSendEventCallback? onSuccess,
    MessageSendEventCallback? onFailure,
  }) async {
    sentCoreMessage = message;
    final ack = <String, dynamic>{
      'success': true,
      'clientMsgId': message.clientMsgId,
      'conversationId': message.conversationId,
      'serverMsgId': 's1',
      'seq': 1,
    };
    onSuccess?.call(ack);
    return ack;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
