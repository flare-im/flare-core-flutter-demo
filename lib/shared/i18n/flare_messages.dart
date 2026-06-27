import 'package:flare_im/shared/i18n/flare_locale.dart';

/// 与 Vue `flareMessages` 核心键对齐的文案树（登录 / 会话 / 聊天 / 连接 / 设置）。
final class FlareMessages {
  const FlareMessages._(this.locale, this._root);

  final FlareLocale locale;
  final Map<String, dynamic> _root;

  factory FlareMessages.of(FlareLocale locale) {
    return FlareMessages._(
      locale,
      _catalog[locale] ?? _catalog[FlareLocale.zhCn]!,
    );
  }

  String t(String path) {
    final parts = path.split('.');
    Object? node = _root;
    for (final part in parts) {
      if (node is! Map) return path;
      node = node[part];
    }
    if (node is String) return node;
    return path;
  }

  FlareNavCopy get nav => FlareNavCopy(this);
  FlareLoginCopy get login => FlareLoginCopy(this);
  FlareConversationCopy get conversation => FlareConversationCopy(this);
  FlareChatCopy get chat => FlareChatCopy(this);
  FlareConnectionCopy get connection => FlareConnectionCopy(this);
  FlareSettingsCopy get settings => FlareSettingsCopy(this);
  FlareSdkLabCopy get sdkLab => FlareSdkLabCopy(this);
  FlareSearchCopy get search => FlareSearchCopy(this);
  FlareDetailsCopy get details => FlareDetailsCopy(this);
}

final class FlareNavCopy {
  const FlareNavCopy(this._m);
  final FlareMessages _m;
  String get login => _m.t('nav.login');
  String get conversations => _m.t('nav.conversations');
  String get sdkLab => _m.t('nav.sdkLab');
  String get settings => _m.t('nav.settings');
}

final class FlareLoginCopy {
  const FlareLoginCopy(this._m);
  final FlareMessages _m;
  String get brandTitle => _m.t('login.brandTitle');
  String get brandSubtitle => _m.t('login.brandSubtitle');
  String get welcomeTitle => _m.t('login.welcomeTitle');
  String get welcomeSubtitle => _m.t('login.welcomeHint');
  String get welcomeHint => _m.t('login.welcomeHint');
  String get userIdLabel => _m.t('login.userIdLabel');
  String get userIdPlaceholder => _m.t('login.userIdPlaceholder');
  String get serverToggle => _m.t('login.serverToggle');
  String get wsUrlLabel => _m.t('login.wsUrlLabel');
  String get wsUrlInvalid => _m.t('login.wsUrlInvalid');
  String get loginButton => _m.t('login.loginButton');
  String get userIdHint => _m.t('login.userIdHint');
  String get userIdRequired => _m.t('login.userIdRequired');
  String get advancedWsHint => _m.t('login.advancedWsHint');
  String get footerPrimary => _m.t('login.footerPrimary');
  String get footerSecondary => _m.t('login.footerSecondary');
  String get cancel => _m.t('login.cancel');
  String get connected => _m.t('login.connected');
  String get disconnected => _m.t('login.disconnected');
}

final class FlareConversationCopy {
  const FlareConversationCopy(this._m);
  final FlareMessages _m;
  String get title => _m.t('conversation.title');
  String get searchPlaceholder => _m.t('conversation.searchPlaceholder');
  String get pinnedSection => _m.t('conversation.pinnedSection');
  String get allSection => _m.t('conversation.allSection');
  String get emptyTitle => _m.t('conversation.emptyTitle');
  String get emptyHint => _m.t('conversation.emptyHint');
  String get startChat => _m.t('conversation.startChat');
  String get emptySearchTitle => _m.t('conversation.emptySearchTitle');
  String get emptySearchHint => _m.t('conversation.emptySearchHint');
  String get filterAll => _m.t('conversation.filterAll');
  String get filterUnread => _m.t('conversation.filterUnread');
  String get filterMention => _m.t('conversation.filterMention');
  String get filterPinned => _m.t('conversation.filterPinned');
  String get filterMuted => _m.t('conversation.filterMuted');
  String get filterArchived => _m.t('conversation.filterArchived');
  String get filterDraft => _m.t('conversation.filterDraft');
  String get draftPrefix => _m.t('conversation.draftPrefix');
  String get noMessagePreview => _m.t('conversation.noMessagePreview');
  String get previewSticker => _m.t('conversation.previewSticker');
  String get previewEmoji => _m.t('conversation.previewEmoji');
  String get currentAccount => _m.t('conversation.currentAccount');
  String get sdkLabSubtitle => _m.t('conversation.sdkLabSubtitle');
  String get language => _m.t('conversation.language');
  String get languageZh => _m.t('conversation.languageZh');
  String get languageEn => _m.t('conversation.languageEn');
}

final class FlareChatCopy {
  const FlareChatCopy(this._m);
  final FlareMessages _m;
  String composerPlaceholder(String name) =>
      _m.t('chat.composerPlaceholder').replaceAll('{name}', name);
  String get send => _m.t('chat.send');
  String get typing => _m.t('chat.typing');
  String get connectionStable => _m.t('chat.connectionStable');
  String get connectionConnecting => _m.t('chat.connectionConnecting');
  String get connectionDisconnected => _m.t('chat.connectionDisconnected');
  String get connectionSendingHint => _m.t('chat.connectionSendingHint');
  String get searchMessages => _m.t('chat.searchMessages');
  String get syncConversation => _m.t('chat.syncConversation');
  String get pullFromServer => _m.t('chat.pullFromServer');
  String get conversationDetails => _m.t('chat.conversationDetails');
  String get multiSelectCount => _m.t('chat.multiSelectCount');
  String get selectTitle => _m.t('chat.selectTitle');
  String get selectHint => _m.t('chat.selectHint');
  String multiSelectCountOf(int count) =>
      _m.t('chat.multiSelectCount').replaceAll('{count}', '$count');
}

final class FlareConnectionCopy {
  const FlareConnectionCopy(this._m);
  final FlareMessages _m;
  String get syncConversations => _m.t('connection.syncConversations');
  String get syncDetail => _m.t('connection.syncDetail');
  String get reconnecting => _m.t('connection.reconnecting');
  String get disconnected => _m.t('connection.disconnected');
  String get retryHint => _m.t('connection.retryHint');
}

final class FlareSettingsCopy {
  const FlareSettingsCopy(this._m);
  final FlareMessages _m;
  String get title => _m.t('settings.title');
  String get appearance => _m.t('settings.appearance');
  String get language => _m.t('settings.language');
  String get themeSystem => _m.t('settings.themeSystem');
  String get themeLight => _m.t('settings.themeLight');
  String get themeDark => _m.t('settings.themeDark');
}

final class FlareSdkLabCopy {
  const FlareSdkLabCopy(this._m);
  final FlareMessages _m;
  String get title => _m.t('sdkLab.title');
  String get refresh => _m.t('sdkLab.refresh');
}

final class FlareSearchCopy {
  const FlareSearchCopy(this._m);
  final FlareMessages _m;
  String get title => _m.t('search.title');
  String get inConversation => _m.t('search.inConversation');
  String get global => _m.t('search.global');
  String get keywordHint => _m.t('search.keywordHint');
  String get searchButton => _m.t('search.searchButton');
  String get filterLabel => _m.t('search.filterLabel');
  String get filterAll => _m.t('search.filterAll');
  String get filterText => _m.t('search.filterText');
  String get filterMedia => _m.t('search.filterMedia');
  String get filterImage => _m.t('search.filterImage');
  String get filterVideo => _m.t('search.filterVideo');
  String get filterAudio => _m.t('search.filterAudio');
  String get filterFile => _m.t('search.filterFile');
  String get noResults => _m.t('search.noResults');
  String resultCount(int n) =>
      _m.t('search.resultCount').replaceAll('{count}', '$n');
  String get openInChat => _m.t('search.openInChat');
}

final class FlareDetailsCopy {
  const FlareDetailsCopy(this._m);
  final FlareMessages _m;
  String get title => _m.t('details.title');
  String get emptyTitle => _m.t('details.emptyTitle');
  String get emptyHint => _m.t('details.emptyHint');
  String get sync => _m.t('details.sync');
  String get markRead => _m.t('details.markRead');
  String get markUnread => _m.t('details.markUnread');
  String get pin => _m.t('details.pin');
  String get unpin => _m.t('details.unpin');
  String get mute => _m.t('details.mute');
  String get unmute => _m.t('details.unmute');
  String get archive => _m.t('details.archive');
  String get unarchive => _m.t('details.unarchive');
  String get clearHistory => _m.t('details.clearHistory');
  String get delete => _m.t('details.delete');
  String get statusSection => _m.t('details.statusSection');
  String get extensions => _m.t('details.extensions');
  String get openSdkLab => _m.t('details.openSdkLab');
  String get pinTag => _m.t('details.pinTag');
  String get muteTag => _m.t('details.muteTag');
  String get archivedTag => _m.t('details.archivedTag');
  String membersCount(int n) =>
      _m.t('details.membersCount').replaceAll('{count}', '$n');
}

const _catalog = <FlareLocale, Map<String, dynamic>>{
  FlareLocale.zhCn: {
    'nav': {
      'login': '登录',
      'conversations': '消息',
      'sdkLab': 'SDK 能力中心',
      'settings': '设置',
    },
    'login': {
      'brandTitle': 'flare IM',
      'brandSubtitle': '安全、快速的即时通讯',
      'welcomeTitle': '欢迎回来',
      'welcomeHint': '请输入您的用户 ID 完成登录',
      'userIdLabel': '用户 ID',
      'userIdPlaceholder': '请输入用户 ID',
      'userIdHint': '用户 ID 由系统分配，可在账号设置中查看',
      'userIdRequired': '请输入用户 ID',
      'serverToggle': '服务器地址（可选）',
      'wsUrlLabel': 'WebSocket',
      'wsUrlInvalid':
          '请输入 access-gateway 的 WebSocket 地址，例如 ws://127.0.0.1:60051/ws',
      'advancedWsHint': '留空则使用配置文件中的默认地址',
      'loginButton': '立即登录',
      'footerPrimary': 'ID 由管理员分配，可在邀请邮件中查看',
      'footerSecondary': '仅支持 ID 登录 · 安全连接已启用',
      'cancel': '取消',
      'connected': '已连接',
      'disconnected': '未连接',
    },
    'conversation': {
      'title': '消息',
      'searchPlaceholder': '搜索会话、消息预览或用户 ID',
      'pinnedSection': '置顶',
      'allSection': '全部',
      'emptyTitle': '暂无会话',
      'emptyHint': '下拉刷新，或发起一个新的单聊 / 群聊',
      'startChat': '发起会话',
      'emptySearchTitle': '无匹配会话',
      'emptySearchHint': '换个关键词再试试',
      'filterAll': '全部',
      'filterUnread': '未读',
      'filterMention': '@我',
      'filterPinned': '置顶',
      'filterMuted': '免打扰',
      'filterArchived': '归档',
      'filterDraft': '草稿',
      'draftPrefix': '草稿：',
      'noMessagePreview': '暂无消息',
      'previewSticker': '贴纸',
      'previewEmoji': '表情',
      'currentAccount': '当前登录账号',
      'sdkLabSubtitle': '查看连接、能力、媒体缓存和诊断信息',
      'language': '界面语言',
      'languageZh': '简体中文',
      'languageEn': 'English',
    },
    'chat': {
      'composerPlaceholder': '发送给 {name}',
      'send': '发送',
      'typing': '正在输入…',
      'connectionStable': '连接稳定 · 已同步',
      'connectionConnecting': '连接中…',
      'connectionDisconnected': '连接已断开 · 将自动重试',
      'connectionSendingHint': '发送中的消息会在连接就绪后继续',
      'searchMessages': '搜索消息',
      'syncConversation': '同步会话',
      'pullFromServer': '从服务端拉取',
      'conversationDetails': '会话详情',
      'multiSelectCount': '已选择 {count} 条',
      'selectTitle': '选择一个会话',
      'selectHint': '从左侧列表打开聊天，或点击加号发起新会话',
    },
    'connection': {
      'syncConversations': '正在同步会话',
      'syncDetail': '连接建立后会继续同步离线数据',
      'reconnecting': '正在重连服务器',
      'disconnected': '连接已断开',
      'retryHint': '请检查服务地址和网络状态',
    },
    'settings': {
      'title': '设置',
      'appearance': '外观',
      'language': '语言',
      'themeSystem': '跟随系统',
      'themeLight': '浅色',
      'themeDark': '深色',
    },
    'sdkLab': {'title': 'SDK 能力中心', 'refresh': '刷新'},
    'search': {
      'title': '搜索消息',
      'inConversation': '当前会话',
      'global': '全部会话',
      'keywordHint': '输入关键词',
      'searchButton': '搜索',
      'filterLabel': '搜索类型',
      'filterAll': '全部',
      'filterText': '文本',
      'filterMedia': '媒体',
      'filterImage': '图片',
      'filterVideo': '视频',
      'filterAudio': '音频',
      'filterFile': '文件',
      'noResults': '无匹配消息',
      'resultCount': '共 {count} 条结果',
      'openInChat': '在聊天中查看',
    },
    'details': {
      'title': '会话详情',
      'emptyTitle': '选择会话',
      'emptyHint': '会话资料、状态与操作会显示在这里',
      'sync': '同步',
      'markRead': '标为已读',
      'markUnread': '标为未读',
      'pin': '置顶',
      'unpin': '取消置顶',
      'mute': '免打扰',
      'unmute': '取消免打扰',
      'archive': '归档',
      'unarchive': '取消归档',
      'clearHistory': '清空本地记录',
      'delete': '删除会话',
      'statusSection': '会话状态',
      'extensions': '扩展入口',
      'openSdkLab': 'SDK 诊断',
      'pinTag': '置顶',
      'muteTag': '免打扰',
      'archivedTag': '已归档',
      'membersCount': '{count} 位成员',
    },
  },
  FlareLocale.enUs: {
    'nav': {
      'login': 'Sign in',
      'conversations': 'Messages',
      'sdkLab': 'SDK Lab',
      'settings': 'Settings',
    },
    'login': {
      'brandTitle': 'flare IM',
      'brandSubtitle': 'Secure, fast messaging',
      'welcomeTitle': 'Welcome back',
      'welcomeHint': 'Enter your user ID to continue',
      'userIdLabel': 'User ID',
      'userIdPlaceholder': 'Enter user ID',
      'userIdHint': 'Your user ID is assigned by the system',
      'userIdRequired': 'User ID is required',
      'serverToggle': 'Server URL (optional)',
      'wsUrlLabel': 'WebSocket',
      'wsUrlInvalid':
          'Enter the access-gateway WebSocket URL, for example ws://127.0.0.1:60051/ws',
      'advancedWsHint': 'Leave empty to use the default from config',
      'loginButton': 'Sign in',
      'footerPrimary': 'ID is assigned by your administrator',
      'footerSecondary': 'ID sign-in only · secure connection',
      'cancel': 'Cancel',
      'connected': 'Connected',
      'disconnected': 'Disconnected',
    },
    'conversation': {
      'title': 'Messages',
      'searchPlaceholder': 'Search conversations or previews',
      'pinnedSection': 'Pinned',
      'allSection': 'All',
      'emptyTitle': 'No conversations yet',
      'emptyHint': 'Pull to refresh or start a new chat',
      'startChat': 'Start chat',
      'emptySearchTitle': 'No matches',
      'emptySearchHint': 'Try another keyword',
      'filterAll': 'All',
      'filterUnread': 'Unread',
      'filterMention': 'Mentions',
      'filterPinned': 'Pinned',
      'filterMuted': 'Muted',
      'filterArchived': 'Archived',
      'filterDraft': 'Drafts',
      'draftPrefix': 'Draft: ',
      'noMessagePreview': 'No messages yet',
      'previewSticker': 'Sticker',
      'previewEmoji': 'Emoji',
      'currentAccount': 'Signed in as',
      'sdkLabSubtitle': 'Connection, capabilities, media cache, diagnostics',
      'language': 'Language',
      'languageZh': '简体中文',
      'languageEn': 'English',
    },
    'chat': {
      'composerPlaceholder': 'Message {name}',
      'send': 'Send',
      'typing': 'Typing…',
      'connectionStable': 'Connected · synced',
      'connectionConnecting': 'Connecting…',
      'connectionDisconnected': 'Disconnected · retrying',
      'connectionSendingHint': 'Sending messages will continue when ready',
      'searchMessages': 'Search messages',
      'syncConversation': 'Sync conversation',
      'pullFromServer': 'Pull from server',
      'conversationDetails': 'Conversation details',
      'multiSelectCount': '{count} selected',
      'selectTitle': 'Select a conversation',
      'selectHint': 'Open a chat from the list or start a new one',
    },
    'connection': {
      'syncConversations': 'Syncing conversations',
      'syncDetail': 'Offline data will sync after connect',
      'reconnecting': 'Reconnecting',
      'disconnected': 'Disconnected',
      'retryHint': 'Check server URL and network',
    },
    'settings': {
      'title': 'Settings',
      'appearance': 'Appearance',
      'language': 'Language',
      'themeSystem': 'System',
      'themeLight': 'Light',
      'themeDark': 'Dark',
    },
    'sdkLab': {'title': 'SDK Lab', 'refresh': 'Refresh'},
    'search': {
      'title': 'Search messages',
      'inConversation': 'This chat',
      'global': 'All chats',
      'keywordHint': 'Keyword',
      'searchButton': 'Search',
      'filterLabel': 'Search type',
      'filterAll': 'All',
      'filterText': 'Text',
      'filterMedia': 'Media',
      'filterImage': 'Images',
      'filterVideo': 'Videos',
      'filterAudio': 'Audio',
      'filterFile': 'Files',
      'noResults': 'No matches',
      'resultCount': '{count} results',
      'openInChat': 'Open in chat',
    },
    'details': {
      'title': 'Details',
      'emptyTitle': 'Select a conversation',
      'emptyHint': 'Metadata and actions appear here',
      'sync': 'Sync',
      'markRead': 'Mark read',
      'markUnread': 'Mark unread',
      'pin': 'Pin',
      'unpin': 'Unpin',
      'mute': 'Mute',
      'unmute': 'Unmute',
      'archive': 'Archive',
      'unarchive': 'Unarchive',
      'clearHistory': 'Clear local history',
      'delete': 'Delete',
      'statusSection': 'Status',
      'extensions': 'Extensions',
      'openSdkLab': 'SDK diagnostics',
      'pinTag': 'Pinned',
      'muteTag': 'Muted',
      'archivedTag': 'Archived',
      'membersCount': '{count} members',
    },
  },
};
