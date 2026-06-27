import 'package:flare_im/application/providers/app_theme_mode_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/shared/i18n/flare_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(flareMessagesProvider);
    final settings = i18n.settings;
    final locale = ref.watch(flareLocaleProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    return Scaffold(
      backgroundColor: FlareImDesign.mobileCanvas,
      appBar: AppBar(
        title: Text(settings.title),
        backgroundColor: FlareImDesign.card,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            settings.language,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            title: i18n.conversation.languageZh,
            selected: locale == FlareLocale.zhCn,
            onTap: () => ref
                .read(flareLocaleProvider.notifier)
                .setLocale(FlareLocale.zhCn),
          ),
          _SettingsTile(
            title: i18n.conversation.languageEn,
            selected: locale == FlareLocale.enUs,
            onTap: () => ref
                .read(flareLocaleProvider.notifier)
                .setLocale(FlareLocale.enUs),
          ),
          const SizedBox(height: 24),
          Text(
            settings.appearance,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            title: settings.themeSystem,
            selected: themeMode == ThemeMode.system,
            onTap: () => ref
                .read(appThemeModeProvider.notifier)
                .setMode(ThemeMode.system),
          ),
          _SettingsTile(
            title: settings.themeLight,
            selected: themeMode == ThemeMode.light,
            onTap: () => ref
                .read(appThemeModeProvider.notifier)
                .setMode(ThemeMode.light),
          ),
          _SettingsTile(
            title: settings.themeDark,
            selected: themeMode == ThemeMode.dark,
            onTap: () =>
                ref.read(appThemeModeProvider.notifier).setMode(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          title: Text(
            title,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          trailing: selected
              ? const Icon(Icons.check_circle, color: FlareImDesign.brandPurple)
              : null,
          onTap: onTap,
        ),
      ),
    );
  }
}
