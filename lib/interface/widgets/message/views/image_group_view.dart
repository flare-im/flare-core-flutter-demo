import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/infrastructure/media/network_image_policy.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/media_viewer/image_preview_modal.dart';
import 'package:flare_im/interface/widgets/message/message_style.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

/// 多图（相册）：九宫格布局，最多展示 9 格；超过 9 张时第 9 格上叠 `+N`。
///
/// 与常见 IM 一致：1 格单列，2 格双列，3–4 格 2×2，5–9 格 3 列；格间细分割线与底栏（张数 + 时间/状态）参照单图气泡。
class ImageGroupView extends StatelessWidget {
  static const int _maxCells = 9;
  static const double _maxBubbleWidth = 240;
  static const double _gap = 1;

  final bool isSelf;
  final List<String> imageUrls;
  final String? description;
  final MessageStatus? messageStatus;
  final String? footerTimeText;

  const ImageGroupView({
    super.key,
    required this.isSelf,
    this.imageUrls = const [],
    this.description,
    this.messageStatus,
    this.footerTimeText,
  });

  /// 列数：九宫格规则（最多 3 列）。
  static int _columnCount(int n) {
    if (n <= 1) return 1;
    if (n == 2) return 2;
    if (n <= 4) return 2;
    return 3;
  }

  static int _rowCount(int n, int cols) => (n + cols - 1) ~/ cols;

  static String _photoCountLabel(int total) {
    if (total <= 0) return '照片';
    return '$total张照片';
  }

  @override
  Widget build(BuildContext context) {
    final all = imageUrls
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (all.isEmpty) {
      return const Text(
        '[图片组]',
        style: TextStyle(fontSize: 13, color: FlareThemeTokens.textSecondary),
      );
    }

    final totalCount = all.length;
    final cells = all.take(_maxCells).toList();
    final n = cells.length;
    final cols = _columnCount(n);
    final rows = _rowCount(n, cols);
    final moreOnLast = totalCount > _maxCells ? totalCount - _maxCells : 0;

    final gapColor = _gridGapColor(context);
    final footerBg = _footerBarBackground(context);
    final footerFg = _footerBarForeground(context);
    final meta = _metaColor(context);
    final cap = description?.trim();
    final captionText = (cap != null && cap.isNotEmpty) ? cap : null;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxBubbleWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: MessageBubbleStyle.bubbleDecoration(
              context,
              isSelf: isSelf,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth.clamp(
                      120.0,
                      _maxBubbleWidth,
                    );
                    final inner = w - _gap * (cols - 1);
                    final side = inner / cols;
                    final gridH = side * rows + _gap * (rows - 1);

                    return ColoredBox(
                      color: gapColor,
                      child: SizedBox(
                        width: w,
                        height: gridH,
                        child: GridView.builder(
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                crossAxisSpacing: _gap,
                                mainAxisSpacing: _gap,
                                childAspectRatio: 1,
                              ),
                          itemCount: n,
                          itemBuilder: (context, i) {
                            final isLast = i == n - 1;
                            final showMore = isLast && moreOnLast > 0;
                            return _ImageGroupCell(
                              imageUrl: cells[i],
                              showMoreCount: showMore ? moreOnLast : 0,
                              onTap: () => ImagePreviewModal.show(
                                context,
                                imageUrl: cells[i],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  color: footerBg,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _photoCountLabel(totalCount),
                          style: TextStyle(
                            color: footerFg,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelf) ...[
                        if (footerTimeText != null &&
                            footerTimeText!.isNotEmpty) ...[
                          Text(
                            footerTimeText!,
                            style: TextStyle(
                              color: footerFg.withValues(alpha: 0.92),
                              fontSize: 12,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        _inlineStatus(
                          context,
                          meta: meta,
                          status: messageStatus,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (captionText != null) ...[
            const SizedBox(height: 6),
            Text(
              captionText,
              style: const TextStyle(
                fontSize: 12,
                color: FlareThemeTokens.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _gridGapColor(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (isSelf) {
      return dark
          ? Colors.white.withValues(alpha: 0.2)
          : Colors.white.withValues(alpha: 0.9);
    }
    return dark
        ? Colors.white.withValues(alpha: 0.08)
        : FlareThemeTokens.bgTertiary;
  }

  Color _footerBarBackground(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (isSelf) {
      return dark
          ? Colors.black.withValues(alpha: 0.22)
          : Colors.black.withValues(alpha: 0.14);
    }
    return dark
        ? Colors.white.withValues(alpha: 0.06)
        : FlareThemeTokens.bgTertiary;
  }

  Color _footerBarForeground(BuildContext context) {
    if (isSelf) {
      return MessageBubbleStyle.selfBubbleForeground(
        context,
      ).withValues(alpha: 0.95);
    }
    return MessageBubbleStyle.otherBubbleForeground(context);
  }

  Color _metaColor(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return FlareDarkThemeTokens.textSecondary.withValues(alpha: 0.95);
    }
    return isSelf
        ? FlareImDesign.messageBubbleSenderMeta
        : FlareImDesign.messageBubbleReceiverMeta;
  }

  Widget _inlineStatus(
    BuildContext context, {
    required Color meta,
    required MessageStatus? status,
  }) {
    final s = status;
    if (s == null) return const SizedBox.shrink();
    switch (s) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.2, color: meta),
        );
      case MessageStatus.sent:
      case MessageStatus.delivered:
        return Icon(Icons.check, size: 15, color: meta);
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 15, color: meta);
      case MessageStatus.failed:
        return const SizedBox.shrink();
    }
  }
}

class _ImageGroupCell extends StatelessWidget {
  final String imageUrl;
  final int showMoreCount;
  final VoidCallback onTap;

  const _ImageGroupCell({
    required this.imageUrl,
    required this.showMoreCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _cellImage(context, imageUrl),
          if (showMoreCount > 0)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.45),
              child: Center(
                child: Text(
                  '+$showMoreCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cellImage(BuildContext context, String url) {
    if (isLocalFileLikePath(url)) {
      final path = url.startsWith('file://')
          ? Uri.parse(url).toFilePath()
          : url;
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const ColoredBox(
          color: FlareThemeTokens.messageMediaPlaceholderBg,
          child: Icon(
            Icons.broken_image_outlined,
            color: FlareThemeTokens.textSecondary,
            size: 22,
          ),
        ),
      );
    }
    if (!isHttpOrHttpsUrl(url)) {
      return const ColoredBox(
        color: FlareThemeTokens.messageMediaPlaceholderBg,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: FlareThemeTokens.textTertiary,
          size: 20,
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) =>
          const ColoredBox(color: FlareThemeTokens.bgHover),
      errorWidget: (context, url, error) => const ColoredBox(
        color: FlareThemeTokens.messageMediaPlaceholderBg,
        child: Icon(
          Icons.broken_image_outlined,
          color: FlareThemeTokens.textSecondary,
          size: 22,
        ),
      ),
    );
  }
}
