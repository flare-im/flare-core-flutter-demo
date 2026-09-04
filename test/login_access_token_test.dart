import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 客户端不再本地签发接入 token（那等于把签名密钥打进安装包）。
/// SDK 托管：init 把网关地址交给核心（auth.tokenEndpoint），login 不传 token；
/// 应用托管：高级区粘贴 token 原样传。
void main() {
  final loginSource = File(
    'lib/interface/screens/login/login_screen.dart',
  ).readAsStringSync();
  final wrapperSource = File(
    'lib/infrastructure/sdk/flare_core_sdk_wrapper.dart',
  ).readAsStringSync();

  test('登录页只剩接入 token 入口，没有签名密钥', () {
    expect(loginSource.contains('_accessTokenController'), isTrue);
    expect(loginSource.contains('_tokenSecretController'), isFalse);
    expect(loginSource.contains('authGenerateCoreToken'), isFalse);
  });

  test('粘贴了 token 就原样传，留空则不传（交给核心向网关签发）', () {
    expect(
      loginSource.contains(
        'final String? token = pastedToken.isNotEmpty ? pastedToken : null;',
      ),
      isTrue,
    );
    expect(
      wrapperSource.contains("if (explicit.isNotEmpty) 'token': explicit,"),
      isTrue,
    );
  });

  test('init 把网关地址交给核心', () {
    expect(
      wrapperSource.contains("'auth': {'tokenEndpoint': _httpUrl}"),
      isTrue,
    );
    expect(wrapperSource.contains('generateCoreToken'), isFalse);
    expect(wrapperSource.contains('tokenSecret'), isFalse);
  });

  test('token 控制器被释放，不泄漏', () {
    expect(loginSource.contains('_accessTokenController.dispose()'), isTrue);
  });
}
