import 'package:flare_im/interface/screens/login/login_error_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('核心报 AUTHENTICATION_FAILED / TOKEN_REJECTED 时换成「核对签名密钥」', () {
    expect(
      friendlyLoginError(Exception(
          '错误 [AUTHENTICATION_FAILED] connect failed primary=ws://x/ws: TOKEN_REJECTED: server closed the connection before CONNECT_ACK')),
      tokenRejectedLoginMessage,
    );
  });

  test('连不上服务器保持原文', () {
    const raw = '错误 [CONNECTION_FAILED] Negotiation timeout after 10s (CONNECT_ACK not received)';
    expect(friendlyLoginError(Exception(raw)), contains('CONNECTION_FAILED'));
    expect(isTokenRejectedLoginError(Exception(raw)), isFalse);
  });
}
