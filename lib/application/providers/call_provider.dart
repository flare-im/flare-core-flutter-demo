import 'dart:async';

import 'package:flare_call_kit/flare_call_kit.dart';
import 'package:flare_im/application/bus/event_bus.dart';
import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/application/providers/sdk_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 开发联调默认开启音视频通话，可通过 --dart-define=FLARE_ENABLE_CALL_KIT=false 关闭。
final callKitEnabledProvider = Provider<bool>((ref) {
  return const bool.fromEnvironment(
    'FLARE_ENABLE_CALL_KIT',
    defaultValue: true,
  );
});

final callBackendAdapterProvider = Provider<SdkCallBackendAdapter>((ref) {
  final sdk = ref.watch(sdkWrapperProvider);
  final currentUser = ref.watch(currentUserProvider);
  return SdkCallBackendAdapter(
    dispatchJson: sdk.messageDispatchJson,
    userId: currentUser?.userId,
  );
});

final callSessionStoreProvider = Provider<InMemoryCallSessionStore>((ref) {
  return const InMemoryCallSessionStore();
});

final callControllerProvider = Provider<FlareCallKitController?>((ref) {
  final enabled = ref.watch(callKitEnabledProvider);
  if (!enabled) {
    return null;
  }
  final sdk = ref.watch(sdkWrapperProvider);
  final currentUser = ref.watch(currentUserProvider);
  final store = ref.watch(callSessionStoreProvider);
  const mediaBridge = FlutterWebRtcMediaBridge();
  final controller = FlareCallKitController(
    backend: ref.watch(callBackendAdapterProvider),
    signalSender: SdkCallSignalSender(dispatchJson: sdk.messageDispatchJson),
    store: store,
    mediaBridge: mediaBridge,
    currentUserId: currentUser?.userId,
  );
  ref.listen(currentUserProvider, (prev, next) {
    controller.setCurrentUserId(next?.userId);
  });
  final StreamSubscription<CallSignalEvent> sub = imEventBus
      .on<CallSignalEvent>()
      .listen((event) async {
        final payload = NormalizedCallSignalPayload.tryParse(event.payload);
        if (payload != null) {
          await controller.handleSignal(payload);
        }
      });
  ref.onDispose(() {
    unawaited(sub.cancel());
    controller.dispose();
  });
  return controller;
});
