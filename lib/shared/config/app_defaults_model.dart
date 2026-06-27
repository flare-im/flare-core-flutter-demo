/// 与 [assets/config/app_defaults.json] 结构一致；解析失败时使用 [AppDefaults.fallback]。
class LoginCopy {
  const LoginCopy({
    required this.brandTitle,
    required this.subtitle,
    required this.welcomeTitle,
    required this.welcomeSubtitle,
    required this.userIdLabel,
    required this.userIdPlaceholder,
    required this.userHintRow,
    required this.primaryButton,
    required this.footerPrimary,
    required this.footerSecondary,
    required this.advancedWsLabel,
    required this.advancedWsHint,
  });

  /// 顶部品牌区大标题（如 flare IM）
  final String brandTitle;

  /// 品牌区副标题 / Slogan（渐变头上的说明文案）
  final String subtitle;
  final String welcomeTitle;
  final String welcomeSubtitle;
  final String userIdLabel;
  final String userIdPlaceholder;

  /// 输入框下方提示行（带信息图标）
  final String userHintRow;
  final String primaryButton;
  final String footerPrimary;
  final String footerSecondary;
  final String advancedWsLabel;
  final String advancedWsHint;

  static LoginCopy fromJson(Map<String, dynamic>? json) {
    if (json == null) return LoginCopy.fallback;
    String s(String k, String d) =>
        (json[k] as String?)?.trim().isNotEmpty == true ? json[k] as String : d;
    return LoginCopy(
      brandTitle: s('brandTitle', LoginCopy.fallback.brandTitle),
      subtitle: s('subtitle', LoginCopy.fallback.subtitle),
      welcomeTitle: s('welcomeTitle', LoginCopy.fallback.welcomeTitle),
      welcomeSubtitle: s('welcomeSubtitle', LoginCopy.fallback.welcomeSubtitle),
      userIdLabel: s('userIdLabel', LoginCopy.fallback.userIdLabel),
      userIdPlaceholder: s(
        'userIdPlaceholder',
        LoginCopy.fallback.userIdPlaceholder,
      ),
      userHintRow: s('userHintRow', LoginCopy.fallback.userHintRow),
      primaryButton: s('primaryButton', LoginCopy.fallback.primaryButton),
      footerPrimary: s('footerPrimary', LoginCopy.fallback.footerPrimary),
      footerSecondary: s('footerSecondary', LoginCopy.fallback.footerSecondary),
      advancedWsLabel: s('advancedWsLabel', LoginCopy.fallback.advancedWsLabel),
      advancedWsHint: s('advancedWsHint', LoginCopy.fallback.advancedWsHint),
    );
  }

  static const LoginCopy fallback = LoginCopy(
    brandTitle: 'flare IM',
    subtitle: '安全、快速的即时通讯',
    welcomeTitle: '欢迎回来',
    welcomeSubtitle: '请输入您的用户 ID 完成登录',
    userIdLabel: '用户 ID',
    userIdPlaceholder: '请输入您的用户 ID',
    userHintRow: '用户 ID 由系统分配，可在账号设置中查看',
    primaryButton: '立即登录',
    footerPrimary: 'ID 由管理员分配，可在邀请邮件中查看',
    footerSecondary: '仅支持 ID 登录 · 安全连接已启用',
    advancedWsLabel: '服务器地址（可选）',
    advancedWsHint: '留空则使用配置文件中的默认地址',
  );
}

class AppDefaults {
  const AppDefaults({
    required this.defaultWsUrl,
    required this.defaultQuicUrl,
    required this.defaultTlsCaCertPath,
    required this.tenantId,
    required this.devTokenSecret,
    required this.tokenIssuer,
    required this.tokenTtlSecs,
    required this.defaultUserId,
    required this.login,
  });

  final String defaultWsUrl;
  final String defaultQuicUrl;
  final String defaultTlsCaCertPath;
  final String tenantId;
  final String devTokenSecret;
  final String tokenIssuer;
  final int tokenTtlSecs;
  final String defaultUserId;
  final LoginCopy login;

  static const AppDefaults fallback = AppDefaults(
    defaultWsUrl: 'ws://127.0.0.1:60051/ws',
    defaultQuicUrl: 'quic://127.0.0.1:60052',
    defaultTlsCaCertPath: '',
    tenantId: '0',
    devTokenSecret:
        'jhkcGVl4L3t7GVY+4jJPHbq8P7KTJv4qoBzOFUYo6oMw6P63x9jbnvjLrQpZuElt',
    tokenIssuer: 'flare-im-core',
    tokenTtlSecs: 3600,
    defaultUserId: '',
    login: LoginCopy.fallback,
  );

  static AppDefaults fromJson(Map<String, dynamic> json) {
    const envTokenSecret = String.fromEnvironment('FLARE_TOKEN_SECRET');
    const envTokenIssuer = String.fromEnvironment('FLARE_TOKEN_ISSUER');
    const envQuicUrl = String.fromEnvironment('FLARE_QUIC_URL');
    const envTlsCaCertPath = String.fromEnvironment('FLARE_TLS_CA_CERT_PATH');
    const envTokenTtlSecs = int.fromEnvironment(
      'FLARE_TOKEN_TTL_SECS',
      defaultValue: 0,
    );
    final ws = (json['defaultWsUrl'] as String?)?.trim();
    final quic = _firstNonEmpty([
      envQuicUrl,
      json['defaultQuicUrl'],
      json['quicUrl'],
    ]);
    final tlsCaCertPath = _firstNonEmpty([
      envTlsCaCertPath,
      json['defaultTlsCaCertPath'],
      json['tlsCaCertPath'],
    ]);
    final tenant = (json['tenantId'] as String?)?.trim();
    final tokenSecret = _firstNonEmpty([
      envTokenSecret,
      json['devTokenSecret'],
      json['tokenSecret'],
    ]);
    final tokenIssuer = _firstNonEmpty([envTokenIssuer, json['tokenIssuer']]);
    final userId = (json['userId'] as String?)?.trim();
    final loginJson = json['login'] as Map<String, dynamic>?;
    return AppDefaults(
      defaultWsUrl: (ws != null && ws.isNotEmpty) ? ws : fallback.defaultWsUrl,
      defaultQuicUrl: quic ?? fallback.defaultQuicUrl,
      defaultTlsCaCertPath: tlsCaCertPath ?? fallback.defaultTlsCaCertPath,
      tenantId: (tenant != null && tenant.isNotEmpty)
          ? tenant
          : fallback.tenantId,
      devTokenSecret: tokenSecret ?? fallback.devTokenSecret,
      tokenIssuer: tokenIssuer ?? fallback.tokenIssuer,
      tokenTtlSecs: envTokenTtlSecs > 0
          ? envTokenTtlSecs
          : _positiveInt(json['tokenTtlSecs'], fallback.tokenTtlSecs),
      defaultUserId: (userId != null && userId.isNotEmpty)
          ? userId
          : fallback.defaultUserId,
      login: LoginCopy.fromJson(loginJson),
    );
  }
}

String? _firstNonEmpty(Iterable<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

int _positiveInt(Object? value, int fallback) {
  final parsed = switch (value) {
    final int v => v,
    final num v => v.toInt(),
    final String v => int.tryParse(v.trim()) ?? fallback,
    _ => fallback,
  };
  return parsed > 0 ? parsed : fallback;
}
