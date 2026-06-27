import 'package:flare_call_kit/flare_call_kit.dart';
import 'package:flare_im/application/providers/app_theme_mode_provider.dart';
import 'package:flare_im/application/providers/call_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/interface/router/app_router.dart';
import 'package:flare_im/interface/sdk_event_scope.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Flare IM 应用主组件
class FlareImApp extends ConsumerWidget {
  const FlareImApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final callEnabled = ref.watch(callKitEnabledProvider);
    final callController = ref.watch(callControllerProvider);
    final flareLocale = ref.watch(flareLocaleProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    return SdkEventScope(
      child: MaterialApp.router(
        title: 'Flare IM',
        themeMode: themeMode,
        locale: materialLocaleFor(flareLocale),
        supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: FlareImDesign.lightTheme(),
        darkTheme: FlareImDesign.darkTheme(),
        routerConfig: router,
        builder: (context, child) {
          final appChild = child ?? const SizedBox.shrink();
          if (!callEnabled || callController == null) {
            return appChild;
          }
          return FlareCallKitHost(controller: callController, child: appChild);
        },
      ),
    );
  }
}
