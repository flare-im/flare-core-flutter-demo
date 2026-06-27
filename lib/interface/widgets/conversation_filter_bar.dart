import 'package:flare_im/application/providers/conversation_filter_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/domain/value_objects/conversation_filter.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/shared/i18n/flare_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 会话列表筛选条（与 Web `ConversationsPanel` filter chips 对齐）。
class ConversationFilterBar extends ConsumerWidget {
  const ConversationFilterBar({super.key, required this.onFilterChanged});

  final ValueChanged<ConversationFilter> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(conversationFilterProvider);
    final i18n = ref.watch(flareMessagesProvider);
    final options = _options(i18n);

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final item = options[index];
          final selected = item.filter == active;
          return FilterChip(
            label: Text(item.label),
            selected: selected,
            showCheckmark: false,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : FlareImDesign.foreground,
            ),
            backgroundColor: FlareImDesign.listHeaderIconCircleBg,
            selectedColor: FlareImDesign.brandPurple,
            side: BorderSide(
              color: selected ? FlareImDesign.brandPurple : Colors.transparent,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (_) {
              ref.read(conversationFilterProvider.notifier).state = item.filter;
              onFilterChanged(item.filter);
            },
          );
        },
      ),
    );
  }
}

final class _FilterOption {
  const _FilterOption({required this.filter, required this.label});
  final ConversationFilter filter;
  final String label;
}

List<_FilterOption> _options(FlareMessages i18n) {
  final c = i18n.conversation;
  return [
    _FilterOption(filter: ConversationFilter.all, label: c.filterAll),
    _FilterOption(filter: ConversationFilter.unread, label: c.filterUnread),
    _FilterOption(filter: ConversationFilter.mention, label: c.filterMention),
  ];
}
