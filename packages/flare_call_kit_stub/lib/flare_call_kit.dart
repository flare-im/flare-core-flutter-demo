import 'package:flutter/material.dart';

typedef CallDispatchJson =
    Future<Map<String, dynamic>> Function(
      String op,
      Map<String, dynamic> params,
    );

@immutable
final class CallKitLabels {
  const CallKitLabels({this.audioCall = '语音通话', this.videoCall = '视频通话'});

  final String audioCall;
  final String videoCall;
}

@immutable
final class StartCallInput {
  const StartCallInput({
    required this.conversationId,
    required this.withVideo,
    this.peerUserId,
    this.participantUserIds,
  });

  final String conversationId;
  final bool withVideo;
  final String? peerUserId;
  final List<String>? participantUserIds;
}

@immutable
final class NormalizedCallSignalPayload {
  const NormalizedCallSignalPayload({
    required this.conversationId,
    required this.callId,
    required this.fromUserId,
    required this.variant,
    required this.body,
    required this.ext,
    this.toUserId,
    this.transport = const <String, dynamic>{},
  });

  final String conversationId;
  final String callId;
  final String fromUserId;
  final String variant;
  final String? toUserId;
  final Map<String, dynamic> body;
  final Map<String, dynamic> transport;
  final Map<String, String> ext;

  static NormalizedCallSignalPayload? tryParse(Map<String, dynamic> raw) {
    final conversationId = _pickString(raw['conversationId']);
    final callId = _pickString(raw['callId']);
    final fromUserId = _pickString(raw['fromUserId']);
    final variant = _pickString(raw['variant']);
    if (conversationId == null ||
        callId == null ||
        fromUserId == null ||
        variant == null ||
        conversationId.isEmpty ||
        callId.isEmpty ||
        fromUserId.isEmpty ||
        variant.isEmpty) {
      return null;
    }
    return NormalizedCallSignalPayload(
      conversationId: conversationId,
      callId: callId,
      fromUserId: fromUserId,
      variant: variant,
      toUserId: _pickString(raw['toUserId']),
      body: _stringMap(raw['body']),
      transport: _stringMap(raw['transport']),
      ext: _stringStringMap(raw['ext']),
    );
  }
}

final class SdkCallBackendAdapter {
  const SdkCallBackendAdapter({
    required CallDispatchJson dispatchJson,
    this.tenantId,
    this.userId,
  }) : _dispatchJson = dispatchJson;

  final CallDispatchJson _dispatchJson;
  final String? tenantId;
  final String? userId;

  Future<Map<String, dynamic>> dispatchProbe(StartCallInput input) {
    return _dispatchJson('capability_dispatch', {
      'capability': input.withVideo ? 'rtc.call.video' : 'rtc.call.audio',
      'conversationId': input.conversationId,
      if (input.peerUserId != null && input.peerUserId!.trim().isNotEmpty)
        'peerUserId': input.peerUserId!.trim(),
      if (input.participantUserIds != null &&
          input.participantUserIds!.isNotEmpty)
        'participantUserIds': input.participantUserIds,
    });
  }
}

final class SdkCallSignalSender {
  const SdkCallSignalSender({required CallDispatchJson dispatchJson})
    : _dispatchJson = dispatchJson;

  final CallDispatchJson _dispatchJson;

  Future<void> send(Map<String, dynamic> payload) async {
    await _dispatchJson('send_call_signal', payload);
  }
}

final class InMemoryCallSessionStore {
  const InMemoryCallSessionStore();
}

final class FlutterWebRtcMediaBridge {
  const FlutterWebRtcMediaBridge();

  Future<void> dispose() async {}
}

final class FlareCallKitController extends ChangeNotifier {
  FlareCallKitController({
    required SdkCallBackendAdapter backend,
    required SdkCallSignalSender signalSender,
    required InMemoryCallSessionStore store,
    FlutterWebRtcMediaBridge? mediaBridge,
    String? currentUserId,
  }) : _backend = backend,
       _signalSender = signalSender,
       _store = store,
       _mediaBridge = mediaBridge,
       _currentUserId = currentUserId;

  final SdkCallBackendAdapter _backend;
  final SdkCallSignalSender _signalSender;
  final InMemoryCallSessionStore _store;
  final FlutterWebRtcMediaBridge? _mediaBridge;
  String? _currentUserId;

  InMemoryCallSessionStore get store => _store;

  void setCurrentUserId(String? userId) {
    final trimmed = userId?.trim();
    _currentUserId = trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<String> start(StartCallInput input) async {
    final callId = 'stub-${DateTime.now().microsecondsSinceEpoch}';
    try {
      await _backend.dispatchProbe(input);
    } on Object {
      await _signalSender.send({
        'kind': 'invite',
        'conversationId': input.conversationId,
        'callId': callId,
        'fromUserId': _currentUserId ?? '',
        if (input.peerUserId != null && input.peerUserId!.trim().isNotEmpty)
          'toUserId': input.peerUserId!.trim(),
        'video': input.withVideo,
      });
    }
    notifyListeners();
    return callId;
  }

  Future<void> handleSignal(NormalizedCallSignalPayload payload) async {
    notifyListeners();
  }

  @override
  void dispose() {
    _mediaBridge?.dispose();
    super.dispose();
  }
}

final class CallOverlayHost extends StatelessWidget {
  const CallOverlayHost({
    super.key,
    required this.controller,
    required this.child,
    this.labels = const CallKitLabels(),
  });

  final FlareCallKitController controller;
  final Widget child;
  final CallKitLabels labels;

  @override
  Widget build(BuildContext context) => child;
}

typedef FlareCallKitHost = CallOverlayHost;

final class CallEntryActions extends StatelessWidget {
  const CallEntryActions({
    super.key,
    required this.controller,
    required this.conversationId,
    this.peerUserId,
    this.labels = const CallKitLabels(),
    this.iconColor,
  });

  final FlareCallKitController controller;
  final String conversationId;
  final String? peerUserId;
  final CallKitLabels labels;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: labels.audioCall,
          icon: Icon(Icons.call_outlined, color: iconColor),
          onPressed: () => _start(context, withVideo: false),
        ),
        IconButton(
          tooltip: labels.videoCall,
          icon: Icon(Icons.videocam_outlined, color: iconColor),
          onPressed: () => _start(context, withVideo: true),
        ),
      ],
    );
  }

  Future<void> _start(BuildContext context, {required bool withVideo}) async {
    try {
      await controller.start(
        StartCallInput(
          conversationId: conversationId,
          withVideo: withVideo,
          peerUserId: peerUserId,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('发起通话失败：$error')));
    }
  }
}

@immutable
final class CallSignalNoticeUiMeta {
  const CallSignalNoticeUiMeta({
    required this.variant,
    required this.mode,
    required this.icon,
    required this.text,
    this.durationText,
    this.semanticKey,
  });

  final String variant;
  final String mode;
  final String icon;
  final String text;
  final String? durationText;
  final String? semanticKey;
}

CallSignalNoticeUiMeta? parseCallSignalNoticeUiMeta({
  required String body,
  required Map<String, String> data,
}) {
  final variant = (data['variant'] ?? '').trim().toLowerCase();
  if (variant != 'reject' && variant != 'busy' && variant != 'hangup') {
    return null;
  }
  final mode = (data['mode'] ?? '').trim().toLowerCase() == 'video'
      ? 'video'
      : 'audio';
  final durationText = (data['durationText'] ?? '').trim();
  final callId = (data['callId'] ?? '').trim();
  final durationSeconds = (data['durationSeconds'] ?? '').trim();
  final reason = (data['reasonCode'] ?? '').trim().toLowerCase();
  return CallSignalNoticeUiMeta(
    variant: variant,
    mode: mode,
    icon: mode == 'video' ? 'video' : 'audio',
    text: body.trim().isEmpty ? '通话结束' : body.trim(),
    durationText: durationText.isEmpty ? null : durationText,
    semanticKey: callId.isEmpty
        ? null
        : '$callId|$variant|$reason|${durationSeconds.isEmpty ? '0' : durationSeconds}',
  );
}

final class CallNoticeTile extends StatelessWidget {
  const CallNoticeTile({
    super.key,
    required this.icon,
    required this.text,
    this.durationText,
  });

  final IconData icon;
  final String text;
  final String? durationText;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF8C8C8C)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7A7A7A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (durationText != null && durationText!.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                durationText!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9A9A9A)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String? _pickString(Object? primary, [Object? fallback]) {
  final first = primary?.toString().trim();
  if (first != null && first.isNotEmpty) return first;
  final second = fallback?.toString().trim();
  return second != null && second.isNotEmpty ? second : null;
}

Map<String, dynamic> _stringMap(Object? value) {
  if (value is! Map) return const <String, dynamic>{};
  return value.map((key, value) => MapEntry('$key', value));
}

Map<String, String> _stringStringMap(Object? value) {
  if (value is! Map) return const <String, String>{};
  return value.map((key, value) => MapEntry('$key', '$value'));
}
