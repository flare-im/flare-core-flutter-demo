import 'dart:async';

import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/infrastructure/media/composer_pack_assets.dart';
import 'package:flare_im/infrastructure/media/composer_recent_emoji_store.dart';
import 'package:flare_im/interface/widgets/composer/composer_emoji_pack_thumb.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 用于剪贴板：文本消息用正文，其它类型用 [MessageContent.previewText]。
String? messageCopyPlainText(Message message) {
  if (message.isRecalled) return null;
  final c = message.content;
  if (c is TextContent) {
    final t = c.text.trim();
    return t.isEmpty ? null : c.text;
  }
  final p = c.previewText.trim();
  return p.isEmpty ? null : c.previewText;
}

/// SDK 在 [Message.extra] 中写入 `pinned`（字符串）。
bool messagePinnedFromExtra(Message message) {
  final v = message.extra['pinned'];
  if (v == null) return false;
  final s = v.trim().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes';
}

/// 删除消息：先选「仅自己」或「所有人」（己方消息可两者；他人消息仅自己）。
Future<void> showDeleteMessageChoiceDialog(
  BuildContext context, {
  Future<void> Function()? onDeleteForSelf,
  Future<void> Function()? onDeleteForEveryone,
  required bool showDeleteForEveryone,
}) async {
  final forEveryone = onDeleteForEveryone;
  final canEveryone = showDeleteForEveryone && forEveryone != null;
  if (onDeleteForSelf == null && !canEveryone) {
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('删除消息'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onDeleteForSelf != null)
            ListTile(
              leading: const Icon(
                Icons.visibility_off_outlined,
                color: Colors.orange,
              ),
              title: const Text('仅为自己删除'),
              subtitle: const Text('其它成员仍可见', style: TextStyle(fontSize: 12)),
              onTap: () async {
                Navigator.of(ctx).pop();
                await onDeleteForSelf();
              },
            ),
          if (canEveryone)
            ListTile(
              leading: const Icon(
                Icons.delete_forever_outlined,
                color: FlareThemeTokens.error,
              ),
              title: const Text('为所有人删除'),
              subtitle: const Text('从会话中移除该消息', style: TextStyle(fontSize: 12)),
              onTap: () async {
                Navigator.of(ctx).pop();
                await forEveryone();
              },
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ],
    ),
  );
}

/// 长按消息：上图样式 — 顶栏表情、第二排回复/转发/撤回、下方分组列表；删除走 [showDeleteMessageChoiceDialog]。
Future<void> showMessageLongPressMenu(
  BuildContext parentContext, {
  void Function(String emoji)? onPickReaction,
  VoidCallback? onReply,
  VoidCallback? onForward,
  VoidCallback? onRecall,
  VoidCallback? onMultiSelect,
  VoidCallback? onMark,
  VoidCallback? onPinToggle,
  VoidCallback? onPinForSelf,
  String pinLabel = '置顶消息',
  VoidCallback? onCopy,
  VoidCallback? onEdit,
  Future<void> Function()? onDeleteForSelf,
  Future<void> Function()? onDeleteForEveryone,
  bool showDeleteForEveryoneOption = false,
}) async {
  final hasReaction = onPickReaction != null;
  final hasQuick = onReply != null || onForward != null || onRecall != null;
  final hasGroupA = onMultiSelect != null || onMark != null;
  final hasPin = onPinToggle != null || onPinForSelf != null;
  final hasGroupB = onCopy != null || onEdit != null;
  final hasDelete =
      onDeleteForSelf != null ||
      (showDeleteForEveryoneOption && onDeleteForEveryone != null);

  if (!hasReaction &&
      !hasQuick &&
      !hasGroupA &&
      !hasPin &&
      !hasGroupB &&
      !hasDelete) {
    ScaffoldMessenger.maybeOf(
      parentContext,
    )?.showSnackBar(const SnackBar(content: Text('暂无可执行操作')));
    return;
  }

  await showModalBottomSheet<void>(
    context: parentContext,
    isScrollControlled: true,
    isDismissible: true,
    showDragHandle: false,
    barrierColor: Colors.transparent,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      final isDark = theme.brightness == Brightness.dark;
      final canvas = isDark
          ? theme.colorScheme.surfaceContainerHighest
          : const Color(0xFFF2F3F5);
      final card = isDark ? theme.colorScheme.surface : Colors.white;
      final onSurface = theme.colorScheme.onSurface;

      Future<void> closeThen(VoidCallback fn) async {
        Navigator.of(sheetCtx).pop();
        await Future<void>.delayed(Duration.zero);
        fn();
      }

      return Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(sheetCtx).pop(),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
            ),
          ),
          ColoredBox(
            color: canvas,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: SingleChildScrollView(
                  child: _MessageLongPressMenuPane(
                    sheetCtx: sheetCtx,
                    parentContext: parentContext,
                    closeThen: closeThen,
                    card: card,
                    onSurface: onSurface,
                    theme: theme,
                    isDark: isDark,
                    hasReaction: hasReaction,
                    hasQuick: hasQuick,
                    hasGroupA: hasGroupA,
                    hasPin: hasPin,
                    hasGroupB: hasGroupB,
                    hasDelete: hasDelete,
                    onPickReaction: onPickReaction,
                    onReply: onReply,
                    onForward: onForward,
                    onRecall: onRecall,
                    onMultiSelect: onMultiSelect,
                    onMark: onMark,
                    onPinToggle: onPinToggle,
                    onPinForSelf: onPinForSelf,
                    pinLabel: pinLabel,
                    onCopy: onCopy,
                    onEdit: onEdit,
                    onDeleteForSelf: onDeleteForSelf,
                    onDeleteForEveryone: onDeleteForEveryone,
                    showDeleteForEveryoneOption: showDeleteForEveryoneOption,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _MessageLongPressMenuPane extends StatefulWidget {
  const _MessageLongPressMenuPane({
    required this.sheetCtx,
    required this.parentContext,
    required this.closeThen,
    required this.card,
    required this.onSurface,
    required this.theme,
    required this.isDark,
    required this.hasReaction,
    required this.hasQuick,
    required this.hasGroupA,
    required this.hasPin,
    required this.hasGroupB,
    required this.hasDelete,
    this.onPickReaction,
    this.onReply,
    this.onForward,
    this.onRecall,
    this.onMultiSelect,
    this.onMark,
    this.onPinToggle,
    this.onPinForSelf,
    required this.pinLabel,
    this.onCopy,
    this.onEdit,
    this.onDeleteForSelf,
    this.onDeleteForEveryone,
    required this.showDeleteForEveryoneOption,
  });

  final BuildContext sheetCtx;
  final BuildContext parentContext;
  final Future<void> Function(VoidCallback fn) closeThen;
  final Color card;
  final Color onSurface;
  final ThemeData theme;
  final bool isDark;
  final bool hasReaction;
  final bool hasQuick;
  final bool hasGroupA;
  final bool hasPin;
  final bool hasGroupB;
  final bool hasDelete;
  final void Function(String reactionPayload)? onPickReaction;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onRecall;
  final VoidCallback? onMultiSelect;
  final VoidCallback? onMark;
  final VoidCallback? onPinToggle;
  final VoidCallback? onPinForSelf;
  final String pinLabel;
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;
  final Future<void> Function()? onDeleteForSelf;
  final Future<void> Function()? onDeleteForEveryone;
  final bool showDeleteForEveryoneOption;

  @override
  State<_MessageLongPressMenuPane> createState() =>
      _MessageLongPressMenuPaneState();
}

class _MessageLongPressMenuPaneState extends State<_MessageLongPressMenuPane> {
  bool _assetsReady = false;
  bool _emojiPickerOpen = false;

  @override
  void initState() {
    super.initState();
    unawaited(_ensureEmojiAssets());
  }

  Future<void> _ensureEmojiAssets() async {
    await ComposerPackAssets.ensureLoaded();
    if (mounted) setState(() => _assetsReady = true);
  }

  Future<void> _onPackKeyForReaction(String key) async {
    await ComposerRecentEmojiStore.record(key);
    if (!mounted) return;
    final bracket = '[$key]';
    widget.closeThen(() => widget.onPickReaction?.call(bracket));
  }

  void _toggleEmojiPicker() {
    setState(() => _emojiPickerOpen = !_emojiPickerOpen);
  }

  Widget _cardWrap({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: widget.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _withDividers(children),
      ),
    );
  }

  Widget _detachedQuickTile(VoidCallback? onTap, IconData icon, String label) {
    if (onTap == null) return const SizedBox.shrink();
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.card,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => widget.closeThen(onTap),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22, color: widget.onSurface),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                      color: widget.onSurface,
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

  Widget _buildReactionStrip() {
    final chipColor = widget.isDark
        ? widget.theme.colorScheme.surfaceContainerHigh
        : FlareThemeTokens.bgSecondary.withValues(alpha: 0.65);
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    final keys = ComposerPackAssets.sortedEmojiKeys;
    final presets = keys.take(6).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: widget.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: !_assetsReady
                ? const SizedBox(
                    height: 38,
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : keys.isEmpty
                ? const SizedBox(
                    height: 38,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '未发现 assets/emoji 资源',
                        style: TextStyle(
                          fontSize: 12,
                          color: FlareThemeTokens.textSecondary,
                        ),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      for (final k in presets)
                        Expanded(
                          child: Center(
                            child: SizedBox(
                              width: 38,
                              height: 38,
                              child: ComposerEmojiPackThumb(
                                emojiKey: k,
                                locale: locale,
                                decodeSize: 72,
                                padding: const EdgeInsets.all(3),
                                onTap: () =>
                                    unawaited(_onPackKeyForReaction(k)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          Material(
            color: chipColor,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: keys.isEmpty ? null : _toggleEmojiPicker,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  _emojiPickerOpen ? Icons.keyboard_arrow_up : Icons.more_horiz,
                  size: 20,
                  color: widget.onSurface.withValues(
                    alpha: keys.isEmpty ? 0.35 : 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiGrid() {
    final keys = ComposerPackAssets.sortedEmojiKeys;
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    if (keys.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      decoration: BoxDecoration(
        color: widget.card,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '选择表情',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.onSurface.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _toggleEmojiPicker,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '收起',
                        style: TextStyle(
                          fontSize: 12,
                          color: FlareThemeTokens.textLink,
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: FlareThemeTokens.textLink,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 220,
            child: GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1,
              ),
              itemCount: keys.length,
              itemBuilder: (context, i) {
                final k = keys[i];
                return ComposerEmojiPackThumb(
                  emojiKey: k,
                  locale: locale,
                  decodeSize: 80,
                  padding: const EdgeInsets.all(2),
                  onTap: () => unawaited(_onPackKeyForReaction(k)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reply = widget.onReply;
    final forward = widget.onForward;
    final recall = widget.onRecall;
    final multiSelect = widget.onMultiSelect;
    final mark = widget.onMark;
    final pinToggle = widget.onPinToggle;
    final pinForSelf = widget.onPinForSelf;
    final copy = widget.onCopy;
    final edit = widget.onEdit;

    final quickChildren = <Widget>[];
    void addQuick(VoidCallback? fn, IconData icon, String label) {
      if (fn == null) return;
      if (quickChildren.isNotEmpty) {
        quickChildren.add(const SizedBox(width: 6));
      }
      quickChildren.add(_detachedQuickTile(fn, icon, label));
    }

    addQuick(reply, Icons.chat_bubble_outline, '回复');
    addQuick(forward, Icons.redo, '转发');
    addQuick(recall, Icons.undo_outlined, '撤回');

    final columnChildren = <Widget>[];

    if (widget.hasReaction) {
      columnChildren.add(_buildReactionStrip());
      columnChildren.add(const SizedBox(height: 6));
    }

    if (_emojiPickerOpen) {
      columnChildren.add(_buildEmojiGrid());
      columnChildren.add(
        SizedBox(
          height: MediaQuery.paddingOf(widget.sheetCtx).bottom > 0 ? 0 : 4,
        ),
      );
    } else {
      if (widget.hasQuick && quickChildren.isNotEmpty) {
        columnChildren.add(Row(children: quickChildren));
        columnChildren.add(const SizedBox(height: 6));
      }

      if (widget.hasGroupA) {
        columnChildren.add(
          _cardWrap(
            children: [
              if (multiSelect != null)
                _SheetListRow(
                  icon: Icons.checklist_rtl,
                  label: '多选',
                  onTap: () => widget.closeThen(multiSelect),
                ),
              if (mark != null)
                _SheetListRow(
                  icon: Icons.flag_outlined,
                  label: '标记',
                  onTap: () => widget.closeThen(mark),
                ),
            ],
          ),
        );
      }
      if (widget.hasGroupA && widget.hasPin) {
        columnChildren.add(const SizedBox(height: 6));
      }
      if (widget.hasPin) {
        columnChildren.add(
          _cardWrap(
            children: [
              if (pinToggle != null)
                _SheetListRow(
                  icon: Icons.vertical_align_top,
                  label: widget.pinLabel,
                  onTap: () => widget.closeThen(pinToggle),
                ),
              if (pinForSelf != null)
                _SheetListRow(
                  icon: Icons.push_pin_outlined,
                  label: '仅自己置顶',
                  onTap: () => widget.closeThen(pinForSelf),
                ),
            ],
          ),
        );
        columnChildren.add(const SizedBox(height: 6));
      }
      if (widget.hasGroupA && widget.hasGroupB && !widget.hasPin) {
        columnChildren.add(const SizedBox(height: 6));
      }
      if (widget.hasGroupA &&
          widget.hasDelete &&
          !widget.hasPin &&
          !widget.hasGroupB) {
        columnChildren.add(const SizedBox(height: 6));
      }
      if (widget.hasGroupB) {
        columnChildren.add(
          _cardWrap(
            children: [
              if (copy != null)
                _SheetListRow(
                  icon: Icons.copy_outlined,
                  label: '复制',
                  onTap: () => widget.closeThen(copy),
                ),
              if (edit != null)
                _SheetListRow(
                  icon: Icons.edit_outlined,
                  label: '编辑',
                  onTap: () => widget.closeThen(edit),
                ),
            ],
          ),
        );
      }
      if (widget.hasGroupB && widget.hasDelete) {
        columnChildren.add(const SizedBox(height: 6));
      }
      if (widget.hasDelete && !widget.hasGroupB && widget.hasPin) {
        columnChildren.add(const SizedBox(height: 6));
      }
      if (widget.hasDelete &&
          !widget.hasGroupB &&
          !widget.hasPin &&
          widget.hasGroupA) {
        columnChildren.add(const SizedBox(height: 6));
      }
      if (widget.hasDelete) {
        columnChildren.add(
          _cardWrap(
            children: [
              _SheetListRow(
                icon: Icons.delete_outline,
                label: '删除',
                iconColor: FlareThemeTokens.error,
                textColor: FlareThemeTokens.error,
                onTap: () async {
                  Navigator.of(widget.sheetCtx).pop();
                  await Future<void>.delayed(Duration.zero);
                  if (!widget.parentContext.mounted) return;
                  await showDeleteMessageChoiceDialog(
                    widget.parentContext,
                    onDeleteForSelf: widget.onDeleteForSelf,
                    onDeleteForEveryone: widget.onDeleteForEveryone,
                    showDeleteForEveryone: widget.showDeleteForEveryoneOption,
                  );
                },
              ),
            ],
          ),
        );
      }
      columnChildren.add(
        SizedBox(
          height: MediaQuery.paddingOf(widget.sheetCtx).bottom > 0 ? 0 : 4,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: columnChildren,
    );
  }
}

List<Widget> _withDividers(List<Widget> rows) {
  if (rows.isEmpty) return rows;
  final out = <Widget>[];
  for (var i = 0; i < rows.length; i++) {
    out.add(rows[i]);
    if (i < rows.length - 1) {
      out.add(
        Divider(
          height: 1,
          thickness: 0.5,
          indent: 40,
          endIndent: 12,
          color: FlareThemeTokens.borderPrimary.withValues(alpha: 0.85),
        ),
      );
    }
  }
  return out;
}

class _SheetListRow extends StatelessWidget {
  const _SheetListRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final c = textColor ?? Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Icon(icon, color: iconColor ?? c, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: c,
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 复制到剪贴板并提示。
void copyMessageToClipboard(BuildContext context, Message message) {
  final text = messageCopyPlainText(message);
  if (text == null || text.trim().isEmpty) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('没有可复制的内容')));
    return;
  }
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(const SnackBar(content: Text('已复制')));
}
