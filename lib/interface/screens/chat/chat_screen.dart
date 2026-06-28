import 'dart:async';
import 'dart:io';

import 'package:extended_text_field/extended_text_field.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flare_call_kit/flare_call_kit.dart';
import 'package:flare_im/application/outbound/im_outbound_facade.dart';
import 'package:flare_im/application/providers/active_chat_stack_provider.dart';
import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/application/providers/call_provider.dart';
import 'package:flare_im/application/providers/chat_outbound_provider.dart';
import 'package:flare_im/application/providers/conversation_state_provider.dart';
import 'package:flare_im/application/providers/im_outbound_provider.dart';
import 'package:flare_im/application/providers/im_sync_state_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/application/providers/message_state_provider.dart';
import 'package:flare_im/application/providers/workbench_ui_provider.dart';
import 'package:flare_im/application/selectors/message_list_view_model.dart';
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart' as im;
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/infrastructure/mappers/sdk_model_mapper.dart';
import 'package:flare_im/infrastructure/media/plain_text_markdown_detect.dart';
import 'package:flare_im/interface/router/app_router.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/composer/composer_emoji_span_builder.dart';
import 'package:flare_im/interface/widgets/composer/message_composer.dart';
import 'package:flare_im/interface/widgets/composer/sdk_message_build_catalog.dart';
import 'package:flare_im/interface/widgets/composer/sdk_message_build_sheet.dart';
import 'package:flare_im/interface/widgets/conversation_details_panel.dart';
import 'package:flare_im/interface/widgets/location/location_picker_sheet.dart';
import 'package:flare_im/interface/widgets/message/chat_message_list_item.dart';
import 'package:flare_im/shared/layout/workbench_layout.dart';
import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final bool embedInWorkbench;

  const ChatScreen({
    super.key,
    required this.conversationId,
    this.embedInWorkbench = false,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with RouteAware {
  final _scrollController = ScrollController();
  final _composerKey = GlobalKey<MessageComposerState>();
  bool _loadingOlder = false;
  late final ActiveChatStackNotifier _activeChatStack;
  late final ImOutboundFacade _imOutbound;
  ModalRoute<dynamic>? _route;
  bool _isForeground = false;
  final Set<String> _subscribedPresenceUserIds = <String>{};
  final Set<String> _presenceQueriedUserIds = <String>{};
  List<String>? _lastRenderedMessageKeys;
  int _tailFollowGeneration = 0;
  final Set<Timer> _tailFollowTimers = <Timer>{};

  /// 引用回复：列表稳定键 + 输入区展示用快照。
  String? _replyTargetMessageKey;
  ComposerReplyQuote? _replyQuoteSnapshot;

  bool _multiSelectMode = false;
  final Set<String> _multiSelectKeys = <String>{};

  String get _cid => widget.conversationId.trim();

  void _flushComposerDraftNow() {
    _composerKey.currentState?.flushDraftNow();
  }

  void _clearReplyTarget() {
    setState(() {
      _replyTargetMessageKey = null;
      _replyQuoteSnapshot = null;
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _multiSelectMode = false;
      _multiSelectKeys.clear();
    });
  }

  void _toggleMultiSelectKey(String messageKey) {
    setState(() {
      if (_multiSelectKeys.contains(messageKey)) {
        _multiSelectKeys.remove(messageKey);
      } else {
        _multiSelectKeys.add(messageKey);
      }
    });
  }

  void _startMultiSelectWith(String messageKey) {
    setState(() {
      _multiSelectMode = true;
      _multiSelectKeys
        ..clear()
        ..add(messageKey);
    });
  }

  void _startReplyToMessageKey(String messageKey) {
    final list = ref.read(messageProvider(_cid));
    final vm = messageRowViewModelForKey(list, messageKey);
    final m = vm?.message;
    if (m == null) return;
    final name = m.senderDisplayName.trim().isNotEmpty
        ? m.senderDisplayName.trim()
        : (m.senderName.trim().isNotEmpty ? m.senderName.trim() : m.senderId);
    setState(() {
      _replyTargetMessageKey = messageKey;
      _replyQuoteSnapshot = ComposerReplyQuote(
        senderName: name,
        preview: m.content.previewText,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _activeChatStack = ref.read(activeChatStackProvider.notifier);
    _imOutbound = ref.read(imOutboundProvider);
    _scrollController.addListener(_onScrollNearTop);
    Future.microtask(() async {
      if (!mounted) return;
      await _imOutbound.chatEnterLoadAndMarkRead(_cid);
    });
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _replyTargetMessageKey = null;
      _replyQuoteSnapshot = null;
      _multiSelectMode = false;
      _multiSelectKeys.clear();
      _lastRenderedMessageKeys = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || route == _route) return;
    if (_route != null) {
      appRouteObserver.unsubscribe(this);
    }
    _route = route;
    appRouteObserver.subscribe(this, route);
    _setForeground(route.isCurrent);
  }

  void _setForeground(bool active) {
    if (_isForeground == active) return;
    _isForeground = active;
    Future<void>(() {
      if (active) {
        if (!mounted) return;
        _activeChatStack.push(_cid);
        return;
      }
      _activeChatStack.remove(_cid);
    });
  }

  @override
  void didPush() => _setForeground(true);

  @override
  void didPopNext() => _setForeground(true);

  @override
  void didPushNext() => _setForeground(false);

  @override
  void didPop() => _setForeground(false);

  @override
  void dispose() {
    _flushComposerDraftNow();
    appRouteObserver.unsubscribe(this);
    _setForeground(false);
    _cancelTailFollowTimers();
    _scrollController.removeListener(_onScrollNearTop);
    _scrollController.dispose();
    super.dispose();
  }

  /// 正向时间线：offset 接近 0 时加载更早消息。
  void _onScrollNearTop() {
    if (!_scrollController.hasClients || _loadingOlder) return;
    final pos = _scrollController.position;
    if (!pos.hasPixels || pos.maxScrollExtent <= 0) return;
    if (!_isNearTimelineBottom()) {
      _tailFollowGeneration += 1;
    }
    if (pos.pixels > 320) return;
    unawaited(_loadOlderPage());
  }

  bool _isNearTimelineBottom() {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    if (!pos.hasPixels) return true;
    return (pos.maxScrollExtent - pos.pixels) <= 180;
  }

  void _scrollTimelineToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final target = pos.maxScrollExtent;
    if ((target - pos.pixels).abs() < 1) return;
    if (!animated) {
      _scrollController.jumpTo(target);
      return;
    }
    unawaited(
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _followTimelineTailIfNeeded(MessageListKeysSignal keysSignal) {
    final nextKeys = keysSignal.orderedKeys;
    final previousKeys = _lastRenderedMessageKeys;
    final shouldFollow = _shouldFollowTimelineTail(previousKeys, nextKeys);
    _lastRenderedMessageKeys = List<String>.of(nextKeys);
    if (!shouldFollow) return;
    _scheduleTimelineTailFollow(animated: previousKeys != null);
  }

  void _scheduleTimelineTailFollow({required bool animated}) {
    _cancelTailFollowTimers();
    final generation = ++_tailFollowGeneration;
    void scroll({required bool animated}) {
      if (!mounted) return;
      if (generation != _tailFollowGeneration) return;
      _scrollTimelineToBottom(animated: animated);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scroll(animated: animated);
    });

    for (final delay in const [
      Duration(milliseconds: 80),
      Duration(milliseconds: 180),
      Duration(milliseconds: 420),
      Duration(milliseconds: 760),
    ]) {
      late final Timer timer;
      timer = Timer(delay, () {
        _tailFollowTimers.remove(timer);
        scroll(animated: false);
      });
      _tailFollowTimers.add(timer);
    }
  }

  void _cancelTailFollowTimers() {
    _tailFollowGeneration += 1;
    for (final timer in _tailFollowTimers) {
      timer.cancel();
    }
    _tailFollowTimers.clear();
  }

  bool _shouldFollowTimelineTail(
    List<String>? previousKeys,
    List<String> nextKeys,
  ) {
    if (nextKeys.isEmpty) return false;
    if (previousKeys == null) return true;
    if (previousKeys.isEmpty) return true;
    final tailChanged = previousKeys.last != nextKeys.last;
    final appendedAtTail =
        nextKeys.length > previousKeys.length &&
        nextKeys.length >= previousKeys.length &&
        _hasSamePrefix(previousKeys, nextKeys);
    if (!tailChanged && !appendedAtTail) return false;
    return _isNearTimelineBottom();
  }

  bool _hasSamePrefix(List<String> prefix, List<String> list) {
    if (prefix.length > list.length) return false;
    for (var i = 0; i < prefix.length; i += 1) {
      if (prefix[i] != list[i]) return false;
    }
    return true;
  }

  Future<void> _loadOlderPage() async {
    if (_loadingOlder || !mounted) return;
    _loadingOlder = true;
    try {
      await ref.read(imOutboundProvider).chatLoadMore(_cid);
    } catch (e, st) {
      debugPrint('loadMore failed: $e\n$st');
    } finally {
      if (mounted) _loadingOlder = false;
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(imOutboundProvider).chatPullServerAndMarkRead(_cid);
  }

  void _dismissComposerMoreGrid() {
    _composerKey.currentState?.dismissMoreFeatureGrid();
  }

  Future<void> _ensurePeerPresence(String peerUserId) async {
    final uid = peerUserId.trim();
    if (uid.isEmpty) return;
    try {
      if (_subscribedPresenceUserIds.add(uid)) {
        await _imOutbound.chatSubscribeUserPresence([uid]);
      }
      if (!_presenceQueriedUserIds.add(uid)) return;
      final presences = await _imOutbound.chatBatchGetUserPresence([uid]);
      final raw = presences[uid];
      final user = SdkModelMapper.userFromPresenceEntry(uid, raw);
      if (user != null && mounted) {
        ref.read(userDirectoryProvider.notifier).upsert(user);
      }
      if (raw is Map) {
        final online = raw['isOnline'] == true;
        if (mounted) {
          ref.read(presenceMapProvider.notifier).setOnline(uid, online);
        }
      } else if (raw is bool && mounted) {
        ref.read(presenceMapProvider.notifier).setOnline(uid, raw);
      }
    } catch (e, st) {
      debugPrint('ensure peer presence failed: $e\n$st');
      _subscribedPresenceUserIds.remove(uid);
      _presenceQueriedUserIds.remove(uid);
    }
  }

  Future<void> _syncConversationMeta() async {
    await ref.read(imOutboundProvider).chatSyncConversationMeta(_cid);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已请求同步会话')));
  }

  void _openMessageSearch() {
    navigateToMessageSearch(context, conversationId: _cid);
  }

  Future<void> _openConversationDetails() async {
    if (isWorkbenchWide(context)) {
      ref.read(workbenchDetailsOpenProvider.notifier).state = true;
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: FlareImDesign.card,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.88,
        child: ConversationDetailsPanel(
          conversationId: _cid,
          onClose: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  Future<void> _handleOutboundSendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final key = _replyTargetMessageKey;
    if (key != null && key.isNotEmpty) {
      final list = ref.read(messageProvider(_cid));
      final vm = messageRowViewModelForKey(list, key);
      final quoted = vm?.message;
      if (quoted == null || quoted.isRecalled) {
        _clearReplyTarget();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('原消息已不可用，已按纯文本发送')));
        }
        await ref
            .read(imOutboundProvider)
            .chatSendTextAndClearDraft(_cid, trimmed);
        return;
      }
      try {
        await ref
            .read(imOutboundProvider)
            .chatSendQuoteTextAndClearDraft(_cid, trimmed, quoted);
        _clearReplyTarget();
      } catch (e, st) {
        debugPrint('send quote failed: $e\n$st');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('引用发送失败：$e')));
      }
      return;
    }
    await ref.read(imOutboundProvider).chatSendTextAndClearDraft(_cid, trimmed);
  }

  Future<void> _handleOutboundEmoji(String packKey) async {
    final key = packKey.trim();
    if (key.isEmpty) return;
    if (_replyTargetMessageKey != null) {
      _clearReplyTarget();
    }
    await ref.read(messageProvider(_cid).notifier).sendEmoji(key);
  }

  Future<void> _handleOutboundSticker(ComposerStickerPick pick) async {
    if (_replyTargetMessageKey != null) {
      _clearReplyTarget();
    }
    await ref
        .read(messageProvider(_cid).notifier)
        .sendSticker(
          stickerId: pick.stickerId,
          packageId: pick.packageId,
          url: pick.assetPath,
          width: 120,
          height: 120,
          stickerFormat: 'webp',
        );
  }

  Future<void> _handleOutboundRichDoc(
    ChatRichDocInputFormat format,
    String source,
  ) async {
    if (_replyTargetMessageKey != null) {
      _clearReplyTarget();
    }
    try {
      await ref
          .read(imOutboundProvider)
          .chatSendRichDoc(
            _cid,
            format: _richDocWireFormat(format),
            source: source,
          );
    } catch (e, st) {
      debugPrint('send rich doc failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('富文本发送失败：$e')));
    }
  }

  String _richDocWireFormat(ChatRichDocInputFormat format) {
    return switch (format) {
      ChatRichDocInputFormat.markdown => 'markdown',
      ChatRichDocInputFormat.html => 'html',
      ChatRichDocInputFormat.docJson => 'docJson',
    };
  }

  Future<void> _handleOutboundBusinessMessage(
    ChatBusinessMessageKind kind,
  ) async {
    if (_replyTargetMessageKey != null) {
      _clearReplyTarget();
    }
    try {
      switch (kind) {
        case ChatBusinessMessageKind.location:
          await _showSendLocationDialog();
        case ChatBusinessMessageKind.contactCard:
          await _showSendContactCardDialog();
        case ChatBusinessMessageKind.schedule:
          await _showSendScheduleDialog();
        case ChatBusinessMessageKind.task:
          await _showSendTaskDialog();
      }
    } catch (e, st) {
      debugPrint('send business message failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('发送失败：$e')));
    }
  }

  String _newBusinessId(String prefix) {
    final me = ref.read(currentUserProvider)?.userId.trim() ?? 'local';
    final ts = DateTime.now().microsecondsSinceEpoch;
    return '${prefix}_${me.hashCode.abs().toRadixString(16)}_$ts';
  }

  List<String> _splitUserIds(String raw) => raw
      .split(RegExp(r'[,，\s]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Map<String, String>? _parseStringMapLines(String raw) {
    final out = <String, String>{};
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      final eq = t.indexOf('=');
      final col = t.indexOf(':');
      var sep = -1;
      if (eq >= 0 && (col < 0 || eq <= col)) {
        sep = eq;
      } else if (col >= 0) {
        sep = col;
      }
      if (sep < 0) continue;
      final key = t.substring(0, sep).trim();
      final value = t.substring(sep + 1).trim();
      if (key.isNotEmpty) out[key] = value;
    }
    return out.isEmpty ? null : out;
  }

  List<Map<String, dynamic>> _parseImageGroupLines(String raw) {
    final out = <Map<String, dynamic>>[];
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      final pipe = t.indexOf('|');
      final imageId = pipe >= 0 ? t.substring(0, pipe).trim() : '';
      final url = pipe >= 0 ? t.substring(pipe + 1).trim() : t;
      out.add({
        'uuid': '',
        'imageId': imageId.isNotEmpty || !url.startsWith('http')
            ? (imageId.isNotEmpty ? imageId : url)
            : '',
        'url': url.startsWith('http') ? url : '',
        'mimeType': '',
        'size': 0,
        'width': 0,
        'height': 0,
        'format': 0,
        'animated': false,
      });
    }
    return out;
  }

  String? _nonEmpty(String? value) {
    final t = (value ?? '').trim();
    return t.isEmpty ? null : t;
  }

  int? _intOrNull(String? value) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  double _requiredDouble(Map<String, String> values, String key, String label) {
    final v = double.tryParse((values[key] ?? '').trim());
    if (v == null) throw StateError('$label 必须为数字');
    return v;
  }

  ({String op, Map<String, dynamic> params}) _buildSdkMessageParams(
    SdkMessageBuildKind kind,
    Map<String, String> values,
  ) {
    switch (kind) {
      case SdkMessageBuildKind.threadReply:
        return (
          op: 'create_thread_reply',
          params: {
            'threadId': (values['threadId'] ?? '').trim(),
            'text': values['text'] ?? '',
          },
        );
      case SdkMessageBuildKind.imageGroup:
        final images = _parseImageGroupLines(values['imageLines'] ?? '');
        if (images.isEmpty) throw StateError('请至少填写一行图片');
        return (
          op: 'create_with_content',
          params: {
            'content': {
              'contentType': 'image_group',
              'images': images,
              'description': (values['description'] ?? '').trim(),
              'metadata':
                  _parseStringMapLines(values['metadata'] ?? '') ??
                  <String, String>{},
            },
          },
        );
      case SdkMessageBuildKind.location:
        return (
          op: 'create_location',
          params: {
            'longitude': _requiredDouble(values, 'longitude', '经度'),
            'latitude': _requiredDouble(values, 'latitude', '纬度'),
            if (_nonEmpty(values['title']) != null)
              'title': _nonEmpty(values['title']),
            if (_nonEmpty(values['address']) != null)
              'address': _nonEmpty(values['address']),
            if (_intOrNull(values['zoom']) != null)
              'zoom': _intOrNull(values['zoom']),
            if (_nonEmpty(values['snapshotUrl']) != null)
              'snapshotUrl': _nonEmpty(values['snapshotUrl']),
            if (_nonEmpty(values['snapshotLocalPath']) != null)
              'snapshotLocalPath': _nonEmpty(values['snapshotLocalPath']),
          },
        );
      case SdkMessageBuildKind.card:
        return (op: 'create_card', params: _compact(values));
      case SdkMessageBuildKind.sticker:
        return (
          op: 'create_sticker',
          params: {
            'stickerId': (values['stickerId'] ?? '').trim(),
            if (_nonEmpty(values['packageId']) != null)
              'packageId': _nonEmpty(values['packageId']),
            if (_nonEmpty(values['url']) != null)
              'url': _nonEmpty(values['url']),
            if (_intOrNull(values['width']) != null)
              'width': _intOrNull(values['width']),
            if (_intOrNull(values['height']) != null)
              'height': _intOrNull(values['height']),
            if (_nonEmpty(values['format']) != null)
              'format': _nonEmpty(values['format']),
          },
        );
      case SdkMessageBuildKind.linkCard:
        return (op: 'create_link_card', params: _compact(values));
      case SdkMessageBuildKind.miniProgram:
        return (
          op: 'create_mini_program',
          params: {
            'appId': (values['appId'] ?? '').trim(),
            if (_nonEmpty(values['title']) != null)
              'title': _nonEmpty(values['title']),
            if (_nonEmpty(values['path']) != null)
              'path': _nonEmpty(values['path']),
            if (_nonEmpty(values['thumbnailUrl']) != null)
              'thumbnailUrl': _nonEmpty(values['thumbnailUrl']),
            if (_parseStringMapLines(values['extra'] ?? '') != null)
              'extra': _parseStringMapLines(values['extra'] ?? ''),
          },
        );
      case SdkMessageBuildKind.notification:
        return (op: 'create_notification', params: _compact(values));
      case SdkMessageBuildKind.vote:
        final options = (values['options'] ?? '')
            .split(RegExp(r'\r?\n'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (options.length < 2) throw StateError('投票至少需要 2 个选项');
        return (
          op: 'create_vote',
          params: {
            'voteId': (values['voteId'] ?? '').trim(),
            'title': (values['title'] ?? '').trim(),
            'options': options,
            if (_splitUserIds(values['participantUserIds'] ?? '').isNotEmpty)
              'participantUserIds': _splitUserIds(
                values['participantUserIds'] ?? '',
              ),
          },
        );
      case SdkMessageBuildKind.task:
        return (
          op: 'create_task',
          params: {
            'taskId': (values['taskId'] ?? '').trim(),
            'title': (values['title'] ?? '').trim(),
            if (_nonEmpty(values['status']) != null)
              'status': _nonEmpty(values['status']),
            if (_splitUserIds(values['participantUserIds'] ?? '').isNotEmpty)
              'participantUserIds': _splitUserIds(
                values['participantUserIds'] ?? '',
              ),
          },
        );
      case SdkMessageBuildKind.schedule:
        final startDelta = _intOrNull(values['startAfterMinutes']) ?? 60;
        final duration = _intOrNull(values['durationMinutes']) ?? 60;
        final start = DateTime.now().add(Duration(minutes: startDelta));
        final end = start.add(Duration(minutes: duration <= 0 ? 60 : duration));
        return (
          op: 'create_schedule',
          params: {
            'scheduleId': (values['scheduleId'] ?? '').trim(),
            'title': (values['title'] ?? '').trim(),
            'startTimeMs': start.millisecondsSinceEpoch,
            'endTimeMs': end.millisecondsSinceEpoch,
            if (_splitUserIds(values['participantUserIds'] ?? '').isNotEmpty)
              'participantUserIds': _splitUserIds(
                values['participantUserIds'] ?? '',
              ),
          },
        );
      case SdkMessageBuildKind.announcement:
        return (op: 'create_announcement', params: _compact(values));
      case SdkMessageBuildKind.custom:
        return (
          op: 'create_custom',
          params: {'type': (values['type'] ?? '').trim()},
        );
      case SdkMessageBuildKind.placeholder:
        return (
          op: 'create_placeholder',
          params: {'reason': (values['reason'] ?? '').trim()},
        );
    }
  }

  Map<String, dynamic> _compact(Map<String, String> values) {
    final out = <String, dynamic>{};
    for (final e in values.entries) {
      final v = e.value.trim();
      if (v.isNotEmpty) out[e.key] = v;
    }
    return out;
  }

  Widget _businessTextField(
    TextEditingController controller, {
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 15,
          height: 1.25,
          fontWeight: FontWeight.w500,
          color: FlareThemeTokens.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon == null
              ? null
              : Icon(icon, size: 19, color: FlareThemeTokens.textSecondary),
          filled: true,
          fillColor: FlareThemeTokens.bgSecondary,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: FlareThemeTokens.textSecondary,
          ),
          hintStyle: TextStyle(
            fontSize: 14,
            color: FlareThemeTokens.textSecondary.withValues(alpha: 0.78),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: FlareThemeTokens.borderSecondary,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: FlareThemeTokens.borderSecondary,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: FlareThemeTokens.primary,
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _showBusinessMessageDialog({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required List<Widget> fields,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      builder: (ctx) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: FlareThemeTokens.bgPrimary,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 28,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(icon, color: accent, size: 25),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 21,
                                        height: 1.2,
                                        fontWeight: FontWeight.w800,
                                        color: FlareThemeTokens.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        height: 1.25,
                                        color: FlareThemeTokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          ...fields,
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: FlareThemeTokens.primary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text(
                                    '取消',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: FlareThemeTokens.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    '发送',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    return ok == true;
  }

  Future<void> _showSendLocationDialog() async {
    final picked = await showLocationPickerSheet(context);
    if (picked == null || !mounted) return;
    await ref
        .read(imOutboundProvider)
        .chatSendLocation(
          _cid,
          latitude: picked.latitude,
          longitude: picked.longitude,
          title: picked.title,
          address: picked.address,
          zoom: picked.zoom,
          snapshotUrl: picked.snapshotUrl,
        );
  }

  Future<void> _showSendContactCardDialog() async {
    final me = ref.read(currentUserProvider);
    final id = TextEditingController(text: me?.userId ?? '');
    final name = TextEditingController(
      text: me?.displayName ?? me?.userId ?? '',
    );
    final subtitle = TextEditingController(text: 'Flare IM 用户');
    final avatar = TextEditingController(text: me?.avatar ?? '');
    try {
      final ok = await _showBusinessMessageDialog(
        title: '发送名片',
        subtitle: '发送联系人资料，便于对方快速识别',
        icon: Icons.badge_rounded,
        accent: FlareThemeTokens.primaryActive,
        fields: [
          _businessTextField(
            id,
            label: '用户 ID',
            icon: Icons.alternate_email_rounded,
          ),
          _businessTextField(
            name,
            label: '显示名称',
            icon: Icons.person_outline_rounded,
          ),
          _businessTextField(
            subtitle,
            label: '副标题',
            icon: Icons.short_text_rounded,
          ),
          _businessTextField(
            avatar,
            label: '头像 URL（可选）',
            hint: 'https://...',
            icon: Icons.image_outlined,
          ),
        ],
      );
      if (!ok) return;
      await ref
          .read(imOutboundProvider)
          .chatSendContactCard(
            _cid,
            id: id.text,
            cardType: 'user',
            title: name.text,
            subtitle: subtitle.text,
            avatar: avatar.text,
          );
    } finally {
      id.dispose();
      name.dispose();
      subtitle.dispose();
      avatar.dispose();
    }
  }

  Future<void> _showSendTaskDialog() async {
    final title = TextEditingController(text: '跟进本次沟通');
    final status = TextEditingController(text: 'todo');
    final participants = TextEditingController();
    try {
      final ok = await _showBusinessMessageDialog(
        title: '发送任务',
        subtitle: '创建一个待办任务卡片并发送到会话',
        icon: Icons.task_alt_rounded,
        accent: FlareThemeTokens.robot,
        fields: [
          _businessTextField(
            title,
            label: '任务标题',
            icon: Icons.check_circle_outline_rounded,
          ),
          _businessTextField(
            status,
            label: '状态',
            hint: 'todo / doing / done',
            icon: Icons.flag_outlined,
          ),
          _businessTextField(
            participants,
            label: '参与人 ID',
            hint: '用逗号或空格分隔',
            icon: Icons.group_outlined,
          ),
        ],
      );
      if (!ok) return;
      await ref
          .read(imOutboundProvider)
          .chatSendTask(
            _cid,
            taskId: _newBusinessId('task'),
            title: title.text,
            status: status.text,
            participantUserIds: _splitUserIds(participants.text),
          );
    } finally {
      title.dispose();
      status.dispose();
      participants.dispose();
    }
  }

  Future<void> _showSendScheduleDialog() async {
    final title = TextEditingController(text: '沟通会议');
    final startAfterMinutes = TextEditingController(text: '30');
    final durationMinutes = TextEditingController(text: '60');
    final participants = TextEditingController();
    try {
      final ok = await _showBusinessMessageDialog(
        title: '发送日程',
        subtitle: '创建一条会议或提醒日程并同步给成员',
        icon: Icons.calendar_month_rounded,
        accent: FlareThemeTokens.important,
        fields: [
          _businessTextField(
            title,
            label: '日程标题',
            icon: Icons.event_note_outlined,
          ),
          _businessTextField(
            startAfterMinutes,
            label: '多少分钟后开始',
            icon: Icons.schedule_rounded,
            keyboardType: TextInputType.number,
          ),
          _businessTextField(
            durationMinutes,
            label: '持续分钟数',
            icon: Icons.timelapse_rounded,
            keyboardType: TextInputType.number,
          ),
          _businessTextField(
            participants,
            label: '参与人 ID',
            hint: '用逗号或空格分隔',
            icon: Icons.group_outlined,
          ),
        ],
      );
      if (!ok) return;
      final startDelta = int.tryParse(startAfterMinutes.text.trim()) ?? 30;
      final duration = int.tryParse(durationMinutes.text.trim()) ?? 60;
      final start = DateTime.now().add(Duration(minutes: startDelta));
      final end = start.add(Duration(minutes: duration <= 0 ? 60 : duration));
      await ref
          .read(imOutboundProvider)
          .chatSendSchedule(
            _cid,
            scheduleId: _newBusinessId('schedule'),
            title: title.text,
            startTimeMs: start.millisecondsSinceEpoch,
            endTimeMs: end.millisecondsSinceEpoch,
            participantUserIds: _splitUserIds(participants.text),
          );
    } finally {
      title.dispose();
      startAfterMinutes.dispose();
      durationMinutes.dispose();
      participants.dispose();
    }
  }

  Future<void> _pickAndSendImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    await ref.read(messageProvider(_cid).notifier).sendImageByPath(picked.path);
  }

  Future<void> _pickAndSendVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    await ref.read(messageProvider(_cid).notifier).sendVideoByPath(picked.path);
  }

  Future<void> _pickAndSendFile({FileType type = FileType.any}) async {
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowMultiple: false,
      withData: false,
    );
    final path = result?.files.firstOrNull?.path?.trim() ?? '';
    if (path.isEmpty) return;
    await ref.read(messageProvider(_cid).notifier).sendFileByPath(path);
  }

  Future<void> _pickAndSendAudio() async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mic),
              title: const Text('按住录音'),
              subtitle: const Text('松开发送，上滑取消'),
              onTap: () => Navigator.of(ctx).pop('record_hold'),
            ),
            ListTile(
              leading: const Icon(Icons.library_music),
              title: const Text('选择音频文件'),
              onTap: () => Navigator.of(ctx).pop('pick'),
            ),
          ],
        ),
      ),
    );
    if (mode == null) return;
    if (mode == 'record_hold') {
      await _recordAndSendAudio();
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
      withData: false,
    );
    final path = result?.files.firstOrNull?.path?.trim() ?? '';
    if (path.isEmpty) return;
    await ref.read(messageProvider(_cid).notifier).sendAudioByPath(path);
  }

  Future<void> _recordAndSendAudio() async {
    final recorder = AudioRecorder();
    String? recordedPath;
    bool isRecording = false;
    bool cancelOnRelease = false;
    double startGlobalY = 0;
    try {
      final hasPermission = await recorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('没有麦克风权限')));
        return;
      }

      final tmp = await getTemporaryDirectory();
      final dir = Directory('${tmp.path}/flare_rec');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final path =
          '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> startRecord(LongPressStartDetails details) async {
              if (isRecording) return;
              startGlobalY = details.globalPosition.dy;
              cancelOnRelease = false;
              await recorder.start(
                const RecordConfig(
                  encoder: AudioEncoder.aacLc,
                  bitRate: 64000,
                  sampleRate: 44100,
                ),
                path: path,
              );
              setDialogState(() {
                isRecording = true;
              });
            }

            Future<void> finishRecord() async {
              if (!isRecording) return;
              final out = await recorder.stop();
              setDialogState(() {
                isRecording = false;
              });
              if (cancelOnRelease) {
                final p = (out ?? '').trim();
                if (p.isNotEmpty) {
                  final f = File(p);
                  if (f.existsSync()) {
                    f.deleteSync();
                  }
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
                return;
              }
              recordedPath = (out ?? '').trim();
              if (ctx.mounted) Navigator.of(ctx).pop();
            }

            return AlertDialog(
              title: const Text('按住录音'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onLongPressStart: startRecord,
                    onLongPressMoveUpdate: (d) {
                      if (!isRecording) return;
                      final shouldCancel =
                          (startGlobalY - d.globalPosition.dy) > 70;
                      if (shouldCancel != cancelOnRelease) {
                        setDialogState(() {
                          cancelOnRelease = shouldCancel;
                        });
                      }
                    },
                    onLongPressEnd: (_) async {
                      await finishRecord();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 160,
                      height: 160,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cancelOnRelease
                            ? Colors.red.withValues(alpha: 0.2)
                            : Theme.of(
                                ctx,
                              ).colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(80),
                        border: Border.all(
                          color: cancelOnRelease
                              ? Colors.red
                              : Theme.of(ctx).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        isRecording
                            ? (cancelOnRelease ? '松开取消' : '松开发送')
                            : '长按开始录音',
                        style: TextStyle(
                          color: cancelOnRelease
                              ? Colors.red
                              : Theme.of(ctx).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isRecording ? '上滑取消录音' : '请长按按钮开始录音',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    if (isRecording) {
                      cancelOnRelease = true;
                      await finishRecord();
                    } else if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        ),
      );
      final trimmed = (recordedPath ?? '').trim();
      if (trimmed.isNotEmpty && mounted) {
        await ref.read(messageProvider(_cid).notifier).sendAudioByPath(trimmed);
      }
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('录音插件未正确加载，请重新构建后再试')));
    } on PlatformException catch (e) {
      if (!mounted) return;
      final msg = (e.message ?? '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isEmpty ? '录音失败，请稍后重试' : '录音失败：$msg')),
      );
    } finally {
      await recorder.dispose();
    }
  }

  Future<void> _handlePickMedia(ComposerPickMediaKind kind) async {
    try {
      switch (kind) {
        case ComposerPickMediaKind.image:
          await _pickAndSendImage();
          break;
        case ComposerPickMediaKind.video:
          await _pickAndSendVideo();
          break;
        case ComposerPickMediaKind.imageOrVideo:
          final result = await FilePicker.platform.pickFiles(
            type: FileType.media,
            allowMultiple: false,
            withData: false,
          );
          final file = result?.files.firstOrNull;
          final path = file?.path?.trim() ?? '';
          if (path.isEmpty) return;
          final ext = (file?.extension ?? '').toLowerCase();
          final isVideo = const {
            'mp4',
            'mov',
            'm4v',
            'avi',
            'webm',
            'mkv',
          }.contains(ext);
          if (isVideo) {
            await ref
                .read(messageProvider(_cid).notifier)
                .sendVideoByPath(path);
          } else {
            await ref
                .read(messageProvider(_cid).notifier)
                .sendImageByPath(path);
          }
          break;
        case ComposerPickMediaKind.audio:
          await _pickAndSendAudio();
          break;
        case ComposerPickMediaKind.file:
        case ComposerPickMediaKind.folder:
          await _pickAndSendFile();
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('发送失败: $e')));
    }
  }

  Future<void> _editOwnMessage(Message message) async {
    final content = message.content;
    if (content is TextContent) {
      await _editOwnTextMessage(message, content.text);
      return;
    }
    if (content is RichDocContent) {
      await _editOwnRichDocMessage(message, content);
    }
  }

  Future<void> _editOwnTextMessage(Message message, String text) async {
    final controller = TextEditingController(text: text);
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('编辑消息'),
              content: ExtendedTextField(
                controller: controller,
                maxLines: 4,
                specialTextSpanBuilder:
                    PlainTextMarkdownDetect.isMarkdown(controller.text)
                    ? null
                    : ComposerEmojiSpanBuilder(
                        inlineSize: 15 * 1.72,
                        localeTag: Localizations.maybeLocaleOf(
                          dialogCtx,
                        )?.toLanguageTag(),
                      ),
                onChanged: (_) => setDialogState(() {}),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        ),
      );
      if (ok != true || !mounted) return;
      final next = controller.text.trim();
      if (next.isEmpty || next == text) return;
      await ref
          .read(imOutboundProvider)
          .chatEditOwnText(_cid, message.serverId, next);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _editOwnRichDocMessage(
    Message message,
    RichDocContent content,
  ) async {
    final initialDocJson = content.docJson.trim();
    final initialPlain = content.plainText.trim();
    final initialFormat = initialDocJson.isNotEmpty
        ? ChatRichDocInputFormat.docJson
        : ChatRichDocInputFormat.markdown;
    final controller = TextEditingController(
      text: initialDocJson.isNotEmpty ? initialDocJson : initialPlain,
    );
    var selected = initialFormat;
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final label = switch (selected) {
              ChatRichDocInputFormat.markdown => 'Markdown',
              ChatRichDocInputFormat.html => 'HTML',
              ChatRichDocInputFormat.docJson => 'Doc JSON',
            };
            return AlertDialog(
              title: const Text('编辑富文本'),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SegmentedButton<ChatRichDocInputFormat>(
                        segments: const [
                          ButtonSegment(
                            value: ChatRichDocInputFormat.markdown,
                            label: Text('Markdown'),
                          ),
                          ButtonSegment(
                            value: ChatRichDocInputFormat.html,
                            label: Text('HTML'),
                          ),
                          ButtonSegment(
                            value: ChatRichDocInputFormat.docJson,
                            label: Text('JSON'),
                          ),
                        ],
                        selected: {selected},
                        showSelectedIcon: false,
                        onSelectionChanged: (next) {
                          setDialogState(() => selected = next.first);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      maxLines: 10,
                      minLines: 6,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: label,
                        filled: true,
                        fillColor: FlareThemeTokens.bgSecondary,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        ),
      );
      if (ok != true || !mounted) return;
      final next = controller.text.trim();
      if (next.isEmpty) return;
      if (selected == initialFormat &&
          next == (initialDocJson.isNotEmpty ? initialDocJson : initialPlain)) {
        return;
      }
      await ref
          .read(imOutboundProvider)
          .chatEditOwnRichDoc(
            _cid,
            message.serverId,
            format: _richDocWireFormat(selected),
            source: next,
          );
    } catch (e, st) {
      debugPrint('edit rich doc failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('富文本编辑失败：$e')));
    } finally {
      controller.dispose();
    }
  }

  List<Message> _selectedMessages() {
    if (_multiSelectKeys.isEmpty) return const [];
    final list = ref.read(messageProvider(_cid));
    final out = <Message>[];
    for (final key in _multiSelectKeys) {
      final m = messageRowViewModelForKey(list, key)?.message;
      if (m != null) out.add(m);
    }
    return out;
  }

  String _messageOperationId(Message message) {
    final sid = message.serverId.trim();
    if (sid.isNotEmpty) return sid;
    return message.clientMsgId.trim();
  }

  Future<void> _showSdkMessageBuildMenu() async {
    _dismissComposerMoreGrid();
    final draft = await showSdkMessageBuildSheet(context);
    if (draft == null || !mounted) return;
    try {
      final request = _buildSdkMessageParams(draft.kind, draft.values);
      await ref
          .read(imOutboundProvider)
          .chatSendMessageBuild(_cid, request.op, request.params);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已发送 SDK 消息')));
    } catch (e, st) {
      debugPrint('send sdk message build failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('发送失败：$e')));
    }
  }

  Future<void> _forwardSelected({required bool merge}) async {
    final selected = _selectedMessages();
    final ids = selected
        .map(_messageOperationId)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有可转发的消息')));
      return;
    }
    try {
      await ref
          .read(imOutboundProvider)
          .chatForwardMessages(
            _cid,
            messageIds: ids,
            merge: merge,
            title: merge ? '合并转发 ${ids.length} 条' : '转发消息',
          );
      _exitMultiSelect();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已转发到当前会话')));
    } catch (e, st) {
      debugPrint('forward selected failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('转发失败：$e')));
    }
  }

  Future<void> _deleteSelectedForSelf() async {
    final ids = _selectedMessages()
        .map(_messageOperationId)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) return;
    try {
      for (final id in ids) {
        await ref.read(imOutboundProvider).chatDeleteForSelf(_cid, id);
      }
      _exitMultiSelect();
    } catch (e, st) {
      debugPrint('delete selected failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final outbound = ref.read(imOutboundProvider);
    ref.listen<ChatOutboundEvent?>(chatOutboundProvider(_cid), (prev, next) {
      if (next == null) return;
      final bus = ref.read(chatOutboundProvider(_cid).notifier);
      switch (next) {
        case ChatOutboundSendText(:final text):
          unawaited(_handleOutboundSendText(text));
        case ChatOutboundSendEmojiPackKey(:final packKey):
          unawaited(_handleOutboundEmoji(packKey));
        case ChatOutboundSendSticker(:final pick):
          unawaited(_handleOutboundSticker(pick));
        case ChatOutboundSendRichDoc(:final format, :final source):
          unawaited(_handleOutboundRichDoc(format, source));
        case ChatOutboundRequestBusinessMessage(:final kind):
          unawaited(_handleOutboundBusinessMessage(kind));
      }
      bus.clear();
    });

    final conversationList = ref.watch(conversationProvider);
    final selectedConversation = ref.watch(selectedConversationProvider);
    final routeSelectedConversation =
        selectedConversation?.conversationId.trim() == _cid
        ? selectedConversation
        : null;
    final conversation =
        routeSelectedConversation ?? conversationById(conversationList, _cid);
    final keysSignal = ref.watch(
      messageProvider(_cid).select(messageListKeysSignal),
    );
    _followTimelineTailIfNeeded(keysSignal);
    final me = ref.watch(currentUserProvider)?.userId ?? '';
    final typingCount = ref.watch(
      typingProvider(_cid).select(
        (t) => t.typingUserIds
            .where((uid) => uid.trim().isNotEmpty && uid != me)
            .length,
      ),
    );
    final conn = ref.watch(connectionStateProvider);

    final title = conversation?.displayTitle.trim().isNotEmpty == true
        ? conversation!.displayTitle
        : '聊天';
    final peerUserId =
        conversation?.conversationType == im.ConversationType.single
        ? (conversation?.peerUserId ?? '').trim()
        : '';
    final peerOnline = peerUserId.isEmpty
        ? null
        : ref.watch(userOnlineProvider(peerUserId));
    final callEnabled = ref.watch(callKitEnabledProvider);
    final callController = ref.watch(callControllerProvider);
    if (peerUserId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_ensurePeerPresence(peerUserId));
      });
    }
    final typingText = typingCount <= 0
        ? ''
        : typingCount == 1
        ? '对方正在输入…'
        : '$typingCount人正在输入…';

    final i18n = ref.watch(flareMessagesProvider);
    final canPop = !widget.embedInWorkbench && Navigator.canPop(context);
    final chatCanvas = Theme.of(context).brightness == Brightness.light
        ? FlareImDesign.chatMessageListCanvas
        : FlareThemeTokens.chatCanvas;

    return Scaffold(
      backgroundColor: chatCanvas,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: FlareThemeTokens.bgPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: FlareThemeTokens.textPrimary,
        shape: const Border(
          bottom: BorderSide(color: FlareThemeTokens.borderSecondary, width: 1),
        ),
        leading: _multiSelectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: '退出多选',
                onPressed: () {
                  _dismissComposerMoreGrid();
                  _exitMultiSelect();
                },
              )
            : canPop
            ? IconButton(
                icon: const BackButtonIcon(),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () {
                  _dismissComposerMoreGrid();
                  _flushComposerDraftNow();
                  Navigator.of(context).maybePop();
                },
              )
            : null,
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _dismissComposerMoreGrid,
          child: _multiSelectMode
              ? Text(
                  i18n.chat.multiSelectCountOf(_multiSelectKeys.length),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: FlareThemeTokens.textPrimary,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: FlareThemeTokens.textPrimary,
                            ),
                          ),
                        ),
                        if (peerOnline != null) ...[
                          const SizedBox(width: 6),
                          _PresencePill(online: peerOnline),
                        ],
                      ],
                    ),
                    if (typingText.isNotEmpty)
                      Text(
                        typingText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: FlareThemeTokens.textSecondary,
                        ),
                      ),
                  ],
                ),
        ),
        actions: _multiSelectMode
            ? [
                IconButton(
                  tooltip: '单条转发',
                  icon: const Icon(Icons.redo_rounded),
                  onPressed: _multiSelectKeys.isEmpty
                      ? null
                      : () => unawaited(_forwardSelected(merge: false)),
                ),
                IconButton(
                  tooltip: '合并转发',
                  icon: const Icon(Icons.library_books_outlined),
                  onPressed: _multiSelectKeys.length < 2
                      ? null
                      : () => unawaited(_forwardSelected(merge: true)),
                ),
                IconButton(
                  tooltip: '仅自己删除',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: _multiSelectKeys.isEmpty
                      ? null
                      : () => unawaited(_deleteSelectedForSelf()),
                ),
              ]
            : [
                if (callEnabled &&
                    callController != null &&
                    peerUserId.isNotEmpty)
                  CallEntryActions(
                    controller: callController,
                    conversationId: _cid,
                    peerUserId: peerUserId,
                    iconColor: FlareThemeTokens.textSecondary,
                  ),
                IconButton(
                  tooltip: 'SDK 消息类型',
                  icon: const Icon(
                    Icons.hub_outlined,
                    color: FlareThemeTokens.textSecondary,
                  ),
                  onPressed: () => unawaited(_showSdkMessageBuildMenu()),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_horiz,
                    color: FlareThemeTokens.textSecondary,
                  ),
                  onOpened: _dismissComposerMoreGrid,
                  onSelected: (value) async {
                    switch (value) {
                      case 'details':
                        await _openConversationDetails();
                        break;
                      case 'search':
                        _openMessageSearch();
                        break;
                      case 'sync_meta':
                        await _syncConversationMeta();
                        break;
                      case 'recall_last':
                        final messages = ref.read(messageProvider(_cid));
                        final own = messages
                            .where((m) => m.senderId == me)
                            .firstOrNull;
                        if (own != null && own.serverId.isNotEmpty) {
                          await outbound.chatRecall(_cid, own.serverId);
                        }
                        break;
                      case 'pull_server':
                        await _onRefresh();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'details',
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.info_outline_rounded),
                        title: Text(i18n.chat.conversationDetails),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'search',
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.search),
                        title: Text(i18n.chat.searchMessages),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'sync_meta',
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.sync_outlined),
                        title: Text(i18n.chat.syncConversation),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'pull_server',
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.cloud_download_outlined),
                        title: Text(i18n.chat.pullFromServer),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'recall_last',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.undo),
                        title: Text('撤回最近一条（自己）'),
                      ),
                    ),
                  ],
                ),
              ],
      ),
      body: Column(
        children: [
          // 与 Tauri Chat 状态条一致：仅在非稳定已连接时展示（Ready 时不占位）
          if (conn != im.ConnectionState.connected)
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _dismissComposerMoreGrid(),
              child: _connectionStatusBanner(conn),
            ),
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _dismissComposerMoreGrid(),
              child: ColoredBox(
                color: chatCanvas,
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: keysSignal.orderedKeys.isEmpty
                      ? CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 120),
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 64,
                                    color: FlareImDesign.mutedForeground
                                        .withValues(alpha: 0.45),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    '暂无消息',
                                    style: TextStyle(
                                      color: FlareImDesign.mutedForeground,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '下拉同步',
                                    style: TextStyle(
                                      color: FlareImDesign.mutedForeground
                                          .withValues(alpha: 0.85),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : CustomScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                FlareImDesign.messageBubbleListHorizontalPad,
                                8,
                                FlareImDesign.messageBubbleListHorizontalPad,
                                20,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final key = keysSignal.orderedKeys[index];
                                  return ChatMessageListItem(
                                    key: ValueKey<String>(key),
                                    conversationId: _cid,
                                    messageKey: key,
                                    currentUserId: me,
                                    onEditOwnText: _editOwnMessage,
                                    onStartReply: _startReplyToMessageKey,
                                    multiSelectMode: _multiSelectMode,
                                    multiSelectSelected: _multiSelectKeys
                                        .contains(key),
                                    onToggleMultiSelect: () =>
                                        _toggleMultiSelectKey(key),
                                    onStartMultiSelect: _startMultiSelectWith,
                                  );
                                }, childCount: keysSignal.orderedKeys.length),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          KeyedSubtree(
            key: ValueKey(_cid),
            child: MessageComposer(
              key: _composerKey,
              conversationId: _cid,
              composeTargetName:
                  conversation?.displayTitle.trim().isNotEmpty == true
                  ? conversation!.displayTitle.trim()
                  : null,
              initialText: conversation?.draft,
              replyQuote: _replyQuoteSnapshot,
              onClearReply: _replyQuoteSnapshot != null
                  ? _clearReplyTarget
                  : null,
              onTypingChanged: (v) {
                outbound.chatSetTyping(_cid, v);
              },
              onDraftChanged: (t) {
                unawaited(
                  outbound.chatSaveDraft(_cid, t.trim().isEmpty ? null : t),
                );
              },
              onPickMedia: (kind) {
                unawaited(_handlePickMedia(kind));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _connectionStatusBanner(im.ConnectionState conn) {
    final i18n = ref.read(flareMessagesProvider).chat;
    final ok = conn == im.ConnectionState.connected;
    final reconnecting = conn == im.ConnectionState.reconnecting;
    final connecting = conn == im.ConnectionState.connecting;
    final fg = ok
        ? FlareThemeTokens.chatConnectionBannerFg
        : FlareThemeTokens.textSecondary;
    final String text;
    if (ok) {
      text = i18n.connectionStable;
    } else if (reconnecting) {
      text =
          '${ref.read(flareMessagesProvider).connection.reconnecting} · ${i18n.connectionSendingHint}';
    } else if (connecting) {
      text = '${i18n.connectionConnecting} · ${i18n.connectionSendingHint}';
    } else {
      text = '${i18n.connectionDisconnected} · ${i18n.connectionSendingHint}';
    }
    return Material(
      color: FlareThemeTokens.chatConnectionBannerBg,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (reconnecting || connecting) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresencePill extends StatelessWidget {
  const _PresencePill({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? const Color(0xFF07C160) : const Color(0xFFB2B2B2);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          online ? '在线' : '离线',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: FlareThemeTokens.textSecondary,
          ),
        ),
      ],
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
