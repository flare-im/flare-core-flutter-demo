import 'package:flare_im/domain/entities/user.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/transport_mode.dart';

abstract class IAuthRepository {
  /// 幂等初始化原生 SDK（示例登录前调用；具体 URL 由 UI 传入，不依赖 FFI 类型泄漏到 interface）。
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
  });

  bool get isSdkInitialized;

  Future<User> login(String userId, String token);

  /// 调用 `flare_sdk_logout`，不释放 SDK 句柄
  Future<void> logout();

  Future<User?> getCurrentUser();

  Future<ConnectionState> getConnectionState();

  Future<String> generateCoreToken(String userId, int expireSeconds);

  Future<String> sdkVersion();
}
