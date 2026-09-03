import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 登录必须支持「直接填服务端签好的接入 token」，而不是只能本地自签。
///
/// 把**签名密钥**放进客户端等于让任何拿到安装包的人伪造任意用户身份 ——
/// 仓库自己的 mint_token.py 就是这么写的：密钥留在服务器上，只把签好的 token
/// 发出去。web 端一直有这个输入框，原生端没有，于是只能连"自己握有密钥"的服务器，
/// 既挡住了对生产环境的验证，也把用户推向"把密钥塞进配置"这条错误的路。
void main() {
  final source = File('lib/interface/screens/login/login_screen.dart')
      .readAsStringSync();

  group('登录的接入 token 入口', () {
    test('有可输入的 token 控制器，并接进了登录流程', () {
      expect(source.contains('_accessTokenController'), isTrue,
          reason: '缺少接入 token 的输入控制器');
      expect(
        RegExp(r'controller:\s*_accessTokenController').hasMatch(source),
        isTrue,
        reason: 'token 控制器没有绑到任何输入框上，用户填不进去',
      );
    });

    test('填了 token 就直接用，不再走本地自签', () {
      expect(
        RegExp(r'pastedToken\.isNotEmpty\s*\?\s*pastedToken').hasMatch(source),
        isTrue,
        reason: '填了 token 却仍然本地签一个，等于这个入口没用',
      );
    });

    test('只有三条路都没有时才报错：贴了 token、或运行时填了密钥，都不能被挡', () {
      // 三条路：贴服务端签好的 token / 运行时填签名密钥 / 构建期配置的密钥。
      // 任一存在都要放行；判据钉住"三者皆空才报错"这个形态。
      expect(
        RegExp(
          r'pastedToken\.isEmpty\s*&&\s*typedSecret\.isEmpty\s*&&\s*!_defaults\.hasUsableTokenSecret',
        ).hasMatch(source),
        isTrue,
        reason: '密钥检查没有让开 token / 运行时密钥路径，填了也会被挡下',
      );
    });

    test('运行时填的密钥优先于构建期默认值，并真的传给了 SDK 初始化', () {
      // 做成运行时输入而不是打进安装包：打进去等于让任何拿到安装包的人伪造任意用户身份。
      expect(source.contains('_tokenSecretController'), isTrue,
          reason: '缺少签名密钥的输入控制器');
      expect(
        RegExp(r'typedSecret\.isNotEmpty\s*\?\s*typedSecret\s*:\s*_defaults\.devTokenSecret')
            .hasMatch(source),
        isTrue,
        reason: '运行时密钥没有覆盖构建期默认值',
      );
      expect(source.contains('tokenSecret: effectiveSecret,'), isTrue,
          reason: '生效的密钥没有传给 SDK 初始化');
      expect(source.contains('_tokenSecretController.dispose()'), isTrue);
    });

    test('token 控制器被释放，不泄漏', () {
      expect(source.contains('_accessTokenController.dispose()'), isTrue);
    });
  });
}
