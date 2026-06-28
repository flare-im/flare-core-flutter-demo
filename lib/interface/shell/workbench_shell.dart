import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/application/providers/workbench_ui_provider.dart';
import 'package:flare_im/interface/screens/conversation_list/conversation_list_screen.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/conversation_details_panel.dart';
import 'package:flare_im/shared/layout/workbench_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 工作台外壳：宽屏三栏（列表 / 聊天 / 详情），窄屏仅展示路由子页。
class WorkbenchShell extends ConsumerWidget {
  const WorkbenchShell({super.key, required this.child});

  final Widget child;

  String? _chatIdFromLocation(String location) {
    const prefix = '/chat/';
    if (!location.startsWith(prefix)) return null;
    final rest = location.substring(prefix.length);
    final slash = rest.indexOf('/');
    final raw = slash < 0 ? rest : rest.substring(0, slash);
    if (raw.isEmpty) return null;
    try {
      return Uri.decodeComponent(raw);
    } on FormatException {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isWorkbenchWide(context)) {
      return child;
    }

    final location = GoRouterState.of(context).uri.path;
    final chatId = _chatIdFromLocation(location);
    final detailsOpen = ref.watch(workbenchDetailsOpenProvider);
    final i18n = ref.watch(flareMessagesProvider);
    final rawTextScale = MediaQuery.textScalerOf(context).scale(1);
    final emptyStateTextScaler = TextScaler.linear(
      rawTextScale.clamp(1.0, 1.25).toDouble(),
    );

    return Row(
      children: [
        const SizedBox(
          width: 360,
          child: ConversationListScreen(embedInWorkbench: true),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: chatId != null
              ? child
              : ColoredBox(
                  color: FlareImDesign.mobileCanvas,
                  child: Center(
                    child: MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: emptyStateTextScaler),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 56,
                                color: FlareImDesign.brandPurple.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                i18n.chat.selectTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                i18n.chat.selectHint,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: FlareImDesign.mutedForeground,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        if (detailsOpen && chatId != null) ...[
          const VerticalDivider(width: 1, thickness: 1),
          SizedBox(
            width: 320,
            child: ConversationDetailsPanel(
              conversationId: chatId,
              onClose: () =>
                  ref.read(workbenchDetailsOpenProvider.notifier).state = false,
            ),
          ),
        ],
      ],
    );
  }
}
