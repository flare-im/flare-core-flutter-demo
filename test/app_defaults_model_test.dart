import 'package:flare_im/domain/value_objects/transport_mode.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flare_im/shared/config/app_defaults_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults use the access-gateway websocket route', () {
    expect(AppDefaults.fallback.defaultWsUrl, 'ws://127.0.0.1:60051/ws');
    expect(AppDefaults.fallback.defaultQuicUrl, 'quic://127.0.0.1:60052');
    expect(AppDefaults.fallback.defaultTlsCaCertPath, isEmpty);
    expect(
      AppDefaults.fallback.devTokenSecret.length,
      greaterThanOrEqualTo(32),
    );
    expect(AppDefaults.fallback.tokenIssuer, 'flare-im-core');
    expect(AppDefaults.fallback.tokenTtlSecs, 3600);
    expect(AppDefaults.fallback.defaultUserId, isEmpty);
  });

  test('loads gateway and token settings from app defaults json shape', () {
    final defaults = AppDefaults.fromJson(const {
      'defaultWsUrl': 'ws://127.0.0.1:60051/ws',
      'defaultQuicUrl': 'quic://127.0.0.1:60052',
      'defaultTlsCaCertPath': '/tmp/flare-server.crt',
      'tenantId': '0',
      'devTokenSecret':
          'local-test-token-secret-with-at-least-thirty-two-bytes',
      'tokenIssuer': 'flare-im-core',
      'tokenTtlSecs': 900,
      'userId': 'bob',
    });

    expect(defaults.defaultWsUrl, 'ws://127.0.0.1:60051/ws');
    expect(defaults.defaultQuicUrl, 'quic://127.0.0.1:60052');
    expect(defaults.defaultTlsCaCertPath, '/tmp/flare-server.crt');
    expect(defaults.tenantId, '0');
    expect(
      defaults.devTokenSecret,
      'local-test-token-secret-with-at-least-thirty-two-bytes',
    );
    expect(defaults.tokenIssuer, 'flare-im-core');
    expect(defaults.tokenTtlSecs, 900);
    expect(defaults.defaultUserId, 'bob');
  });

  test('maps Flutter login transport choices to SDK init config', () {
    expect(
      buildSdkTransportConfig(
        SdkConfig(
          wsUrl: ' ws://127.0.0.1:60051/ws ',
          tokenSecret: AppDefaults.fallback.devTokenSecret,
        ),
      ),
      {
        'wsUrl': 'ws://127.0.0.1:60051/ws',
        'transportPolicy': 'websocket_only',
        'defaultTransport': 'websocket',
      },
    );

    expect(
      buildSdkTransportConfig(
        SdkConfig(
          wsUrl: 'ws://127.0.0.1:60051/ws',
          transportMode: SdkTransportMode.quic,
          quicUrl: ' quic://127.0.0.1:60052 ',
          tlsCaCertPath: ' /tmp/flare-server.crt ',
          tokenSecret: AppDefaults.fallback.devTokenSecret,
        ),
      ),
      {
        'wsUrl': 'ws://127.0.0.1:60051/ws',
        'quicUrl': 'quic://127.0.0.1:60052',
        'tlsCaCertPath': '/tmp/flare-server.crt',
        'transportPolicy': 'auto',
        'defaultTransport': 'quic',
        'protocolRaceOrder': ['quic'],
      },
    );

    expect(
      buildSdkTransportConfig(
        SdkConfig(
          wsUrl: 'ws://127.0.0.1:60051/ws',
          transportMode: SdkTransportMode.race,
          quicUrl: 'quic://127.0.0.1:60052',
          tokenSecret: AppDefaults.fallback.devTokenSecret,
        ),
      ),
      {
        'wsUrl': 'ws://127.0.0.1:60051/ws',
        'quicUrl': 'quic://127.0.0.1:60052',
        'transportPolicy': 'protocol_race',
        'defaultTransport': 'quic',
        'protocolRaceOrder': ['quic', 'websocket'],
      },
    );
  });
}
