import 'package:flare_im/shared/i18n/flare_messages.dart';
import 'package:flutter/material.dart';

// 任务状态展示（与业务侧常见英文 key 兼容）；文案走 [FlareChatCopy]（中英双语）。
String formatTaskStatusLabel(String status, FlareChatCopy i18n) {
  final s = status.trim();
  if (s.isEmpty) return i18n.statusUnknown;
  switch (s.toLowerCase()) {
    case 'todo':
      return i18n.statusTodo;
    case 'pending':
      return i18n.statusPending;
    case 'doing':
    case 'in_progress':
      return i18n.statusInProgress;
    case 'done':
    case 'completed':
      return i18n.statusDone;
    case 'closed':
      return i18n.statusClosed;
    case 'cancelled':
    case 'canceled':
      return i18n.statusCancelled;
    default:
      return s;
  }
}

// 任务状态胶囊样式分支。
enum TaskStatusPillVariant { neutral, todo, doing, done }

TaskStatusPillVariant taskStatusPillVariant(String status) {
  final s = status.trim().toLowerCase();
  if (RegExp(r'done|completed|closed').hasMatch(s)) {
    return TaskStatusPillVariant.done;
  }
  if (RegExp(r'todo|pending').hasMatch(s)) {
    return TaskStatusPillVariant.todo;
  }
  if (RegExp(r'doing|progress|in_progress').hasMatch(s)) {
    return TaskStatusPillVariant.doing;
  }
  return TaskStatusPillVariant.neutral;
}

({Color fg, Color bg, Color border}) taskStatusPillColors(
  TaskStatusPillVariant v,
) {
  switch (v) {
    case TaskStatusPillVariant.todo:
      return (
        fg: const Color(0xFF165DFF),
        bg: const Color(0x1A165DFF),
        border: const Color(0x40165DFF),
      );
    case TaskStatusPillVariant.doing:
      return (
        fg: const Color(0xFFD46B08),
        bg: const Color(0x1AD46B08),
        border: const Color(0x47D46B08),
      );
    case TaskStatusPillVariant.done:
      return (
        fg: const Color(0xFF00B42A),
        bg: const Color(0x1A00B42A),
        border: const Color(0x4700B42A),
      );
    case TaskStatusPillVariant.neutral:
      return (
        fg: const Color(0xFF4E5969),
        bg: const Color(0xFFF2F3F5),
        border: const Color(0xFFE5E6EB),
      );
  }
}
