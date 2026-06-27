import 'package:flare_im/application/providers/service_providers.dart';
import 'package:flare_im/application/services/auth_service.dart';
import 'package:flare_im/domain/entities/user.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前用户状态
final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, User?>((
  ref,
) {
  final authService = ref.watch(authServiceProvider);
  return CurrentUserNotifier(authService);
});

class CurrentUserNotifier extends StateNotifier<User?> {
  final AuthService _authService;

  CurrentUserNotifier(this._authService) : super(null);

  /// 登录
  Future<void> login(String userId, String token) async {
    final user = await _authService.login(userId, token);
    state = user;
  }

  /// 登出
  Future<void> logout() async {
    await _authService.logout();
    state = null;
  }

  /// 刷新用户信息
  Future<void> refresh() async {
    final user = await _authService.getCurrentUser();
    state = user;
  }
}

/// 连接状态
final connectionStateProvider =
    StateNotifierProvider<ConnectionStateNotifier, ConnectionState>((ref) {
      final authService = ref.watch(authServiceProvider);
      return ConnectionStateNotifier(authService);
    });

class ConnectionStateNotifier extends StateNotifier<ConnectionState> {
  final AuthService _authService;

  ConnectionStateNotifier(this._authService)
    : super(ConnectionState.disconnected);

  /// 刷新连接状态
  Future<void> refresh() async {
    final state = await _authService.getConnectionState();
    this.state = state;
  }
}

/// 是否已登录
final isLoggedInProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});
