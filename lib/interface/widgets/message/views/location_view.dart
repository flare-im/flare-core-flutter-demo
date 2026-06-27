import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/infrastructure/media/network_image_policy.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/message/message_style.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// 位置消息：地图预览、标题地址、气泡样式；送达态仅己方。
class LocationView extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? address;
  final String? title;
  final int? zoom;
  final String? snapshotUrl;
  final String? snapshotLocalPath;
  final bool isSelf;
  final MessageStatus? messageStatus;

  const LocationView({
    super.key,
    required this.latitude,
    required this.longitude,
    this.address,
    this.title,
    this.zoom,
    this.snapshotUrl,
    this.snapshotLocalPath,
    required this.isSelf,
    this.messageStatus,
  });

  static const double _mapHeight = 120;

  // 无 snapshotUrl 时用 OSM 静态图。
  static String? _staticMapUrl(double lat, double lon, int? zoom) {
    if (!lat.isFinite || !lon.isFinite) return null;
    if (lat == 0 && lon == 0) return null;
    const w = 640;
    const mapH = 240;
    final z = (zoom ?? 16).clamp(1, 18);
    final center = '$lat,$lon';
    return 'https://staticmap.openstreetmap.de/staticmap.php?center=${Uri.encodeComponent(center)}&zoom=$z&size=${w}x$mapH';
  }

  /// 国内使用高德地图 [Web URI](https://lbs.amap.com/api/uri-api/guide/mobile-web/marker)：
  /// `uri.amap.com` 在移动端常可唤起高德 App；无坐标时用关键词搜索。
  ///
  /// [position] 为「经度,纬度」。若业务侧坐标为 WGS84，可追加 `coordinate: 'wgs84'`。
  Uri? _launchMapUri() {
    final t = title?.trim();
    final addr = address?.trim();
    final hasValidCoords =
        latitude.isFinite &&
        longitude.isFinite &&
        !(latitude == 0 && longitude == 0);

    if (hasValidCoords) {
      final name = (t != null && t.isNotEmpty)
          ? t
          : (addr != null && addr.isNotEmpty)
          ? addr
          : '位置';
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        return Uri.parse(
          'geo:$latitude,$longitude?q=${Uri.encodeComponent('$latitude,$longitude($name)')}',
        );
      }
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        return Uri(
          scheme: 'https',
          host: 'maps.apple.com',
          path: '/',
          queryParameters: <String, String>{
            'll': '$latitude,$longitude',
            'q': name,
          },
        );
      }
      return Uri(
        scheme: 'https',
        host: 'maps.google.com',
        path: '/',
        queryParameters: <String, String>{'q': '$latitude,$longitude'},
      );
    }

    final query = (t != null && t.isNotEmpty)
        ? t
        : (addr != null && addr.isNotEmpty)
        ? addr
        : null;
    if (query == null) return null;
    return Uri(
      scheme: 'https',
      host: 'uri.amap.com',
      path: '/search',
      queryParameters: <String, String>{'keyword': query},
    );
  }

  Future<void> _openMap(BuildContext context) async {
    final uri = _launchMapUri();
    if (uri == null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('无法打开地图')));
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('无法打开地图')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = title?.trim();
    final addr = address?.trim();
    final titleText = (t != null && t.isNotEmpty)
        ? t
        : (addr != null && addr.isNotEmpty)
        ? addr
        : '位置';
    final subtitleText =
        (t != null && t.isNotEmpty && addr != null && addr.isNotEmpty)
        ? addr
        : '';

    final snap = snapshotUrl?.trim();
    final localSnap = snapshotLocalPath?.trim();
    final hasLocalSnapshot =
        !kIsWeb &&
        localSnap != null &&
        localSnap.isNotEmpty &&
        File(localSnap).existsSync();
    final hasValidCoords =
        latitude.isFinite &&
        longitude.isFinite &&
        !(latitude == 0 && longitude == 0);
    final mapUrl = (snap != null && snap.isNotEmpty && isHttpOrHttpsUrl(snap))
        ? snap
        : (hasValidCoords ? _staticMapUrl(latitude, longitude, zoom) : null);
    final showPin =
        !hasLocalSnapshot &&
        (snap == null || snap.isEmpty) &&
        hasValidCoords &&
        mapUrl != null;

    final light = Theme.of(context).brightness == Brightness.light;
    final readIconColor = light
        ? FlareImDesign.messageBubbleSenderFill
        : FlareThemeTokens.primary;

    final infoBg = _infoStripBackground(context);
    final titleColor = _infoTitleColor(context);
    const subtitleColor = FlareThemeTokens.textSecondary;

    return LayoutBuilder(
      builder: (context, constraints) {
        const fixedW = FlareImDesign.messageLocationCardFixedWidth;
        final maxAllowed =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : fixedW;
        final cardW = math.min(fixedW, maxAllowed);
        final bubbleR = MessageBubbleStyle.bubbleRadius(context);

        return SizedBox(
          width: cardW,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(bubbleR),
              onTap: () => _openMap(context),
              child: Ink(
                decoration: MessageBubbleStyle.bubbleDecoration(
                  context,
                  isSelf: isSelf,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(bubbleR),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: _mapHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (hasLocalSnapshot)
                              Image.file(
                                File(localSnap),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: FlareThemeTokens
                                          .messageMediaPlaceholderBg,
                                      child: const Icon(
                                        Icons.map_outlined,
                                        size: 40,
                                        color: FlareThemeTokens.textSecondary,
                                      ),
                                    ),
                              )
                            else if (mapUrl != null)
                              CachedNetworkImage(
                                imageUrl: mapUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: FlareThemeTokens
                                      .messageMediaPlaceholderBg,
                                  child: const Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: FlareThemeTokens
                                      .messageMediaPlaceholderBg,
                                  child: const Icon(
                                    Icons.map_outlined,
                                    size: 40,
                                    color: FlareThemeTokens.textSecondary,
                                  ),
                                ),
                              )
                            else
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      FlareThemeTokens.bgTertiary,
                                      FlareThemeTokens
                                          .messageMediaPlaceholderBg,
                                    ],
                                  ),
                                ),
                              ),
                            if (showPin)
                              const Center(
                                child: Icon(
                                  Icons.location_on,
                                  size: 36,
                                  color: FlareThemeTokens.error,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 4,
                                      color: Color(0x40000000),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        color: infoBg,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    titleText,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                      color: titleColor,
                                    ),
                                  ),
                                  if (subtitleText.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      subtitleText,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isSelf && messageStatus != null) ...[
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: _statusIcon(
                                  messageStatus!,
                                  readIconColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _infoStripBackground(BuildContext context) {
    if (isSelf) {
      return Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.white;
    }
    return Colors.transparent;
  }

  Color _infoTitleColor(BuildContext context) {
    if (isSelf) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      return dark ? FlareThemeTokens.textPrimary : FlareThemeTokens.textPrimary;
    }
    return MessageBubbleStyle.otherBubbleForeground(context);
  }

  Widget _statusIcon(MessageStatus status, Color readColor) {
    switch (status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.4,
            color: FlareThemeTokens.textSecondary,
          ),
        );
      case MessageStatus.sent:
      case MessageStatus.delivered:
        return const Icon(
          Icons.check,
          size: 16,
          color: FlareThemeTokens.textSecondary,
        );
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 16, color: readColor);
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline,
          size: 16,
          color: FlareThemeTokens.error,
        );
    }
  }
}
