import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/interface/widgets/message/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('failed self message keeps retry affordance near the bubble', (
    tester,
  ) async {
    var retryCount = 0;
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: Message(
              serverId: '',
              clientMsgId: 'cm1',
              conversationId: 'c1',
              senderId: 'u1',
              seq: 0,
              timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
              clientTimestamp: DateTime.fromMillisecondsSinceEpoch(1000),
              content: const TextContent('hello'),
              status: MessageStatus.failed,
              source: MessageSource.local,
              senderName: '',
              senderAvatar: '',
              senderDisplayName: '',
            ),
            currentUserId: 'u1',
            onResend: () => retryCount++,
          ),
        ),
      ),
    );

    final retry = find.text('重发');
    expect(retry, findsOneWidget);
    expect(tester.getTopLeft(retry).dx, greaterThan(500));

    await tester.tap(retry);
    expect(retryCount, 1);
  });
}
