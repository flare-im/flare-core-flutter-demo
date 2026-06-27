import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/message/business_system/business_message_format.dart';
import 'package:flare_im/interface/widgets/message/business_system/system_feature_bridge.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

// 分配任务卡片：顶栏 + 分隔线 + 标题与元数据行 + 底部「查看任务」（不展示 ID）。
class TaskView extends StatelessWidget {
  static const double _maxWidth = 320;
  static const double _radius = 12;
  static const double _accentW = 4;
  static const Color _accent = Color(0xFFFF9800);
  static const Color _deadlineColor = Color(0xFFE53935);
  static const Color _assigneeIconColor = Color(0xFFFFB74D);

  final String? taskId;
  final String? title;
  final String? detail;
  final Map<String, String> metadata;
  final List<String> participantUserIds;

  const TaskView({
    super.key,
    this.taskId,
    this.title,
    this.detail,
    this.metadata = const {},
    this.participantUserIds = const [],
  });

  @override
  Widget build(BuildContext context) {
    final headline = (title ?? '').trim().isNotEmpty ? title!.trim() : '任务';
    final rawStatus = (detail ?? '').trim();
    final statusLabel = formatTaskStatusLabel(rawStatus);
    final pill = taskStatusPillVariant(rawStatus);
    final pillColors = taskStatusPillColors(pill);
    final participantLine = participantUserIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join('、');
    final deadline = _pickMeta(metadata, const [
      'deadline',
      'due_date',
      'due',
      'end_date',
      '截止',
    ]);
    final assignee = _pickMeta(metadata, const [
      'assignee',
      'assigned_to',
      'assignee_name',
      'executor',
      'assignee_display',
      '指派',
    ]);
    final hasTaskId = taskId != null && taskId!.isNotEmpty;
    final metaEntries = metadata.entries
        .where((e) => e.key.trim().isNotEmpty)
        .where((e) => !_isStructuralMetaKey(e.key))
        .toList();

    return Semantics(
      label: '任务：$headline',
      button: hasTaskId,
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
                                Icons.check_box_rounded,
                                size: 22,
                                color: _accent,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '分配任务',
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
                            headline,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                              color: Color(0xFF111827),
                            ),
                          ),
                          if (deadline != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 18,
                                  color: _deadlineColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '截止：$deadline',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _deadlineColor,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (assignee != null) ...[
                            SizedBox(height: deadline != null ? 8 : 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.person_outline_rounded,
                                  size: 18,
                                  color: _assigneeIconColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '指派给：$assignee',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      height: 1.3,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              const Text(
                                '状态',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: FlareThemeTokens.textTertiary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: pillColors.bg,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: pillColors.border),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                    color: pillColors.fg,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                              onPressed: hasTaskId
                                  ? () => openSystemFeature(taskId)
                                  : null,
                              style: TextButton.styleFrom(
                                foregroundColor: _accent,
                                backgroundColor: _accent.withValues(
                                  alpha: 0.12,
                                ),
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
                                '查看任务',
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

  static String? _pickMeta(Map<String, String> meta, List<String> keys) {
    for (final k in keys) {
      final v = meta[k]?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  static bool _isStructuralMetaKey(String k) {
    const keys = {
      'deadline',
      'due_date',
      'due',
      'end_date',
      '截止',
      'assignee',
      'assigned_to',
      'assignee_name',
      'executor',
      'assignee_display',
      '指派',
    };
    return keys.contains(k);
  }
}
