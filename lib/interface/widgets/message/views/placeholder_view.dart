import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 占位消息。
class PlaceholderView extends ConsumerWidget {
  final bool isSelf;
  final String? fallbackText;

  const PlaceholderView({super.key, required this.isSelf, this.fallbackText});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(flareMessagesProvider).chat;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        fallbackText ?? i18n.placeholderTag,
        style: const TextStyle(
          fontSize: 12,
          color: FlareThemeTokens.textTertiary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
