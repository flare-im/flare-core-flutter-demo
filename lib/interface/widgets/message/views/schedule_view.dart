import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/message/business_system/system_feature_bridge.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

// 日程提醒卡片：顶栏 + 分隔线 + 时间与地点行 + 底部「查看日程」（不展示 ID）。
class ScheduleView extends StatelessWidget {
  static const double _maxWidth = 320;
  static const double _radius = 12;
  static const double _accentW = 4;
  static const Color _accent = Color(0xFF7E57FF);

  final String? scheduleId;
  final String? title;
  final String? timeRange;
  final Map<String, String> metadata;
  final List<String> participantUserIds;

  const ScheduleView({
    super.key,
    this.scheduleId,
    this.title,
    this.timeRange,
    this.metadata = const {},
    this.participantUserIds = const [],
  });

  String? _pickMeta(List<String> keys) {
    for (final k in keys) {
      final v = metadata[k]?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  String? _locationLine() {
    return _pickMeta(const [
      'location',
      'place',
      'address',
      'meeting_link',
      'meeting_url',
      '会议',
      '会议链接',
    ]);
  }

  String? _rsvpLine() {
    return _pickMeta(const ['rsvp', 'acceptance', 'response', '参与状态']);
  }

  @override
  Widget build(BuildContext context) {
    final t = title ?? '日程';
    final participantLine = participantUserIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join('、');
    final location = _locationLine();
    final rsvp = _rsvpLine();
    final metaEntries = metadata.entries
        .where((e) => e.key.trim().isNotEmpty)
        .where((e) => !_isRedundantMetaKey(e.key))
        .toList();

    return Semantics(
      label: '日程：$t',
      button: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: FlareImDesign.messageBubbleReceiverBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: _accentW, color: _accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.calendar_month_rounded,
                                size: 22,
                                color: _accent,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '日程提醒',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937),
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: FlareThemeTokens.borderSecondary
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                          Text(
                            t,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                              color: Color(0xFF111827),
                            ),
                          ),
                          if (timeRange != null &&
                              timeRange!.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 18,
                                  color: _accent,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    timeRange!.trim(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      height: 1.35,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (location != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                  color: _accent,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    location,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      height: 1.35,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (participantLine.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              '参与人 · $participantLine',
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: Color(0xFF4E5969),
                              ),
                            ),
                          ],
                          if (rsvp != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              rsvp,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2E7D32),
                                height: 1.3,
                              ),
                            ),
                          ],
                          if (metaEntries.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Theme(
                              data: Theme.of(
                                context,
                              ).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: const Text(
                                  '业务参数',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: FlareThemeTokens.textSecondary,
                                  ),
                                ),
                                children: [
                                  for (final e in metaEntries)
                                    ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        e.key,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF8F959E),
                                        ),
                                      ),
                                      subtitle: Text(
                                        e.value,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF1D2129),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () => openSystemFeature(scheduleId),
                              style: TextButton.styleFrom(
                                foregroundColor: _accent,
                                backgroundColor: _accent.withValues(alpha: 0.1),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: _accent.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                              child: const Text(
                                '查看日程',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isRedundantMetaKey(String k) {
    const skip = {
      'location',
      'place',
      'address',
      'meeting_link',
      'meeting_url',
      '会议',
      '会议链接',
      'rsvp',
      'acceptance',
      'response',
      '参与状态',
    };
    return skip.contains(k);
  }
}
