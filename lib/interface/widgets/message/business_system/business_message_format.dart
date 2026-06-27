import 'package:flutter/material.dart';

// 任务状态展示（与业务侧常见英文 key 兼容）。
String formatTaskStatusLabel(String status) {
  final s = status.trim();
  if (s.isEmpty) return '状态未知';
  final lower = s.toLowerCase();
  const map = <String, String>{
    'todo': '待办',
    'pending': '待处理',
    'doing': '进行中',
    'in_progress': '进行中',
    'done': '已完成',
    'completed': '已完成',
    'closed': '已关闭',
    'cancelled': '已取消',
    'canceled': '已取消',
  };
  return map[lower] ?? s;
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
