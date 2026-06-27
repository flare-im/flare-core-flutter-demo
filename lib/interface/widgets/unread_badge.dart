import 'package:flare_im/application/providers/im_sync_state_provider.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 角标：只监听未读总数（`select`），会话列表大刷新时也不重复重建整树。
class UnreadBadge extends ConsumerWidget {
  const UnreadBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(unreadProvider.select((u) => u.total));
    if (total <= 0) return const SizedBox.shrink();

    final label = total > 99 ? '99+' : '$total';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: FlareImDesign.destructive,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
