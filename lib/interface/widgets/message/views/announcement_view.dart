import 'package:flare_im/interface/widgets/message/business_system/system_feature_bridge.dart';
import 'package:flutter/material.dart';

// 群公告：浅黄底、喇叭标题、分隔线、正文、底栏发布者与时间。
class AnnouncementView extends StatelessWidget {
  static const double _maxWidth = 320;
  static const double _radius = 12;
  static const Color _cream = Color(0xFFFFF8E7);
  static const Color _accent = Color(0xFFC67C3B);
  static const Color _divider = Color(0xFFFFE0B2);
  static const Color _bodyFg = Color(0xFF5D4037);
  static const Color _footerMuted = Color(0xFF8D6E63);

  final String? announcementId;
  final String? headline;
  final String? body;
  final Map<String, String> metadata;
  final String? footerTimeText;

  const AnnouncementView({
    super.key,
    this.announcementId,
    this.headline,
    this.body,
    this.metadata = const {},
    this.footerTimeText,
  });

  String _publisherLine() {
    final fromMeta =
        metadata['publisher']?.trim() ??
        metadata['postedBy']?.trim() ??
        metadata['publisherLabel']?.trim() ??
        metadata['footerLeft']?.trim();
    if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
    return '群主 发布';
  }

  String _timeLine() {
    final fromMeta = metadata['postedTime']?.trim() ?? metadata['time']?.trim();
    if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
    final ext = footerTimeText?.trim();
    return ext ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final titleLine = (headline ?? '').trim();
    final b = (body ?? '').trim();
    final time = _timeLine();
    final ariaTitle = titleLine.isNotEmpty
        ? titleLine
        : (b.isNotEmpty ? b : '群公告');

    return Semantics(
      label: '公告：$ariaTitle',
      button: announcementId != null && announcementId!.isNotEmpty,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _cream,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: _divider.withValues(alpha: 0.95)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.campaign_outlined, size: 22, color: _accent),
                      SizedBox(width: 8),
                      Text(
                        '群公告',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _accent,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, thickness: 1, color: _divider),
                  ),
                  if (titleLine.isNotEmpty) ...[
                    Text(
                      titleLine,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        color: Color(0xFF3E2723),
                      ),
                    ),
                    if (b.isNotEmpty) const SizedBox(height: 8),
                  ],
                  if (b.isNotEmpty)
                    Text(
                      b,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.45,
                        color: _bodyFg,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          _publisherLine(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _accent,
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (time.isNotEmpty)
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: _footerMuted,
                            height: 1.2,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed:
                          announcementId != null && announcementId!.isNotEmpty
                          ? () => openSystemFeature(announcementId)
                          : null,
                      style: TextButton.styleFrom(
                        foregroundColor: _accent,
                        backgroundColor: _accent.withValues(alpha: 0.12),
                        disabledForegroundColor: _accent.withValues(
                          alpha: 0.45,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: _accent.withValues(alpha: 0.38),
                          ),
                        ),
                      ),
                      child: const Text(
                        '查看详情',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
