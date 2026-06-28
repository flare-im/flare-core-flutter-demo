import 'dart:async';

import 'package:flare_im/application/providers/chat_outbound_provider.dart';
import 'package:flare_im/infrastructure/media/plain_text_markdown_detect.dart';
import 'package:flare_im/interface/widgets/composer/composer_emoji_span_builder.dart';
import 'package:flare_im/interface/widgets/composer/composer_inline_text_field.dart';
import 'package:flare_im/interface/widgets/composer/composer_models.dart';
import 'package:flare_im/interface/widgets/composer/composer_reply_strip.dart';
import 'package:flare_im/interface/widgets/composer/composer_sheets.dart';
import 'package:flare_im/interface/widgets/composer/draft_idle_scheduler.dart';
import 'package:flare_im/interface/widgets/composer/rich_text_composer_formatter.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'composer_models.dart';

/// 文本输入：输入态（typing）、草稿变更回调（输入静默后调 SDK）。
/// 布局：浅灰底栏 [FlareThemeTokens.bgSecondary]；上行 [ComposerInlineTextField]（与表情面板草稿同款）+ 框内右侧展开；
/// 下行六格均分工具条（线框灰图标）；点「+」展开 4×2 宫格，展开时为「×」同风格收起。
/// 可选 [composeTargetName] → 占位「发送给 xxx」。
/// 发送（文本 / 点选表情立即发 / 贴纸意图）经 [chatOutboundProvider] 派发，由 [ChatScreen] 统一调 SDK。
/// IME「发送」键、[TextInputAction.send]、物理回车（Shift+回车换行）均走同一出站总线。
class MessageComposer extends ConsumerStatefulWidget {
  final String conversationId;
  final String? initialText;
  final void Function(bool isTyping)? onTypingChanged;
  final void Function(String text)? onDraftChanged;

  /// 引用回复条；为 null 时不展示。
  final ComposerReplyQuote? replyQuote;
  final VoidCallback? onClearReply;

  /// 「+」更多入口（附件等）；后续可扩展音视频通话等，未实现业务时可仅 SnackBar 占位。
  final void Function(ComposerPickMediaKind kind)? onPickMedia;

  final int? maxLength;
  final String placeholder;
  final bool disabled;

  /// 非空时输入框占位为「发送给 xxx」（与常见 IM 稿一致）；否则用 [placeholder]。
  final String? composeTargetName;

  const MessageComposer({
    super.key,
    required this.conversationId,
    this.initialText,
    this.onTypingChanged,
    this.onDraftChanged,
    this.replyQuote,
    this.onClearReply,
    this.onPickMedia,
    this.maxLength,
    this.placeholder = 'Type a message...',
    this.disabled = false,
    this.composeTargetName,
  });

  @override
  ConsumerState<MessageComposer> createState() => MessageComposerState();
}

class MessageComposerState extends ConsumerState<MessageComposer> {
  static const Duration _draftIdleDelay = Duration(seconds: 5);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _typingIdleTimer;
  late final DraftIdleScheduler _draftScheduler;
  bool _typingActive = false;

  /// 富文本模式（Aa）；作为持久输入模式，发送后保留。
  bool _richTextEnabled = false;
  RichComposerFormatting _richFormatting = const RichComposerFormatting();

  /// 圆形「+」下方的内联功能宫格（4×2）；与 [showComposerAttachSheet] 并存，「全部附件」进 Sheet。
  bool _moreGridOpen = false;

  bool get _isStackLayout => _controller.text.contains('\n');

  bool get _replyPreviewWarn {
    final t = widget.replyQuote?.preview ?? '';
    return RegExp(
      r'失败|错误|fail|error|invalid|expired|⚠|警告|异常',
      caseSensitive: false,
    ).hasMatch(t);
  }

  String get _effectiveHint {
    final name = widget.composeTargetName?.trim();
    if (name != null && name.isNotEmpty) return '发送给 $name';
    return widget.placeholder;
  }

  @override
  void initState() {
    super.initState();
    final d = widget.initialText;
    if (d != null && d.isNotEmpty) {
      _controller.text = d;
    }
    _draftScheduler = DraftIdleScheduler(
      delay: _draftIdleDelay,
      onSave: (text) => widget.onDraftChanged?.call(text),
    );
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant MessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _typingIdleTimer?.cancel();
      _cancelPendingDraftSave();
      _setTyping(false);
      final d = widget.initialText;
      _controller.text = d ?? '';
    } else if (oldWidget.initialText != widget.initialText &&
        _controller.text.trim().isEmpty) {
      final d = widget.initialText;
      if (d != null && d.isNotEmpty) {
        _controller.text = d;
      }
    }
  }

  void _onFocusChange() {
    _typingIdleTimer?.cancel();
    if (_focusNode.hasFocus) {
      _setTyping(true);
    } else {
      _setTyping(false);
    }
  }

  @override
  void dispose() {
    _typingIdleTimer?.cancel();
    flushDraftNow();
    _draftScheduler.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _setTyping(bool v) {
    if (_typingActive == v) return;
    _typingActive = v;
    widget.onTypingChanged?.call(v);
  }

  void _onTextChanged(String t) {
    setState(() {});

    _scheduleDraftSave(t);

    if (widget.onTypingChanged == null) return;

    if (_focusNode.hasFocus) {
      _setTyping(true);
      return;
    }

    if (t.trim().isEmpty) return;

    _setTyping(true);
    _typingIdleTimer?.cancel();
    _typingIdleTimer = Timer(const Duration(milliseconds: 3500), () {
      _setTyping(false);
    });
  }

  void _cancelPendingDraftSave() {
    _draftScheduler.cancel();
  }

  /// 退出聊天页或切换会话前，把当前仍在静默窗口内的非空输入立即保存为草稿。
  void flushDraftNow() {
    _draftScheduler.flush();
  }

  void _scheduleDraftSave(String text) {
    if (widget.onDraftChanged == null) return;
    _draftScheduler.schedule(text);
  }

  void _restartDraftIdleWindow() {
    _scheduleDraftSave(_controller.text);
  }

  void _insertAtCursor(String insert) {
    _closeMoreGrid();
    if (widget.disabled) return;
    final v = _controller.value;
    final s = v.selection;
    final t = v.text;
    final start = s.start >= 0 ? s.start : t.length;
    final end = s.end >= 0 ? s.end : t.length;
    var newText = t.replaceRange(start, end, insert);
    if (widget.maxLength != null && newText.length > widget.maxLength!) {
      newText = newText.substring(0, widget.maxLength!);
    }
    final newOffset = (start + insert.length).clamp(0, newText.length);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    _onTextChanged(newText);
  }

  void _closeMoreGrid() {
    if (!_moreGridOpen) return;
    setState(() => _moreGridOpen = false);
  }

  /// 收起「+」内联宫格（例如点击消息区时通过 [GlobalKey<MessageComposerState>] 调用）。
  void dismissMoreFeatureGrid() => _closeMoreGrid();

  void _toggleMoreGrid() {
    if (widget.disabled) return;
    setState(() {
      _moreGridOpen = !_moreGridOpen;
      if (_moreGridOpen) {
        _focusNode.unfocus();
      }
    });
  }

  void _snackComingSoon(String name) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$name（占位）')));
  }

  void _pickMedia(ComposerPickMediaKind kind) {
    if (widget.onPickMedia != null) {
      widget.onPickMedia!(kind);
    } else {
      final label = switch (kind) {
        ComposerPickMediaKind.imageOrVideo => '相册（图片与视频）',
        ComposerPickMediaKind.image => '图片',
        ComposerPickMediaKind.video => '视频',
        ComposerPickMediaKind.audio => '语音',
        ComposerPickMediaKind.file => '本地文件',
        ComposerPickMediaKind.folder => '本地文件夹',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$label（占位）')));
    }
  }

  /// 与主栏 [ComposerInlineTextField] 共用 [TextEditingController]，顶栏单独 [FocusNode]，避免双输入框抢焦点无法打字。
  Future<void> _showEmojiStickerSheet(BuildContext sheetContext) async {
    final cid = widget.conversationId;
    final locale = Localizations.maybeLocaleOf(sheetContext)?.toLanguageTag();
    await showComposerEmojiStickerSheet(
      sheetContext,
      panelDraftController: _controller,
      panelMinLines: 1,
      panelMaxLines: _isStackLayout ? 8 : 5,
      panelMaxLength: widget.maxLength,
      panelDraftEnabled: !widget.disabled,
      panelHintText: _effectiveHint,
      onPanelDraftChanged: _onTextChanged,
      panelSpecialTextSpanBuilder:
          PlainTextMarkdownDetect.isMarkdown(_controller.text)
          ? null
          : ComposerEmojiSpanBuilder(inlineSize: 15 * 1.72, localeTag: locale),
      onPanelExpandPressed: widget.disabled
          ? null
          : () => unawaited(_openExpandedEditor()),
      onPanelSubmitted: _submit,
      onInsertBracket: (s) {
        _insertAtCursor(s);
        _focusNode.requestFocus();
      },
      onEmojiPackTapSend: (packKey) {
        _restartDraftIdleWindow();
        ref
            .read(chatOutboundProvider(cid).notifier)
            .dispatch(ChatOutboundSendEmojiPackKey(packKey));
      },
      onPickSticker: (pick) {
        _restartDraftIdleWindow();
        ref
            .read(chatOutboundProvider(cid).notifier)
            .dispatch(ChatOutboundSendSticker(pick));
      },
      onPanelSend: (sheetDraft) => _submit(sheetDraft),
    );
  }

  Future<void> _openEmojiStickerPanel() async {
    _closeMoreGrid();
    await _showEmojiStickerSheet(context);
  }

  void _toggleRichText() {
    _closeMoreGrid();
    if (widget.disabled) return;
    setState(() {
      _richTextEnabled = !_richTextEnabled;
      if (!_richTextEnabled) {
        _richFormatting = const RichComposerFormatting();
      }
    });
    if (_richTextEnabled) {
      _focusNode.requestFocus();
    }
  }

  Future<void> _openExpandedEditor() async {
    _closeMoreGrid();
    await showComposerExpandedEditor(
      context,
      controller: _controller,
      focusNode: _focusNode,
      placeholder: _effectiveHint,
      maxLength: widget.maxLength,
      disabled: widget.disabled,
      onChanged: _onTextChanged,
      onSend: () => _submit(_controller.text),
      onEmojiSticker: () => _showEmojiStickerSheet(context),
      onPickMedia: _pickMedia,
      onInsertAtCursor: _insertAtCursor,
    );
  }

  void _submit(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _typingIdleTimer?.cancel();
    _cancelPendingDraftSave();
    _setTyping(false);
    ref
        .read(chatOutboundProvider(widget.conversationId).notifier)
        .dispatch(
          _richTextEnabled
              ? ChatOutboundSendRichDoc(
                  format: ChatRichDocInputFormat.markdown,
                  source: RichComposerMarkdownSerializer.serialize(
                    t,
                    _richFormatting,
                  ),
                )
              : PlainTextMarkdownDetect.isMarkdown(t)
              ? ChatOutboundSendRichDoc(
                  format: ChatRichDocInputFormat.markdown,
                  source: t,
                )
              : ChatOutboundSendText(t),
        );
    _controller.clear();
    _closeMoreGrid();
    setState(() {});
    _focusNode.unfocus();
  }

  void _toggleInlineStyle(RichComposerInlineStyle style) {
    if (widget.disabled) return;
    setState(() {
      _richFormatting = _richFormatting.toggleInline(style);
    });
    _focusNode.requestFocus();
  }

  void _toggleBlockStyle(RichComposerBlockStyle style) {
    if (widget.disabled) return;
    setState(() {
      _richFormatting = _richFormatting.toggleBlock(style);
    });
    _focusNode.requestFocus();
  }

  TextStyle _inputTextStyle() {
    final inline = _richFormatting.inlineStyles;
    return TextStyle(
      fontSize: _richFormatting.blockStyle == RichComposerBlockStyle.heading
          ? 17
          : 15,
      height: 1.45,
      color: inline.contains(RichComposerInlineStyle.link)
          ? FlareThemeTokens.primary
          : FlareThemeTokens.textPrimary,
      fontWeight:
          inline.contains(RichComposerInlineStyle.bold) ||
              _richFormatting.blockStyle == RichComposerBlockStyle.heading
          ? FontWeight.w700
          : FontWeight.w400,
      fontStyle: inline.contains(RichComposerInlineStyle.italic)
          ? FontStyle.italic
          : FontStyle.normal,
      decoration:
          inline.contains(RichComposerInlineStyle.strike) ||
              inline.contains(RichComposerInlineStyle.link)
          ? TextDecoration.combine([
              if (inline.contains(RichComposerInlineStyle.strike))
                TextDecoration.lineThrough,
              if (inline.contains(RichComposerInlineStyle.link))
                TextDecoration.underline,
            ])
          : TextDecoration.none,
      fontFamily: inline.contains(RichComposerInlineStyle.inlineCode)
          ? 'Menlo'
          : null,
    );
  }

  /// 上行：[ComposerInlineTextField] + 框内右侧「展开」。
  /// 发送：软键盘「发送」→ [onSubmitted]；硬键盘回车→发送，Shift+回车→换行。
  Widget _buildInputRow({required int minLines, required int maxLines}) {
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
        _submit(_controller.text);
        return KeyEventResult.handled;
      },
      child: ComposerInlineTextField(
        controller: _controller,
        focusNode: _focusNode,
        hintText: _effectiveHint,
        minLines: minLines,
        maxLines: maxLines,
        maxLength: widget.maxLength,
        enabled: !widget.disabled,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.send,
        style: _richTextEnabled ? _inputTextStyle() : null,
        specialTextSpanBuilder:
            _richTextEnabled ||
                PlainTextMarkdownDetect.isMarkdown(_controller.text)
            ? null
            : ComposerEmojiSpanBuilder(
                inlineSize: 15 * 1.72,
                localeTag: Localizations.maybeLocaleOf(
                  context,
                )?.toLanguageTag(),
              ),
        onChanged: _onTextChanged,
        onSubmitted: _submit,
        onExpandPressed: widget.disabled
            ? null
            : () => unawaited(_openExpandedEditor()),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      ),
    );
  }

  Widget _formatChip({
    required Widget child,
    required String tooltip,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    final foreground = selected
        ? FlareThemeTokens.primary
        : FlareThemeTokens.textSecondary;
    final background = selected
        ? FlareThemeTokens.bgSelected
        : FlareThemeTokens.bgPrimary;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.disabled ? null : onPressed,
            borderRadius: BorderRadius.circular(15),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.disabled
                    ? background.withValues(alpha: 0.42)
                    : background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? FlareThemeTokens.primary.withValues(alpha: 0.18)
                      : FlareThemeTokens.borderSecondary.withValues(
                          alpha: 0.62,
                        ),
                  width: 0.5,
                ),
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: foreground, size: 15),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formatText(String value, {bool italic = false, bool strike = false}) {
    return Text(
      value,
      style: TextStyle(
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        decoration: strike ? TextDecoration.lineThrough : TextDecoration.none,
      ),
    );
  }

  Widget _buildRichFormatStrip() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _richTextEnabled
          ? Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _formatChip(
                      child: _formatText('Aa'),
                      tooltip: '标题',
                      selected: _richFormatting.isBlockActive(
                        RichComposerBlockStyle.heading,
                      ),
                      onPressed: () =>
                          _toggleBlockStyle(RichComposerBlockStyle.heading),
                    ),
                    const SizedBox(width: 6),
                    _formatChip(
                      child: _formatText('B'),
                      tooltip: '加粗',
                      selected: _richFormatting.isInlineActive(
                        RichComposerInlineStyle.bold,
                      ),
                      onPressed: () =>
                          _toggleInlineStyle(RichComposerInlineStyle.bold),
                    ),
                    const SizedBox(width: 6),
                    _formatChip(
                      child: _formatText('S', strike: true),
                      tooltip: '删除线',
                      selected: _richFormatting.isInlineActive(
                        RichComposerInlineStyle.strike,
                      ),
                      onPressed: () =>
                          _toggleInlineStyle(RichComposerInlineStyle.strike),
                    ),
                    const SizedBox(width: 6),
                    _formatChip(
                      child: _formatText('I', italic: true),
                      tooltip: '斜体',
                      selected: _richFormatting.isInlineActive(
                        RichComposerInlineStyle.italic,
                      ),
                      onPressed: () =>
                          _toggleInlineStyle(RichComposerInlineStyle.italic),
                    ),
                    const SizedBox(width: 6),
                    _formatChip(
                      child: const Icon(Icons.format_list_bulleted_rounded),
                      tooltip: '无序列表',
                      selected: _richFormatting.isBlockActive(
                        RichComposerBlockStyle.bulletList,
                      ),
                      onPressed: () =>
                          _toggleBlockStyle(RichComposerBlockStyle.bulletList),
                    ),
                    const SizedBox(width: 6),
                    _formatChip(
                      child: const Icon(Icons.format_list_numbered_rounded),
                      tooltip: '有序列表',
                      selected: _richFormatting.isBlockActive(
                        RichComposerBlockStyle.orderedList,
                      ),
                      onPressed: () =>
                          _toggleBlockStyle(RichComposerBlockStyle.orderedList),
                    ),
                    const SizedBox(width: 6),
                    _formatChip(
                      child: const Icon(Icons.format_quote_rounded),
                      tooltip: '引用',
                      selected: _richFormatting.isBlockActive(
                        RichComposerBlockStyle.quote,
                      ),
                      onPressed: () =>
                          _toggleBlockStyle(RichComposerBlockStyle.quote),
                    ),
                    const SizedBox(width: 6),
                    _formatChip(
                      child: const Icon(Icons.code_rounded),
                      tooltip: '代码块',
                      selected: _richFormatting.isBlockActive(
                        RichComposerBlockStyle.codeBlock,
                      ),
                      onPressed: () =>
                          _toggleBlockStyle(RichComposerBlockStyle.codeBlock),
                    ),
                    const SizedBox(width: 6),
                    _formatChip(
                      child: _formatText('{}'),
                      tooltip: '行内代码',
                      selected: _richFormatting.isInlineActive(
                        RichComposerInlineStyle.inlineCode,
                      ),
                      onPressed: () => _toggleInlineStyle(
                        RichComposerInlineStyle.inlineCode,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _formatChip(
                      child: const Icon(Icons.link_rounded),
                      tooltip: '链接',
                      selected: _richFormatting.isInlineActive(
                        RichComposerInlineStyle.link,
                      ),
                      onPressed: () =>
                          _toggleInlineStyle(RichComposerInlineStyle.link),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }

  Widget _toolbarIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool selected = false,
  }) {
    final base = selected
        ? FlareThemeTokens.primary
        : FlareThemeTokens.composerToolbarIcon;
    final color = widget.disabled ? base.withValues(alpha: 0.38) : base;
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      onPressed: widget.disabled ? null : onPressed,
      icon: Icon(icon, size: 24, color: color),
    );
  }

  Widget _moreGridTile({
    required String label,
    required IconData icon,
    required Color background,
    required VoidCallback onTap,
  }) {
    final enabled = !widget.disabled;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled
            ? () {
                onTap();
              }
            : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: enabled
                      ? background
                      : background.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.15,
                  color: enabled
                      ? FlareThemeTokens.textSecondary
                      : FlareThemeTokens.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 宫格单元顶部对齐，避免行距被单元格纵向居中拉大。
  Widget _moreGridTileAligned({
    required String label,
    required IconData icon,
    required Color background,
    required VoidCallback onTap,
  }) {
    return Align(
      alignment: Alignment.topCenter,
      child: _moreGridTile(
        label: label,
        icon: icon,
        background: background,
        onTap: onTap,
      ),
    );
  }

  /// 工具栏下方 4×2 宫格。
  Widget _buildMoreFeatureGrid() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _moreGridOpen
          ? Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 0),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 2,
                crossAxisSpacing: 6,
                childAspectRatio: 1.05,
                children: [
                  _moreGridTileAligned(
                    label: '文件',
                    icon: Icons.folder_outlined,
                    background: FlareThemeTokens.warning,
                    onTap: () {
                      _closeMoreGrid();
                      _pickMedia(ComposerPickMediaKind.file);
                    },
                  ),
                  _moreGridTileAligned(
                    label: '视频',
                    icon: Icons.videocam_outlined,
                    background: FlareThemeTokens.primaryHover,
                    onTap: () {
                      _closeMoreGrid();
                      _pickMedia(ComposerPickMediaKind.video);
                    },
                  ),
                  _moreGridTileAligned(
                    label: '位置',
                    icon: Icons.location_on_outlined,
                    background: FlareThemeTokens.info,
                    onTap: () {
                      _closeMoreGrid();
                      _restartDraftIdleWindow();
                      ref
                          .read(
                            chatOutboundProvider(
                              widget.conversationId,
                            ).notifier,
                          )
                          .dispatch(
                            const ChatOutboundRequestBusinessMessage(
                              ChatBusinessMessageKind.location,
                            ),
                          );
                    },
                  ),
                  _moreGridTileAligned(
                    label: '名片',
                    icon: Icons.badge_outlined,
                    background: FlareThemeTokens.primaryActive,
                    onTap: () {
                      _closeMoreGrid();
                      _restartDraftIdleWindow();
                      ref
                          .read(
                            chatOutboundProvider(
                              widget.conversationId,
                            ).notifier,
                          )
                          .dispatch(
                            const ChatOutboundRequestBusinessMessage(
                              ChatBusinessMessageKind.contactCard,
                            ),
                          );
                    },
                  ),
                  _moreGridTileAligned(
                    label: '日程',
                    icon: Icons.event_note_outlined,
                    background: FlareThemeTokens.important,
                    onTap: () {
                      _closeMoreGrid();
                      _restartDraftIdleWindow();
                      ref
                          .read(
                            chatOutboundProvider(
                              widget.conversationId,
                            ).notifier,
                          )
                          .dispatch(
                            const ChatOutboundRequestBusinessMessage(
                              ChatBusinessMessageKind.schedule,
                            ),
                          );
                    },
                  ),
                  _moreGridTileAligned(
                    label: '任务',
                    icon: Icons.task_alt_outlined,
                    background: FlareThemeTokens.robot,
                    onTap: () {
                      _closeMoreGrid();
                      _restartDraftIdleWindow();
                      ref
                          .read(
                            chatOutboundProvider(
                              widget.conversationId,
                            ).notifier,
                          )
                          .dispatch(
                            const ChatOutboundRequestBusinessMessage(
                              ChatBusinessMessageKind.task,
                            ),
                          );
                    },
                  ),
                  _moreGridTileAligned(
                    label: '投票',
                    icon: Icons.poll_outlined,
                    background: FlareThemeTokens.success,
                    onTap: () {
                      _closeMoreGrid();
                      _snackComingSoon('投票');
                    },
                  ),
                  _moreGridTileAligned(
                    label: '链接',
                    icon: Icons.link_rounded,
                    background: FlareThemeTokens.info,
                    onTap: () {
                      _closeMoreGrid();
                      _snackComingSoon('链接');
                    },
                  ),
                  _moreGridTileAligned(
                    label: '小程序',
                    icon: Icons.apps_rounded,
                    background: FlareThemeTokens.primaryHover,
                    onTap: () {
                      _closeMoreGrid();
                      _snackComingSoon('小程序');
                    },
                  ),
                  _moreGridTileAligned(
                    label: '话题',
                    icon: Icons.forum_outlined,
                    background: FlareThemeTokens.robot,
                    onTap: () {
                      _closeMoreGrid();
                      _snackComingSoon('话题');
                    },
                  ),
                  _moreGridTileAligned(
                    label: '通知',
                    icon: Icons.notifications_none_rounded,
                    background: FlareThemeTokens.warning,
                    onTap: () {
                      _closeMoreGrid();
                      _snackComingSoon('通知');
                    },
                  ),
                  _moreGridTileAligned(
                    label: '公告',
                    icon: Icons.campaign_outlined,
                    background: FlareThemeTokens.important,
                    onTap: () {
                      _closeMoreGrid();
                      _snackComingSoon('公告');
                    },
                  ),
                ],
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }

  /// 下行：六枚工具均分整行（表情 / @ / 语音 / 图片 / Aa / 更多）。
  Widget _buildBottomToolbar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 4, bottom: 0),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: FlareThemeTokens.borderSecondary.withValues(alpha: 0.95),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: _toolbarIconButton(
                icon: Icons.emoji_emotions_outlined,
                tooltip: '表情与贴纸',
                onPressed: () {
                  _closeMoreGrid();
                  unawaited(_openEmojiStickerPanel());
                },
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: _toolbarIconButton(
                icon: Icons.alternate_email,
                tooltip: '@提及',
                onPressed: () => _insertAtCursor('@'),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: _toolbarIconButton(
                icon: Icons.mic_none_outlined,
                tooltip: '语音',
                onPressed: () {
                  _closeMoreGrid();
                  _pickMedia(ComposerPickMediaKind.audio);
                },
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: _toolbarIconButton(
                icon: Icons.image_outlined,
                tooltip: '图片',
                onPressed: () {
                  _closeMoreGrid();
                  _pickMedia(ComposerPickMediaKind.image);
                },
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: _toolbarIconButton(
                icon: Icons.text_fields_rounded,
                tooltip: '富文本',
                selected: _richTextEnabled,
                onPressed: _toggleRichText,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: _toolbarIconButton(
                icon: _moreGridOpen ? Icons.close_outlined : Icons.add_outlined,
                tooltip: _moreGridOpen ? '收起' : '更多功能',
                onPressed: _toggleMoreGrid,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 默认：上行输入 + 下行工具栏；发送用 IME 发送键 / onSubmitted 与硬键盘回车。
  Widget _buildMobileCompactRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildInputRow(minLines: 1, maxLines: 5),
        _buildRichFormatStrip(),
        const SizedBox(height: 8),
        _buildBottomToolbar(),
        _buildMoreFeatureGrid(),
      ],
    );
  }

  /// 多行：同上；换行用 Shift+回车，发送用回车 / 键盘发送键。
  Widget _buildStackBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildInputRow(minLines: 1, maxLines: 8),
        _buildRichFormatStrip(),
        const SizedBox(height: 8),
        _buildBottomToolbar(),
        _buildMoreFeatureGrid(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final showReply = widget.replyQuote != null && widget.replyQuote!.isVisible;
    final stack = _isStackLayout;

    return Material(
      color: FlareThemeTokens.bgSecondary,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: FlareThemeTokens.borderSecondary),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, showReply ? 8 : 10, 8, stack ? 4 : 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showReply)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ComposerReplyStrip(
                    quote: widget.replyQuote!,
                    onClear: widget.onClearReply,
                    previewWarn: _replyPreviewWarn,
                  ),
                ),
              stack ? _buildStackBody() : _buildMobileCompactRow(),
              if (stack && _controller.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '多行模式 · 发送键或回车发送，Shift+回车换行',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      color: FlareThemeTokens.textSecondary.withValues(
                        alpha: 0.9,
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
