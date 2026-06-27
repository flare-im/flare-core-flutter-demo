import 'package:flare_im/infrastructure/media/composer_pack_assets.dart';
import 'package:flare_im/infrastructure/media/emoji_pack_i18n.dart';
import 'package:flare_im/infrastructure/media/pack_asset_resolver.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

// 表情消息（`[key]` / key / Unicode）。
class EmojiView extends StatelessWidget {
  final String emoji;
  final bool isSelf;

  const EmojiView({super.key, required this.emoji, required this.isSelf});

  static final RegExp _bracketKey = RegExp(r'^\[([a-z][a-z0-9_]*)\]$');
  static final RegExp _bareKey = RegExp(r'^([a-z][a-z0-9_]*)$');

  String? _resolvePackKey(String raw) {
    final t = raw.trim();
    final b = _bracketKey.firstMatch(t);
    if (b != null) return b.group(1);
    final n = _bareKey.firstMatch(t);
    if (n != null) return n.group(1);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    final packKey = _resolvePackKey(emoji);

    if (packKey != null && ComposerPackAssets.hasEmojiWebp(packKey)) {
      const side = FlareImDesign.messageStickerLikeAssetMaxSide;
      return SizedBox(
        width: side,
        height: side,
        child: Image.asset(
          PackAssetResolver.emojiPackAssetPath(packKey),
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => Text(
            EmojiPackI18n.formatBracket(packKey, locale: locale),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: FlareThemeTokens.textSecondary,
            ),
          ),
        ),
      );
    }

    if (packKey != null) {
      return Text(
        EmojiPackI18n.formatBracket(packKey, locale: locale),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: FlareThemeTokens.textSecondary,
        ),
      );
    }

    return Text(emoji, style: const TextStyle(fontSize: 48));
  }
}
