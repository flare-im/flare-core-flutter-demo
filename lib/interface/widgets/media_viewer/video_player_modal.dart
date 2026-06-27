import 'dart:io';

import 'package:flare_im/infrastructure/media/network_image_policy.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// 视频全屏播放、静音、关闭。
class VideoPlayerModal {
  VideoPlayerModal._();

  static Future<void> show(
    BuildContext context, {
    required String videoUrl,
    String? posterUrl,
  }) async {
    if (!isHttpOrHttpsUrl(videoUrl) && !isLocalFileLikePath(videoUrl)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法播放：无效视频地址')));
      return;
    }
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (ctx, animation, secondaryAnimation) => _VideoPlayerPage(
          videoUrl: videoUrl,
          posterUrl: posterUrl != null && isHttpOrHttpsUrl(posterUrl)
              ? posterUrl
              : null,
        ),
      ),
    );
  }
}

class _VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String? posterUrl;

  const _VideoPlayerPage({required this.videoUrl, this.posterUrl});

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  late final VideoPlayerController _controller;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    final isLocal = isLocalFileLikePath(widget.videoUrl);
    final localPath = widget.videoUrl.startsWith('file://')
        ? Uri.parse(widget.videoUrl).toFilePath()
        : widget.videoUrl;
    _controller =
        isLocal
              ? VideoPlayerController.file(File(localPath))
              : VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
          ..initialize().then((_) {
            if (mounted) setState(() {});
          })
          ..setLooping(false)
          ..addListener(() {
            if (mounted) setState(() {});
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
                const Expanded(
                  child: Text(
                    '视频',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _muted = !_muted;
                      _controller.setVolume(_muted ? 0 : 1);
                    });
                  },
                  icon: Icon(
                    _muted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: _controller.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      )
                    : const CircularProgressIndicator(
                        color: FlareThemeTokens.primary,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      if (_controller.value.isPlaying) {
                        _controller.pause();
                      } else {
                        _controller.play();
                      }
                      setState(() {});
                    },
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    label: Text(_controller.value.isPlaying ? '暂停' : '播放'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
