import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/infrastructure/media/network_image_policy.dart';
import 'package:flare_im/infrastructure/media/pack_asset_resolver.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

// 贴纸消息。
class StickerView extends StatelessWidget {
  final StickerContent sticker;
  final bool isSelf;

  const StickerView({super.key, required this.sticker, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    const maxSide = FlareImDesign.messageStickerLikeAssetMaxSide;
    double w = (sticker.width ?? 0) > 0 ? sticker.width!.toDouble() : 68;
    double h = (sticker.height ?? 0) > 0 ? sticker.height!.toDouble() : 68;
    if (w > maxSide || h > maxSide) {
      final scale = maxSide / (w > h ? w : h);
      w *= scale;
      h *= scale;
    }

    final assetPath = PackAssetResolver.stickerAssetPath(
      stickerId: sticker.stickerId,
      packageId: sticker.packageId,
    );
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        width: w,
        height: h,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _placeholder(w, h),
      );
    }

    final net = sticker.url?.trim() ?? '';
    if (isHttpOrHttpsUrl(net)) {
      return CachedNetworkImage(
        imageUrl: net,
        width: w,
        height: h,
        fit: BoxFit.contain,
        placeholder: (context, url) => SizedBox(
          width: w,
          height: h,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => _placeholder(w, h),
      );
    }

    return _placeholder(w, h);
  }

  Widget _placeholder(double w, double h) {
    return Container(
      width: w,
      height: h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FlareThemeTokens.bgHover,
        borderRadius: BorderRadius.circular(FlareThemeTokens.radiusLg),
        border: Border.all(color: FlareThemeTokens.borderPrimary),
      ),
      child: const Icon(
        Icons.insert_emoticon_outlined,
        size: 32,
        color: FlareThemeTokens.textSecondary,
      ),
    );
  }
}
