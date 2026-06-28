import 'package:extended_text_field/extended_text_field.dart';
import 'package:flare_im/infrastructure/media/composer_pack_assets.dart';
import 'package:flare_im/infrastructure/media/composer_recent_emoji_store.dart';
import 'package:flare_im/infrastructure/media/composer_static_asset_image.dart';
import 'package:flare_im/infrastructure/media/plain_text_markdown_detect.dart';
import 'package:flare_im/interface/widgets/composer/composer_emoji_pack_thumb.dart';
import 'package:flare_im/interface/widgets/composer/composer_emoji_span_builder.dart';
import 'package:flare_im/interface/widgets/composer/composer_inline_text_field.dart';
import 'package:flare_im/interface/widgets/composer/composer_models.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 表情来自 `assets/emoji/*.webp`，贴纸来自 `assets/stickers/**`。
/// 选择器内资源用 [ComposerStaticAssetImage] 仅显示首帧（静态）；会话内仍可用动图展示。
/// 点表情：无 [onPanelSend] 时插入 `[key]` 并关闭；若仅提供 [onEmojiPackTapSend] 则立即回调。
/// 若同时提供 [onPanelSend] 与 [onEmojiPackTapSend]，点表情仍写入面板输入框（可与文字组合），由用户点「发送」提交。
/// 点贴纸立即走 [onPickSticker]（发送由上层处理，并关闭面板）。
///
/// 若提供 [onPanelSend]，会显示草稿输入框；点选表情写入草稿（不关闭），点「发送」传入当前草稿全文后**不关闭**面板以便继续选表情/输入。
///
/// 若传入 [panelDraftController]，则与主栏**共用**同一 [TextEditingController]（内容与选区一致）。
/// **不要**共用 [FocusNode]：面板顶栏使用内部焦点，避免与主栏两个 [TextField] 抢同一节点导致无法聚焦。
/// 未传入 [panelDraftController] 时使用面板内独立草稿框。
Future<void> showComposerEmojiStickerSheet(
  BuildContext context, {
  required void Function(String insert) onInsertBracket,
  void Function(String packKey)? onEmojiPackTapSend,
  void Function(ComposerStickerPick pick)? onPickSticker,
  void Function(String sheetDraft)? onPanelSend,

  /// 与主栏共用时可传入，使面板顶栏与主输入内容、选区一致。
  TextEditingController? panelDraftController,
  int? panelMaxLength,
  bool panelDraftEnabled = true,
  String? panelHintText,
  ValueChanged<String>? onPanelDraftChanged,

  /// 与 [MessageComposer] 主栏一致：行数、样式、展开、键盘发送。
  int panelMinLines = 1,
  int panelMaxLines = 5,
  SpecialTextSpanBuilder? panelSpecialTextSpanBuilder,
  VoidCallback? onPanelExpandPressed,
  ValueChanged<String>? onPanelSubmitted,
  int initialBottomTab = 0,
}) async {
  final h = MediaQuery.sizeOf(context).height;
  final sheetHeight = (h * 0.54).clamp(340.0, 540.0);

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: Column(
        children: [
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) {
                final nav = Navigator.of(ctx, rootNavigator: true);
                if (nav.canPop()) nav.pop();
              },
              child: const SizedBox.expand(),
            ),
          ),
          Container(
            height: sheetHeight,
            color: const Color(0xFFEEF1F6),
            child: _ComposerEmojiStickerPanel(
              initialBottomTab: initialBottomTab,
              panelDraftController: panelDraftController,
              panelMaxLength: panelMaxLength,
              panelDraftEnabled: panelDraftEnabled,
              panelHintText: panelHintText,
              onPanelDraftChanged: onPanelDraftChanged,
              panelMinLines: panelMinLines,
              panelMaxLines: panelMaxLines,
              panelSpecialTextSpanBuilder: panelSpecialTextSpanBuilder,
              onPanelExpandPressed: onPanelExpandPressed,
              onPanelSubmitted: onPanelSubmitted,
              onInsertBracket: (s) {
                final nav = Navigator.of(ctx, rootNavigator: true);
                if (nav.canPop()) nav.pop();
                onInsertBracket(s);
              },
              onEmojiPackTapSend: onEmojiPackTapSend == null
                  ? null
                  : (key) {
                      final nav = Navigator.of(ctx, rootNavigator: true);
                      if (nav.canPop()) nav.pop();
                      onEmojiPackTapSend(key);
                    },
              onPickSticker: onPickSticker == null
                  ? null
                  : (pick) {
                      final nav = Navigator.of(ctx, rootNavigator: true);
                      if (nav.canPop()) nav.pop();
                      onPickSticker(pick);
                    },
              onPanelSend: onPanelSend == null
                  ? null
                  : (String sheetDraft) {
                      onPanelSend(sheetDraft);
                    },
            ),
          ),
        ],
      ),
    ),
  );
}

class _ComposerEmojiStickerPanel extends StatefulWidget {
  const _ComposerEmojiStickerPanel({
    required this.initialBottomTab,
    required this.onInsertBracket,
    this.onEmojiPackTapSend,
    this.onPickSticker,
    this.onPanelSend,
    this.panelDraftController,
    this.panelMaxLength,
    this.panelDraftEnabled = true,
    this.panelHintText,
    this.onPanelDraftChanged,
    this.panelMinLines = 1,
    this.panelMaxLines = 5,
    this.panelSpecialTextSpanBuilder,
    this.onPanelExpandPressed,
    this.onPanelSubmitted,
  });

  final int initialBottomTab;
  final void Function(String insert) onInsertBracket;
  final void Function(String packKey)? onEmojiPackTapSend;
  final void Function(ComposerStickerPick pick)? onPickSticker;
  final void Function(String sheetDraft)? onPanelSend;
  final TextEditingController? panelDraftController;
  final int? panelMaxLength;
  final bool panelDraftEnabled;
  final String? panelHintText;
  final ValueChanged<String>? onPanelDraftChanged;
  final int panelMinLines;
  final int panelMaxLines;
  final SpecialTextSpanBuilder? panelSpecialTextSpanBuilder;
  final VoidCallback? onPanelExpandPressed;
  final ValueChanged<String>? onPanelSubmitted;

  @override
  State<_ComposerEmojiStickerPanel> createState() =>
      _ComposerEmojiStickerPanelState();
}

class _ComposerEmojiStickerPanelState
    extends State<_ComposerEmojiStickerPanel> {
  static const Color _panelTint = Color(0xFFEEF1F6);

  late int _bottomTab;
  List<String> _recentKeys = [];
  TextEditingController? _ownedDraftController;
  FocusNode? _ownedDraftFocus;
  bool _sharedDraftRefreshScheduled = false;

  int get _packageCount => widget.onPickSticker == null
      ? 0
      : ComposerPackAssets.stickerPackageIdsInOrder.length;

  int get _maxTab => _packageCount;

  List<String> get _packageIds => ComposerPackAssets.stickerPackageIdsInOrder;

  bool get _showDraftField => widget.onPanelSend != null;

  bool get _usesSharedDraft => widget.panelDraftController != null;

  TextEditingController get _draft =>
      widget.panelDraftController ?? _ownedDraftController!;

  void _onSharedDraftControllerChanged() {
    if (!mounted || _sharedDraftRefreshScheduled) return;
    _sharedDraftRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sharedDraftRefreshScheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _bottomTab = widget.initialBottomTab.clamp(0, _maxTab);
    if (_showDraftField) {
      _ownedDraftFocus = FocusNode();
      if (!_usesSharedDraft) {
        _ownedDraftController = TextEditingController();
      } else {
        widget.panelDraftController!.addListener(
          _onSharedDraftControllerChanged,
        );
      }
    }
    _loadRecent();
  }

  @override
  void dispose() {
    if (_usesSharedDraft && _showDraftField) {
      widget.panelDraftController?.removeListener(
        _onSharedDraftControllerChanged,
      );
    }
    _ownedDraftController?.dispose();
    _ownedDraftFocus?.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final raw = await ComposerRecentEmojiStore.load();
    if (!mounted) return;
    setState(() => _recentKeys = raw);
  }

  Future<void> _onEmojiKey(String key) async {
    await ComposerRecentEmojiStore.record(key);
    if (!mounted) return;
    if (_showDraftField && !widget.panelDraftEnabled) return;
    if (_showDraftField) {
      _insertIntoDraft('[$key]');
      return;
    }
    if (widget.onEmojiPackTapSend != null) {
      widget.onEmojiPackTapSend!(key);
      return;
    }
    widget.onInsertBracket('[$key]');
  }

  void _insertIntoDraft(String insert) {
    final v = _draft.value;
    final t = v.text;
    final s = v.selection;
    final start = s.start >= 0 ? s.start : t.length;
    final end = s.end >= 0 ? s.end : t.length;
    var newText = t.replaceRange(start, end, insert);
    if (widget.panelMaxLength != null &&
        newText.length > widget.panelMaxLength!) {
      newText = newText.substring(0, widget.panelMaxLength!);
    }
    final newOffset = (start + insert.length).clamp(0, newText.length);
    _draft.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    widget.onPanelDraftChanged?.call(newText);
    setState(() {});
  }

  String? get _locale => Localizations.maybeLocaleOf(context)?.toLanguageTag();

  /// 与 [MessageComposer._buildInputRow] 使用同一套 [ComposerInlineTextField] 参数（独立 [FocusNode]）。
  Widget _buildDraftTextField() {
    assert(_ownedDraftFocus != null, 'draft focus only when _showDraftField');
    final span =
        widget.panelSpecialTextSpanBuilder ??
        ComposerEmojiSpanBuilder(inlineSize: 15 * 1.72, localeTag: _locale);
    final field = ComposerInlineTextField(
      controller: _draft,
      focusNode: _ownedDraftFocus!,
      hintText: widget.panelHintText ?? '输入或选择表情',
      minLines: widget.panelMinLines,
      maxLines: widget.panelMaxLines,
      enabled: widget.panelDraftEnabled,
      maxLength: widget.panelMaxLength,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.send,
      specialTextSpanBuilder: span,
      onChanged: widget.onPanelDraftChanged,
      onSubmitted: widget.onPanelSubmitted,
      onExpandPressed: widget.onPanelExpandPressed,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    );
    if (widget.onPanelSubmitted == null) return field;
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey != LogicalKeyboardKey.enter &&
            event.logicalKey != LogicalKeyboardKey.numpadEnter) {
          return KeyEventResult.ignored;
        }
        if (HardwareKeyboard.instance.isShiftPressed) {
          return KeyEventResult.ignored;
        }
        widget.onPanelSubmitted!(_draft.text);
        return KeyEventResult.handled;
      },
      child: field,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 2, bottom: 2),
            decoration: BoxDecoration(
              color: FlareThemeTokens.borderPrimary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        if (_showDraftField)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
            child: _buildDraftTextField(),
          ),
        Expanded(
          child: ColoredBox(
            color: _panelTint,
            child: _bottomTab == 0
                ? _buildEmojiPage()
                : _buildStickerPage(_packageIds[_bottomTab - 1]),
          ),
        ),
        _buildBottomBar(context),
      ],
    );
  }

  Widget _buildEmojiPage() {
    final allKeys = ComposerPackAssets.sortedEmojiKeys;
    final recent = _recentKeys.where(allKeys.contains).take(21).toList();

    if (allKeys.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '未在打包资源中发现 assets/emoji/*.webp。\n请确认 pubspec 已声明 assets/emoji/ 且目录内有文件。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: FlareThemeTokens.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        if (recent.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: Text(
                '最常使用',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: FlareThemeTokens.textSecondary.withValues(alpha: 0.95),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (context, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final key = recent[i];
                  return ComposerEmojiPackThumb(
                    emojiKey: key,
                    locale: _locale,
                    onTap: () => _onEmojiKey(key),
                  );
                },
              ),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, recent.isEmpty ? 6 : 10, 8, 6),
            child: Text(
              '默认表情',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: FlareThemeTokens.textSecondary.withValues(alpha: 0.95),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate((context, i) {
              final key = allKeys[i];
              return ComposerEmojiPackThumb(
                emojiKey: key,
                locale: _locale,
                onTap: () => _onEmojiKey(key),
              );
            }, childCount: allKeys.length),
          ),
        ),
      ],
    );
  }

  Widget _buildStickerPage(String packageId) {
    if (widget.onPickSticker == null) {
      return const SizedBox.shrink();
    }
    final items = ComposerPackAssets.stickersForPackage(packageId);
    if (items.isEmpty) {
      return const Center(
        child: Text(
          '当前分包下无 .webp 资源',
          style: TextStyle(color: FlareThemeTokens.textSecondary),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final it = items[i];
        return Tooltip(
          message: it.alt,
          child: Material(
            color: FlareThemeTokens.bgPrimary,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => widget.onPickSticker!(
                ComposerStickerPick(
                  stickerId: it.stickerId,
                  packageId: it.packageId,
                  assetPath: it.assetPath,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: ComposerStaticAssetImage(
                  assetPath: it.assetPath,
                  fit: BoxFit.contain,
                  decodeSize: 128,
                  error: const Icon(
                    Icons.broken_image_outlined,
                    color: FlareThemeTokens.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final sendEnabled = widget.onPanelSend != null && widget.panelDraftEnabled;
    return Material(
      color: FlareThemeTokens.bgPrimary,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 3, 8, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                tooltip: '更多表情包',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('自定义表情包（占位）')));
                },
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: FlareThemeTokens.textSecondary,
                ),
              ),
              _BottomPackChip(
                selected: _bottomTab == 0,
                onTap: () => setState(() => _bottomTab = 0),
                child: Icon(
                  Icons.emoji_emotions_outlined,
                  size: 20,
                  color: _bottomTab == 0
                      ? FlareThemeTokens.primary
                      : FlareThemeTokens.textSecondary,
                ),
              ),
              if (widget.onPickSticker != null)
                for (var i = 0; i < _packageIds.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _BottomPackChip(
                      selected: _bottomTab == i + 1,
                      onTap: () => setState(() => _bottomTab = i + 1),
                      child: _StickerPackTabIcon(packageId: _packageIds[i]),
                    ),
                  ),
              const Spacer(),
              FilledButton(
                onPressed: sendEnabled
                    ? () {
                        final draft = _draft.text;
                        widget.onPanelSend!(draft);
                        if (!_usesSharedDraft) {
                          _draft.clear();
                        }
                        setState(() {});
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: FlareThemeTokens.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '发送',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomPackChip extends StatelessWidget {
  const _BottomPackChip({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? FlareThemeTokens.bgSelected
          : FlareThemeTokens.bgTertiary,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(width: 36, height: 36, child: Center(child: child)),
      ),
    );
  }
}

class _StickerPackTabIcon extends StatelessWidget {
  const _StickerPackTabIcon({required this.packageId});

  final String packageId;

  @override
  Widget build(BuildContext context) {
    final first = ComposerPackAssets.firstStickerInPackage(packageId);
    if (first == null) {
      return const Icon(
        Icons.collections_outlined,
        size: 20,
        color: FlareThemeTokens.textSecondary,
      );
    }
    return ClipOval(
      child: SizedBox(
        width: 28,
        height: 28,
        child: ComposerStaticAssetImage(
          assetPath: first.assetPath,
          fit: BoxFit.cover,
          decodeSize: 64,
        ),
      ),
    );
  }
}

/// 「+」更多面板：图片 / 视频 / 文件 / 文件夹等；可选「表情与贴纸」；后续可扩音视频通话等入口。
Future<void> showComposerAttachSheet(
  BuildContext context, {
  required void Function(ComposerPickMediaKind kind) onPick,
  VoidCallback? onOpenEmojiSticker,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 12),
                  decoration: BoxDecoration(
                    color: FlareThemeTokens.borderPrimary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  '更多功能',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: FlareThemeTokens.textPrimary,
                  ),
                ),
              ),
              if (onOpenEmojiSticker != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                        color: FlareThemeTokens.borderSecondary,
                      ),
                    ),
                    leading: const Icon(
                      Icons.emoji_emotions_outlined,
                      color: FlareThemeTokens.textSecondary,
                    ),
                    title: const Text('表情与贴纸'),
                    subtitle: Text(
                      '来自 assets/emoji 与 assets/stickers',
                      style: TextStyle(
                        fontSize: 12,
                        color: FlareThemeTokens.textSecondary.withValues(
                          alpha: 0.9,
                        ),
                      ),
                    ),
                    onTap: () {
                      final nav = Navigator.of(ctx, rootNavigator: true);
                      if (nav.canPop()) nav.pop();
                      onOpenEmojiSticker();
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _AttachTile(
                            icon: Icons.image_outlined,
                            label: '图片',
                            onTap: () {
                              final nav = Navigator.of(
                                ctx,
                                rootNavigator: true,
                              );
                              if (nav.canPop()) nav.pop();
                              onPick(ComposerPickMediaKind.image);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AttachTile(
                            icon: Icons.videocam_outlined,
                            label: '视频',
                            onTap: () {
                              final nav = Navigator.of(
                                ctx,
                                rootNavigator: true,
                              );
                              if (nav.canPop()) nav.pop();
                              onPick(ComposerPickMediaKind.video);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AttachTile(
                            icon: Icons.insert_drive_file_outlined,
                            label: '文件',
                            onTap: () {
                              final nav = Navigator.of(
                                ctx,
                                rootNavigator: true,
                              );
                              if (nav.canPop()) nav.pop();
                              onPick(ComposerPickMediaKind.file);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _AttachTile(
                            icon: Icons.photo_library_outlined,
                            label: '相册',
                            subtitle: '图片与视频',
                            onTap: () {
                              final nav = Navigator.of(
                                ctx,
                                rootNavigator: true,
                              );
                              if (nav.canPop()) nav.pop();
                              onPick(ComposerPickMediaKind.imageOrVideo);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AttachTile(
                            icon: Icons.folder_open_outlined,
                            label: '文件夹',
                            onTap: () {
                              final nav = Navigator.of(
                                ctx,
                                rootNavigator: true,
                              );
                              if (nav.canPop()) nav.pop();
                              onPick(ComposerPickMediaKind.folder);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AttachTile extends StatelessWidget {
  const _AttachTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FlareThemeTokens.bgTertiary,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: FlareThemeTokens.textSecondary),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: FlareThemeTokens.textPrimary,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: FlareThemeTokens.textSecondary.withValues(
                        alpha: 0.95,
                      ),
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

/// 展开大输入区（与主输入共用 [controller] / [focusNode]）。
/// 使用 [ComposerInlineTextField] 与主栏/表情草稿同款白底无描边样式；底部浅灰工具条。
/// 收起：点击 Sheet 上方空白（与表情面板一致）或系统遮罩。
Future<void> showComposerExpandedEditor(
  BuildContext context, {
  required TextEditingController controller,
  required FocusNode focusNode,
  required String placeholder,
  required int? maxLength,
  required bool disabled,
  required ValueChanged<String> onChanged,
  required VoidCallback onSend,
  Future<void> Function()? onEmojiSticker,
  void Function(ComposerPickMediaKind kind)? onPickMedia,
  void Function(String insert)? onInsertAtCursor,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (ctx) {
      final keyboardBottom = MediaQuery.viewInsetsOf(ctx).bottom;
      final hintText = placeholder.trim().isNotEmpty
          ? placeholder.trim()
          : '发消息';
      final bottomBreathing = keyboardBottom > 0 ? 0.0 : 18.0;
      final localeTag = Localizations.maybeLocaleOf(ctx)?.toLanguageTag();
      final screenH = MediaQuery.sizeOf(ctx).height;
      final panelH = (screenH * 0.58).clamp(280.0, screenH * 0.92);

      Future<void> emoji() async {
        if (onEmojiSticker != null) {
          await onEmojiSticker();
        } else if (ctx.mounted) {
          ScaffoldMessenger.of(
            ctx,
          ).showSnackBar(const SnackBar(content: Text('表情（未接入）')));
        }
      }

      void pick(ComposerPickMediaKind k) {
        if (onPickMedia != null) {
          onPickMedia(k);
        } else if (ctx.mounted) {
          ScaffoldMessenger.of(
            ctx,
          ).showSnackBar(const SnackBar(content: Text('附件（未接入）')));
        }
      }

      void insert(String s) {
        if (onInsertAtCursor != null) {
          onInsertAtCursor(s);
        } else if (ctx.mounted) {
          ScaffoldMessenger.of(
            ctx,
          ).showSnackBar(const SnackBar(content: Text('插入（未接入）')));
        }
      }

      void comingSoon(String name) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(
            ctx,
          ).showSnackBar(SnackBar(content: Text('$name（开发中）')));
        }
      }

      Widget tbIcon(IconData icon, String tip, VoidCallback? onTap) {
        final c = disabled
            ? FlareThemeTokens.composerToolbarIcon.withValues(alpha: 0.38)
            : FlareThemeTokens.composerToolbarIcon;
        return IconButton(
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          onPressed: disabled || onTap == null ? null : onTap,
          icon: Icon(icon, size: 22, color: c),
        );
      }

      return Padding(
        padding: EdgeInsets.only(bottom: keyboardBottom + bottomBreathing),
        child: Column(
          children: [
            Expanded(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) {
                  final nav = Navigator.of(ctx, rootNavigator: true);
                  if (nav.canPop()) nav.pop();
                },
                child: const SizedBox.expand(),
              ),
            ),
            SizedBox(
              height: panelH,
              child: Material(
                color: FlareThemeTokens.bgSecondary,
                child: StatefulBuilder(
                  builder: (modalCtx, setModalState) {
                    void finishSendLive() {
                      if (controller.text.trim().isEmpty || disabled) return;
                      onSend();
                      if (ctx.mounted) {
                        final nav = Navigator.of(ctx, rootNavigator: true);
                        if (nav.canPop()) nav.pop();
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                            child: ComposerInlineTextField(
                              expands: true,
                              controller: controller,
                              focusNode: focusNode,
                              hintText: hintText,
                              enabled: !disabled,
                              maxLength: maxLength,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.45,
                                color: FlareThemeTokens.textPrimary,
                              ),
                              hintFontSize: 16,
                              specialTextSpanBuilder:
                                  PlainTextMarkdownDetect.isMarkdown(
                                    controller.text,
                                  )
                                  ? null
                                  : ComposerEmojiSpanBuilder(
                                      inlineSize: 16 * 1.72,
                                      localeTag: localeTag,
                                    ),
                              textInputAction: TextInputAction.send,
                              contentPadding: const EdgeInsets.all(14),
                              borderRadius: 6,
                              onChanged: (s) {
                                onChanged(s);
                                setModalState(() {});
                              },
                              onSubmitted: (_) => finishSendLive(),
                            ),
                          ),
                        ),
                        ListenableBuilder(
                          listenable: controller,
                          builder: (context, _) {
                            final canSubmitNow =
                                controller.text.trim().isNotEmpty && !disabled;
                            return Container(
                              width: double.infinity,
                              padding: EdgeInsets.fromLTRB(
                                4,
                                2,
                                6,
                                keyboardBottom > 0 ? 4 : 10,
                              ),
                              decoration: BoxDecoration(
                                color: FlareThemeTokens.bgSecondary,
                                border: Border(
                                  top: BorderSide(
                                    color: FlareThemeTokens.borderSecondary
                                        .withValues(alpha: 0.95),
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        tbIcon(
                                          Icons.emoji_emotions_outlined,
                                          '表情与贴纸',
                                          () => emoji(),
                                        ),
                                        tbIcon(
                                          Icons.alternate_email,
                                          '@提及',
                                          () => insert('@'),
                                        ),
                                        tbIcon(
                                          Icons.image_outlined,
                                          '图片',
                                          () =>
                                              pick(ComposerPickMediaKind.image),
                                        ),
                                        tbIcon(
                                          Icons.text_fields_rounded,
                                          '富文本',
                                          () => comingSoon('富文本'),
                                        ),
                                        tbIcon(
                                          Icons.format_indent_increase,
                                          '增加缩进',
                                          () => comingSoon('缩进'),
                                        ),
                                        tbIcon(
                                          Icons.format_indent_decrease,
                                          '减少缩进',
                                          () => comingSoon('缩进'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '发送',
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(
                                      minWidth: 44,
                                      minHeight: 44,
                                    ),
                                    onPressed: canSubmitNow
                                        ? finishSendLive
                                        : null,
                                    icon: Icon(
                                      Icons.send_rounded,
                                      size: 22,
                                      color: canSubmitNow
                                          ? FlareThemeTokens.primary
                                          : FlareThemeTokens.textDisabled,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
