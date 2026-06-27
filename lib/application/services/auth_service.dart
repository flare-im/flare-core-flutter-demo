import 'package:flare_im/domain/entities/user.dart';
import 'package:flare_im/domain/repositories/i_auth_repository.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/transport_mode.dart';

class AuthService {
  final IAuthRepository _repo;

  AuthService(this._repo);

  bool get isSdkInitialized => _repo.isSdkInitialized;

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
  }) => _repo.initSdk(
    wsUrl: wsUrl,
    transportMode: transportMode,
    quicUrl: quicUrl,
    tenantId: tenantId,
    tokenSecret: tokenSecret,
    tokenIssuer: tokenIssuer,
    tokenTtlSecs: tokenTtlSecs,
    tlsCaCertPath: tlsCaCertPath,
    dataUrl: dataUrl,
  );

  Future<User> login(String userId, String token) => _repo.login(userId, token);

  Future<void> logout() => _repo.logout();

  Future<User?> getCurrentUser() => _repo.getCurrentUser();

  Future<ConnectionState> getConnectionState() => _repo.getConnectionState();

  Future<String> generateCoreToken(String userId, {int expireSeconds = 3600}) {
    return _repo.generateCoreToken(userId, expireSeconds);
  }

  Future<String> sdkVersion() => _repo.sdkVersion();
}
