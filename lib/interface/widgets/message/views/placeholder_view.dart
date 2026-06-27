import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

// 占位消息。
class PlaceholderView extends StatelessWidget {
  final bool isSelf;
  final String? fallbackText;

  const PlaceholderView({super.key, required this.isSelf, this.fallbackText});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        fallbackText ?? '[占位]',
        style: const TextStyle(
          fontSize: 12,
          color: FlareThemeTokens.textTertiary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
