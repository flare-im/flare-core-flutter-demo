import 'package:flare_call_kit/flare_call_kit.dart';
import 'package:flare_im/application/providers/call_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stub cannot advertise RTC or construct a controller', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(callKitEnabledProvider), isFalse);
    expect(container.read(callControllerProvider), isNull);
  });

  test('stub rejects a direct start without dispatching or sending an invite', () async {
    var dispatches = 0;
    Future<Map<String, dynamic>> dispatch(String op, Map<String, dynamic> params) async {
      dispatches++;
      return {};
    }
    final controller = FlareCallKitController(
      backend: SdkCallBackendAdapter(dispatchJson: dispatch),
      signalSender: SdkCallSignalSender(dispatchJson: dispatch),
      store: const InMemoryCallSessionStore(),
    );
    addTearDown(controller.dispose);
    await expectLater(
      controller.start(const StartCallInput(conversationId: 'test', withVideo: false)),
      throwsUnsupportedError,
    );
    expect(dispatches, 0);
  });
}
