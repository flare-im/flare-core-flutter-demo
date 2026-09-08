import 'package:flare_im/application/providers/app_theme_mode_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/shared/i18n/flare_locale.dart';
import 'package:flare_im_ui/flare_im_ui.dart'
    show
        FlareSettingKind,
        FlareSettingsItem,
        FlareSettingsList,
        FlareSettingsSection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 设置屏：语言 + 外观,飞书式 kit 列表(单选行由 kit FlareSettingsList 承载)。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(flareMessagesProvider);
    final settings = i18n.settings;
    final locale = ref.watch(flareLocaleProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    final sections = [
      FlareSettingsSection(
        title: settings.language,
        items: [
          FlareSettingsItem(
            key: 'lang_zh',
            label: i18n.conversation.languageZh,
            kind: FlareSettingKind.select,
            value: locale == FlareLocale.zhCn,
          ),
          FlareSettingsItem(
            key: 'lang_en',
            label: i18n.conversation.languageEn,
            kind: FlareSettingKind.select,
            value: locale == FlareLocale.enUs,
          ),
        ],
      ),
      FlareSettingsSection(
        title: settings.appearance,
        items: [
          FlareSettingsItem(
            key: 'theme_system',
            label: settings.themeSystem,
            kind: FlareSettingKind.select,
            value: themeMode == ThemeMode.system,
          ),
          FlareSettingsItem(
            key: 'theme_light',
            label: settings.themeLight,
            kind: FlareSettingKind.select,
            value: themeMode == ThemeMode.light,
          ),
          FlareSettingsItem(
            key: 'theme_dark',
            label: settings.themeDark,
            kind: FlareSettingKind.select,
            value: themeMode == ThemeMode.dark,
          ),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: FlareImDesign.mobileCanvas,
      appBar: AppBar(
        title: Text(settings.title),
        backgroundColor: FlareImDesign.card,
        surfaceTintColor: Colors.transparent,
      ),
      body: FlareSettingsList(
        sections: sections,
        onSelect: (item) {
          switch (item.key) {
            case 'lang_zh':
              ref.read(flareLocaleProvider.notifier).setLocale(FlareLocale.zhCn);
            case 'lang_en':
              ref.read(flareLocaleProvider.notifier).setLocale(FlareLocale.enUs);
            case 'theme_system':
              ref.read(appThemeModeProvider.notifier).setMode(ThemeMode.system);
            case 'theme_light':
              ref.read(appThemeModeProvider.notifier).setMode(ThemeMode.light);
            case 'theme_dark':
              ref.read(appThemeModeProvider.notifier).setMode(ThemeMode.dark);
          }
        },
      ),
    );
  }
}
