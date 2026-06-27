import 'package:flare_im/application/providers/sdk_provider.dart';
import 'package:flare_im/application/services/auth_service.dart';
import 'package:flare_im/application/services/conversation_service.dart';
import 'package:flare_im/application/services/message_service.dart';
import 'package:flare_im/domain/repositories/i_auth_repository.dart';
import 'package:flare_im/domain/repositories/i_conversation_repository.dart';
import 'package:flare_im/domain/repositories/i_message_repository.dart';
import 'package:flare_im/infrastructure/repositories/auth_repository_impl.dart';
import 'package:flare_im/infrastructure/repositories/conversation_repository_impl.dart';
import 'package:flare_im/infrastructure/repositories/message_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 认证仓库 Provider
final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  final sdkWrapper = ref.watch(sdkWrapperProvider);
  return AuthRepositoryImpl(sdkWrapper);
});

/// 会话仓库 Provider
final conversationRepositoryProvider = Provider<IConversationRepository>((ref) {
  final sdkWrapper = ref.watch(sdkWrapperProvider);
  return ConversationRepositoryImpl(sdkWrapper);
});

/// 消息仓库 Provider
final messageRepositoryProvider = Provider<IMessageRepository>((ref) {
  final sdkWrapper = ref.watch(sdkWrapperProvider);
  return MessageRepositoryImpl(sdkWrapper);
});

/// 认证服务 Provider
final authServiceProvider = Provider<AuthService>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthService(authRepository);
});

/// 会话服务 Provider
final conversationServiceProvider = Provider<ConversationService>((ref) {
  final conversationRepository = ref.watch(conversationRepositoryProvider);
  return ConversationService(conversationRepository);
});

/// 消息服务 Provider
final messageServiceProvider = Provider<MessageService>((ref) {
  final messageRepository = ref.watch(messageRepositoryProvider);
  return MessageService(messageRepository);
});
