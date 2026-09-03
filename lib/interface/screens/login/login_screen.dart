import 'dart:async';

import 'package:flare_im/application/providers/im_outbound_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/domain/value_objects/transport_mode.dart';
import 'package:flare_im/infrastructure/paths/sdk_data_url.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/shared/config/app_config_loader.dart';
import 'package:flare_im/shared/config/app_defaults_model.dart';
import 'package:flare_im/shared/session/saved_session_store.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 登录页（设计稿：上紫渐变品牌区 + 下白表单区，品牌紫主按钮）
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _userIdController;
  late final TextEditingController _serverUrlController;
  late final TextEditingController _quicUrlController;
  late final TextEditingController _tlsCaCertPathController;
  /// 可选：直接填服务端签好的接入 token。
  ///
  /// 不填才回退到本地用 devTokenSecret 自签。留这个口子是因为把**签名密钥**放进
  /// 客户端等于让任何拿到安装包的人都能伪造任意用户身份 —— 仓库自己的
  /// mint_token.py 也是这么写的：密钥留在服务器，只把签好的 token 发出去。
  /// web 端一直有这个输入框，原生端没有，于是只能连"自己握有密钥"的服务器。
  late final TextEditingController _accessTokenController;
  late final TextEditingController _tokenSecretController;

  AppDefaults _defaults = AppDefaults.fallback;
  SdkTransportMode _transportMode = SdkTransportMode.websocket;
  bool _isLoading = false;
  String? _errorMessage;
  String? _loginStage;
  @override
  void initState() {
    super.initState();
    _userIdController = TextEditingController();
    _serverUrlController = TextEditingController(
      text: AppDefaults.fallback.defaultWsUrl,
    );
    _quicUrlController = TextEditingController(
      text: AppDefaults.fallback.defaultQuicUrl,
    );
    _accessTokenController = TextEditingController();
    _tokenSecretController = TextEditingController();
    _tlsCaCertPathController = TextEditingController(
      text: AppDefaults.fallback.defaultTlsCaCertPath,
    );
    unawaited(_bootstrapConfig());
  }

  Future<void> _bootstrapConfig() async {
    final d = await AppConfigLoader.load();
    if (!mounted) return;
    setState(() {
      _defaults = d;
      _serverUrlController.text = d.defaultWsUrl;
      _quicUrlController.text = d.defaultQuicUrl;
      _tlsCaCertPathController.text = d.defaultTlsCaCertPath;
      if (_userIdController.text.trim().isEmpty) {
        _userIdController.text = d.defaultUserId;
      }
    });
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _serverUrlController.dispose();
    _quicUrlController.dispose();
    _tlsCaCertPathController.dispose();
    _accessTokenController.dispose();
    _tokenSecretController.dispose();
    super.dispose();
  }

  String get _effectiveWsUrl {
    final t = _serverUrlController.text.trim();
    return t.isNotEmpty ? t : _defaults.defaultWsUrl;
  }

  String get _effectiveQuicUrl {
    final t = _quicUrlController.text.trim();
    return t.isNotEmpty ? t : _defaults.defaultQuicUrl;
  }

  String get _effectiveTlsCaCertPath {
    final t = _tlsCaCertPathController.text.trim();
    return t.isNotEmpty ? t : _defaults.defaultTlsCaCertPath;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loginStage = '正在准备 SDK 运行环境';
    });

    try {
      final wsUrl = _effectiveWsUrl;
      final im = ref.read(imOutboundProvider);
      final dataUrl = await resolveSdkDataUrl();
      if (mounted) {
        setState(() => _loginStage = '正在初始化 SDK 和本地数据库');
      }
      // 高级区填了现成的接入 token 就直接用，不需要本地持有签名密钥。
      final pastedToken = _accessTokenController.text.trim();
      // 密钥优先取运行时填的那个。做成输入而不是只读构建期常量：
      // 打进安装包等于让任何拿到它的人伪造任意用户身份；填在这里只落在本机。
      final typedSecret = _tokenSecretController.text.trim();
      final effectiveSecret =
          typedSecret.isNotEmpty ? typedSecret : _defaults.devTokenSecret;
      // 占位密钥签出来的 token 服务端一律验不过。与其让用户拿着一个「登录失败」
      // 去猜网络/账号哪里错了，不如在这里说清楚缺的是什么、去哪里拿。
      if (pastedToken.isEmpty && typedSecret.isEmpty && !_defaults.hasUsableTokenSecret) {
        throw StateError(
          '既没有填「接入 token」，也没有填「签名密钥」：'
          'assets/config/app_defaults.json 里的 devTokenSecret 仍是占位值。'
          '推荐用前者——签名密钥留在服务器上，客户端只拿签好的 token；'
          '要本地自签则填入 flare-im-core/logs/.dev-token-secret 的内容，'
          '或以 --dart-define=FLARE_TOKEN_SECRET=... 启动。',
        );
      }
      await im.authEnsureSdkInitialized(
        wsUrl: wsUrl,
        transportMode: _transportMode,
        quicUrl: _effectiveQuicUrl,
        tenantId: _defaults.tenantId,
        tokenSecret: effectiveSecret,
        tokenIssuer: _defaults.tokenIssuer,
        tokenTtlSecs: _defaults.tokenTtlSecs,
        tlsCaCertPath: _effectiveTlsCaCertPath,
        dataUrl: dataUrl,
      );

      final userId = _userIdController.text.trim();
      if (mounted) {
        setState(() => _loginStage = '正在生成登录凭证');
      }
      final token = pastedToken.isNotEmpty
          ? pastedToken
          : await im.authGenerateCoreToken(
              userId,
              expireSeconds: _defaults.tokenTtlSecs,
            );
      if (mounted) {
        setState(() => _loginStage = '正在登录并建立实时连接');
      }
      await im.authLogin(userId, token);
      await SavedSessionStore.save(
        SavedSessionProfile(
          userId: userId,
          wsUrl: wsUrl,
          transportMode: _transportMode,
          quicUrl: _effectiveQuicUrl,
          tlsCaCertPath: _effectiveTlsCaCertPath,
        ),
      );

      if (mounted) {
        context.go('/conversations');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loginStage = null;
        });
      }
    }
  }

  double _headerHeight(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return (h * 0.34).clamp(220.0, 300.0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(flareMessagesProvider).login;
    final tt = Theme.of(context).textTheme;

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: const BorderSide(color: FlareImDesign.loginInputBorder),
    );

    return Scaffold(
      backgroundColor: FlareImDesign.loginCanvas,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _headerHeight(context),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FlareImDesign.loginGradientTop,
                    FlareImDesign.loginGradientBottom,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FlareThemeTokens.spacing2xl,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: FlareImDesign.loginLogoBg,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 36,
                          color: FlareImDesign.loginLogoAccent,
                        ),
                      ),
                      const SizedBox(height: FlareThemeTokens.spacingLg),
                      Text(
                        l10n.brandTitle,
                        textAlign: TextAlign.center,
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: FlareImDesign.loginHeaderOnGradient,
                          letterSpacing: 0,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: FlareThemeTokens.spacingSm),
                      Text(
                        l10n.brandSubtitle,
                        textAlign: TextAlign.center,
                        style: tt.bodyMedium?.copyWith(
                          color: FlareImDesign.loginHeaderSlogan,
                          height: 1.45,
                          fontWeight: FontWeight.w400,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.welcomeTitle,
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: FlareImDesign.loginTitle,
                        fontSize: 26,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.welcomeSubtitle,
                      style: tt.bodyMedium?.copyWith(
                        color: FlareImDesign.loginSubtitle,
                        height: 1.45,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      l10n.userIdLabel,
                      style: tt.titleSmall?.copyWith(
                        color: FlareImDesign.loginTitle,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _userIdController,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleLogin(),
                      style: const TextStyle(
                        fontSize: 16,
                        color: FlareImDesign.loginTitle,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.userIdPlaceholder,
                        hintStyle: const TextStyle(
                          color: FlareImDesign.loginHint,
                          fontSize: 15,
                        ),
                        filled: true,
                        fillColor: FlareImDesign.loginInputFill,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          color: FlareImDesign.loginSubtitle,
                          size: 22,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(
                            color: FlareThemeTokens.primary,
                            width: 1.5,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide(
                            color: FlareImDesign.destructive.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide(
                            color: FlareImDesign.destructive.withValues(
                              alpha: 0.95,
                            ),
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.userIdRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: FlareImDesign.loginInfoIconTint,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.userIdHint,
                            style: tt.bodySmall?.copyWith(
                              color: FlareImDesign.loginSubtitle,
                              height: 1.45,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '连接协议',
                      style: tt.titleSmall?.copyWith(
                        color: FlareImDesign.loginTitle,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<SdkTransportMode>(
                      segments: const [
                        ButtonSegment(
                          value: SdkTransportMode.websocket,
                          label: Text(
                            'WebSocket',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                          ),
                        ),
                        ButtonSegment(
                          value: SdkTransportMode.quic,
                          label: Text('QUIC', maxLines: 1),
                        ),
                        ButtonSegment(
                          value: SdkTransportMode.race,
                          label: Text('竞速', maxLines: 1),
                        ),
                      ],
                      style: SegmentedButton.styleFrom(
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: {_transportMode},
                      showSelectedIcon: false,
                      onSelectionChanged: (next) {
                        setState(() => _transportMode = next.first);
                      },
                    ),
                    Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          l10n.serverToggle,
                          style: tt.bodySmall?.copyWith(
                            color: FlareImDesign.loginSubtitle,
                          ),
                        ),
                        children: [
                          TextFormField(
                            controller: _serverUrlController,
                            validator: (value) {
                              final raw = value?.trim() ?? '';
                              if (raw.isEmpty) return null;
                              final uri = Uri.tryParse(raw);
                              if (uri == null ||
                                  (uri.scheme != 'ws' && uri.scheme != 'wss') ||
                                  uri.host.isEmpty ||
                                  uri.path != '/ws') {
                                return l10n.wsUrlInvalid;
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              hintText: _defaults.defaultWsUrl,
                              hintStyle: const TextStyle(
                                color: FlareImDesign.loginHint,
                                fontSize: 13,
                              ),
                              labelText: l10n.wsUrlLabel,
                              filled: true,
                              fillColor: FlareImDesign.loginInputFill,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: FlareImDesign.loginInputBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: FlareImDesign.loginInputBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: FlareThemeTokens.primary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          if (_transportMode != SdkTransportMode.websocket) ...[
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _quicUrlController,
                              validator: (value) {
                                if (_transportMode ==
                                    SdkTransportMode.websocket) {
                                  return null;
                                }
                                final typed = value?.trim() ?? '';
                                final raw = typed.isNotEmpty
                                    ? typed
                                    : _defaults.defaultQuicUrl;
                                final uri = Uri.tryParse(raw);
                                if (uri == null ||
                                    uri.scheme != 'quic' ||
                                    uri.host.isEmpty) {
                                  return '请输入有效的 QUIC URL';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: _defaults.defaultQuicUrl,
                                hintStyle: const TextStyle(
                                  color: FlareImDesign.loginHint,
                                  fontSize: 13,
                                ),
                                labelText: 'QUIC URL',
                                filled: true,
                                fillColor: FlareImDesign.loginInputFill,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: FlareImDesign.loginInputBorder,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: FlareImDesign.loginInputBorder,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: FlareThemeTokens.primary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                                                        // 可选：直接填服务端签好的接入 token。填了就不需要本地持有签名密钥 ——
                            // 把密钥放进客户端等于让任何拿到安装包的人都能伪造任意用户身份。
                            TextFormField(
                              controller: _accessTokenController,
                              decoration: InputDecoration(
                                hintText:
                                    '留空则用本地 devTokenSecret 自签',
                                hintStyle: const TextStyle(
                                  color: FlareImDesign.loginHint,
                                  fontSize: 13,
                                ),
                                labelText: '接入 token（可选）',
                                filled: true,
                                fillColor: FlareImDesign.loginInputFill,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: FlareImDesign.loginInputBorder,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: FlareImDesign.loginInputBorder,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: FlareThemeTokens.primary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // 运行时填入服务端的签名密钥，之后只输入 user id 即可登录。
                            // 做成输入而不是打进安装包：打进去等于让任何拿到安装包的人
                            // 伪造任意用户身份；填在这里只落在本机。
                            TextFormField(
                              controller: _tokenSecretController,
                              decoration: InputDecoration(
                                hintText:
                                    '服务端的签名密钥 —— 用它按用户 ID 在本地签发',
                                hintStyle: const TextStyle(
                                  color: FlareImDesign.loginHint,
                                  fontSize: 13,
                                ),
                                labelText: '签名密钥（可选）',
                                filled: true,
                                fillColor: FlareImDesign.loginInputFill,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: FlareImDesign.loginInputBorder,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: FlareImDesign.loginInputBorder,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: FlareThemeTokens.primary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            TextFormField(
                              controller: _tlsCaCertPathController,
                              decoration: InputDecoration(
                                hintText:
                                    '/path/to/flare-im-core/certs/server.crt',
                                hintStyle: const TextStyle(
                                  color: FlareImDesign.loginHint,
                                  fontSize: 13,
                                ),
                                labelText: 'TLS CA 证书路径',
                                filled: true,
                                fillColor: FlareImDesign.loginInputFill,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: FlareImDesign.loginInputBorder,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: FlareImDesign.loginInputBorder,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: FlareThemeTokens.primary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            l10n.advancedWsHint,
                            style: tt.bodySmall?.copyWith(
                              color: FlareImDesign.loginHint,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: FlareThemeTokens.spacingMd),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: FlareImDesign.destructive.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: FlareImDesign.destructive.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: FlareImDesign.destructive,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: FlareImDesign.destructive,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: FlareThemeTokens.spacingXl),
                    if (_isLoading && _loginStage != null) ...[
                      Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: FlareImDesign.brandPurple,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _loginStage!,
                              style: tt.bodySmall?.copyWith(
                                color: FlareImDesign.loginSubtitle,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: FlareThemeTokens.spacingMd),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: FilledButton.styleFrom(
                          backgroundColor: FlareImDesign.loginCtaBg,
                          foregroundColor: FlareImDesign.loginCtaFg,
                          disabledBackgroundColor: FlareImDesign.loginCtaBg
                              .withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: FlareImDesign.loginCtaFg.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.login_rounded,
                                    size: 22,
                                    color: FlareImDesign.loginCtaFg,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    l10n.loginButton,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: FlareThemeTokens.spacingLg),
                    Text(
                      l10n.footerPrimary,
                      textAlign: TextAlign.center,
                      style: tt.bodySmall?.copyWith(
                        color: FlareImDesign.loginSubtitle,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.footerSecondary,
                      textAlign: TextAlign.center,
                      style: tt.bodySmall?.copyWith(
                        color: FlareImDesign.loginHint,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
