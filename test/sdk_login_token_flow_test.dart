import 'dart:convert';
import 'dart:io';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart';
import 'package:flare_im/infrastructure/paths/sdk_data_url.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flare_im/shared/config/app_defaults_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'generates a core login token through the core SDK FFI contract',
    () async {
      final client = FlareCoreSdk.createClient();
      addTearDown(client.dispose);

      final result = await client
          .generateCoreToken(
            CoreTokenRequest(
              userId: 'hugo',
              secret: AppDefaults.fallback.devTokenSecret,
              issuer: 'flare-im-core',
              ttlSecs: 3600,
              tenantId: '0',
            ),
          )
          .timeout(const Duration(seconds: 5));
      _expectCoreToken(result.token);
    },
  );

  test('initializes SDK and generates a core login token', () async {
    final root = await Directory.systemTemp.createTemp('flare-sdk-token-test-');
    final sdk = SdkWrapper();
    addTearDown(() async {
      await sdk.dispose();
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    await sdk
        .init(
          SdkConfig(
            wsUrl: 'ws://127.0.0.1:60051/ws',
            tenantId: '0',
            tokenSecret: AppDefaults.fallback.devTokenSecret,
            tokenIssuer: AppDefaults.fallback.tokenIssuer,
            tokenTtlSecs: AppDefaults.fallback.tokenTtlSecs,
            dataUrl: toFileDataUrl(root.path),
          ),
        )
        .timeout(const Duration(seconds: 5));

    final token = await sdk
        .generateCoreToken(userId: 'hugo', ttlSecs: 3600)
        .timeout(const Duration(seconds: 5));
    _expectCoreToken(token);
  });
}

void _expectCoreToken(String token) {
  final parts = token.split('.');
  expect(parts, hasLength(3));

  final payload =
      jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
          as Map<String, dynamic>;
  expect(payload['sub'], 'hugo');
  expect(payload['iss'], 'flare-im-core');
  expect(payload['tenant_id'], '0');
  expect((payload['exp'] as num).toInt(), greaterThan(payload['iat']));
}
