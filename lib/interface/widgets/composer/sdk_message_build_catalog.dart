enum SdkMessageBuildFieldType { text, textarea }

class SdkMessageBuildField {
  final String key;
  final String label;
  final SdkMessageBuildFieldType type;
  final String? placeholder;
  final String defaultValue;

  const SdkMessageBuildField({
    required this.key,
    required this.label,
    this.type = SdkMessageBuildFieldType.text,
    this.placeholder,
    this.defaultValue = '',
  });
}

enum SdkMessageBuildKind {
  threadReply,
  imageGroup,
  location,
  card,
  sticker,
  linkCard,
  miniProgram,
  notification,
  vote,
  task,
  schedule,
  announcement,
  custom,
  placeholder,
}

class SdkMessageBuildCatalogEntry {
  final SdkMessageBuildKind kind;
  final String label;
  final String protoHint;
  final String group;
  final List<SdkMessageBuildField> fields;

  const SdkMessageBuildCatalogEntry({
    required this.kind,
    required this.label,
    required this.protoHint,
    required this.group,
    required this.fields,
  });
}

const sdkMessageBuildCatalog = <SdkMessageBuildCatalogEntry>[
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.threadReply,
    label: '线程 THREAD',
    protoHint: '14 THREAD',
    group: '基础',
    fields: [
      SdkMessageBuildField(key: 'threadId', label: 'threadId'),
      SdkMessageBuildField(
        key: 'text',
        label: '正文',
        type: SdkMessageBuildFieldType.textarea,
      ),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.imageGroup,
    label: '多图 IMAGE_GROUP',
    protoHint: '32 IMAGE_GROUP · create_with_content',
    group: '基础',
    fields: [
      SdkMessageBuildField(
        key: 'imageLines',
        label: '图片 URL / imageId',
        type: SdkMessageBuildFieldType.textarea,
        placeholder: '输入真实图片 URL 或 imageId',
      ),
      SdkMessageBuildField(key: 'description', label: '说明（可选）'),
      SdkMessageBuildField(
        key: 'metadata',
        label: 'metadata（每行 key: value）',
        type: SdkMessageBuildFieldType.textarea,
        placeholder: 'albumId: <真实相册 ID>',
      ),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.location,
    label: '位置 LOCATION',
    protoHint: '6 LOCATION',
    group: '卡片与链接',
    fields: [
      SdkMessageBuildField(key: 'longitude', label: '经度'),
      SdkMessageBuildField(key: 'latitude', label: '纬度'),
      SdkMessageBuildField(key: 'title', label: '标题'),
      SdkMessageBuildField(
        key: 'address',
        label: '详细地址',
        type: SdkMessageBuildFieldType.textarea,
      ),
      SdkMessageBuildField(key: 'zoom', label: '地图缩放（可选）'),
      SdkMessageBuildField(key: 'snapshotUrl', label: '快照 URL（可选）'),
      SdkMessageBuildField(key: 'snapshotLocalPath', label: '本地快照路径（可选）'),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.card,
    label: '名片 CARD',
    protoHint: '7 CARD',
    group: '卡片与链接',
    fields: [
      SdkMessageBuildField(key: 'cardType', label: 'cardType'),
      SdkMessageBuildField(key: 'id', label: 'id'),
      SdkMessageBuildField(key: 'title', label: 'title'),
      SdkMessageBuildField(key: 'subtitle', label: 'subtitle'),
      SdkMessageBuildField(key: 'avatar', label: 'avatar URL'),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.sticker,
    label: '贴纸 STICKER',
    protoHint: '8 STICKER',
    group: '卡片与链接',
    fields: [
      SdkMessageBuildField(key: 'stickerId', label: 'stickerId'),
      SdkMessageBuildField(key: 'packageId', label: 'packageId'),
      SdkMessageBuildField(key: 'url', label: 'url（可选）'),
      SdkMessageBuildField(key: 'width', label: 'width'),
      SdkMessageBuildField(key: 'height', label: 'height'),
      SdkMessageBuildField(key: 'format', label: 'format'),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.linkCard,
    label: '链接卡片 LINK_CARD',
    protoHint: 'MessageContent.link_card',
    group: '卡片与链接',
    fields: [
      SdkMessageBuildField(key: 'url', label: 'url'),
      SdkMessageBuildField(key: 'title', label: 'title'),
      SdkMessageBuildField(key: 'description', label: 'description'),
      SdkMessageBuildField(key: 'thumbnailUrl', label: 'thumbnailUrl'),
      SdkMessageBuildField(key: 'siteName', label: 'siteName'),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.miniProgram,
    label: '小程序 MINI_PROGRAM',
    protoHint: 'MessageContent.mini_program',
    group: '卡片与链接',
    fields: [
      SdkMessageBuildField(key: 'appId', label: 'appId'),
      SdkMessageBuildField(key: 'title', label: 'title'),
      SdkMessageBuildField(key: 'path', label: 'path'),
      SdkMessageBuildField(key: 'thumbnailUrl', label: 'thumbnailUrl'),
      SdkMessageBuildField(
        key: 'extra',
        label: 'extra（每行 key: value）',
        type: SdkMessageBuildFieldType.textarea,
        placeholder: '输入真实扩展字段，每行 key: value',
      ),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.notification,
    label: '通知 NOTIFICATION',
    protoHint: '61 NOTIFICATION',
    group: '业务',
    fields: [
      SdkMessageBuildField(key: 'title', label: '标题'),
      SdkMessageBuildField(
        key: 'body',
        label: '正文',
        type: SdkMessageBuildFieldType.textarea,
      ),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.vote,
    label: '投票 POLL',
    protoHint: '80 POLL · participantUserIds',
    group: '业务',
    fields: [
      SdkMessageBuildField(key: 'voteId', label: 'voteId'),
      SdkMessageBuildField(key: 'title', label: '标题'),
      SdkMessageBuildField(
        key: 'options',
        label: '选项（每行一个）',
        type: SdkMessageBuildFieldType.textarea,
      ),
      SdkMessageBuildField(
        key: 'participantUserIds',
        label: '参与人 ID（逗号/换行分隔）',
        type: SdkMessageBuildFieldType.textarea,
      ),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.task,
    label: '任务 TASK',
    protoHint: '81 TASK · participantUserIds',
    group: '业务',
    fields: [
      SdkMessageBuildField(key: 'taskId', label: 'taskId'),
      SdkMessageBuildField(key: 'title', label: '标题'),
      SdkMessageBuildField(key: 'status', label: 'status'),
      SdkMessageBuildField(
        key: 'participantUserIds',
        label: '参与人 ID（逗号/换行分隔）',
        type: SdkMessageBuildFieldType.textarea,
      ),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.schedule,
    label: '日程 SCHEDULE',
    protoHint: '82 SCHEDULE · start/end 毫秒',
    group: '业务',
    fields: [
      SdkMessageBuildField(key: 'scheduleId', label: 'scheduleId'),
      SdkMessageBuildField(key: 'title', label: '标题'),
      SdkMessageBuildField(key: 'startAfterMinutes', label: '多少分钟后开始'),
      SdkMessageBuildField(key: 'durationMinutes', label: '持续分钟数'),
      SdkMessageBuildField(
        key: 'participantUserIds',
        label: '参与人 ID（逗号/换行分隔）',
        type: SdkMessageBuildFieldType.textarea,
      ),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.announcement,
    label: '公告 ANNOUNCEMENT',
    protoHint: '83 ANNOUNCEMENT',
    group: '业务',
    fields: [
      SdkMessageBuildField(key: 'title', label: '标题'),
      SdkMessageBuildField(
        key: 'body',
        label: '正文',
        type: SdkMessageBuildFieldType.textarea,
      ),
    ],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.custom,
    label: '自定义 CUSTOM',
    protoHint: '100 CUSTOM',
    group: '其它',
    fields: [SdkMessageBuildField(key: 'type', label: '业务 type 字符串')],
  ),
  SdkMessageBuildCatalogEntry(
    kind: SdkMessageBuildKind.placeholder,
    label: '占位 PLACEHOLDER',
    protoHint: '111-115',
    group: '其它',
    fields: [SdkMessageBuildField(key: 'reason', label: 'reason')],
  ),
];

Map<String, String> initialSdkMessageBuildValues(
  SdkMessageBuildCatalogEntry entry,
) {
  return {for (final field in entry.fields) field.key: field.defaultValue};
}
