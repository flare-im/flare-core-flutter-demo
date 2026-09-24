import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_im/infrastructure/media/network_image_policy.dart';
import 'package:flare_im_ui/flare_im_ui.dart';
import 'package:flutter/material.dart';

/// Thin platform-image adapter for the design kit's full-screen preview.
abstract final class ImagePreviewModal {
  static Future<void> show(
    BuildContext context, {
    required String imageUrl,
  }) async {
    if (!isHttpOrHttpsUrl(imageUrl) && !isLocalFileLikePath(imageUrl)) return;
    await FlareImagePreview.present(
      context,
      imageSrc: imageUrl,
      imageBuilder: (context, source) {
        if (isHttpOrHttpsUrl(source)) {
          return CachedNetworkImage(
            imageUrl: source,
            fit: BoxFit.contain,
            errorWidget: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white,
              size: 48,
            ),
          );
        }
        final path = source.startsWith('file://')
            ? Uri.parse(source).toFilePath()
            : source;
        return Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(
            Icons.broken_image_outlined,
            color: Colors.white,
            size: 48,
          ),
        );
      },
    );
  }
}
