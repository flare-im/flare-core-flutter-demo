import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/interface/widgets/composer/composer_models.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 引用回复顶条。
class ComposerReplyStrip extends ConsumerWidget {
  final ComposerReplyQuote quote;
  final VoidCallback? onClear;
  final bool previewWarn;

  const ComposerReplyStrip({
    super.key,
    required this.quote,
    required this.onClear,
    required this.previewWarn,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(flareMessagesProvider).composer;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: FlareThemeTokens.composerReplyStripBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: FlareThemeTokens.composerReplyStripBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 20),
                color: FlareThemeTokens.composerReplyStripClose,
                tooltip: c.cancelReply,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Container(
                width: 1,
                height: 16,
                color: FlareThemeTokens.composerReplyStripSep,
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: Text(
                  c.replyTo(quote.senderName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: FlareThemeTokens.composerReplyStripLabel,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    if (previewWarn)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: FlareThemeTokens.conversationListQuoteWarning,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        quote.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: FlareThemeTokens.composerReplyStripPreview,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
