import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_im/infrastructure/media/network_image_policy.dart';
import 'package:flutter/material.dart';

// 图片全屏预览、缩放平移、关闭。
class ImagePreviewModal {
  ImagePreviewModal._();

  static Future<void> show(
    BuildContext context, {
    required String imageUrl,
  }) async {
    if (!isHttpOrHttpsUrl(imageUrl) && !isLocalFileLikePath(imageUrl)) return;
    final controller = TransformationController();
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (ctx, animation, secondaryAnimation) {
          return _ImagePreviewPage(
            imageUrl: imageUrl,
            transformationController: controller,
          );
        },
      ),
    );
  }
}

class _ImagePreviewPage extends StatefulWidget {
  final String imageUrl;
  final TransformationController transformationController;

  const _ImagePreviewPage({
    required this.imageUrl,
    required this.transformationController,
  });

  @override
  State<_ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<_ImagePreviewPage> {
  static const _minScale = 0.5;
  static const _maxScale = 4.0;

  Widget _imageBody() {
    if (isHttpOrHttpsUrl(widget.imageUrl)) {
      return CachedNetworkImage(
        imageUrl: widget.imageUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => const SizedBox(
          width: 120,
          height: 120,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        errorWidget: (context, url, error) => const Icon(
          Icons.broken_image_outlined,
          color: Colors.white,
          size: 48,
        ),
      );
    }
    final path = widget.imageUrl.startsWith('file://')
        ? Uri.parse(widget.imageUrl).toFilePath()
        : widget.imageUrl;
    return Image.file(
      File(path),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => const Icon(
        Icons.broken_image_outlined,
        color: Colors.white,
        size: 48,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: const ColoredBox(color: Colors.transparent),
          ),
          Center(
            child: InteractiveViewer(
              minScale: _minScale,
              maxScale: _maxScale,
              transformationController: widget.transformationController,
              clipBehavior: Clip.none,
              child: _imageBody(),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: '关闭',
                    ),
                    IconButton(
                      onPressed: () => widget.transformationController.value =
                          Matrix4.identity(),
                      icon: const Icon(Icons.fit_screen, color: Colors.white),
                      tooltip: '重置缩放',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
