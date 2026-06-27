import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/application/providers/sdk_lab_provider.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SdkLabScreen extends HookConsumerWidget {
  const SdkLabScreen({super.key});

  static const _tabs = [
    Tab(text: '诊断'),
    Tab(text: '事件'),
    Tab(text: 'Builder'),
    Tab(text: '媒体'),
    Tab(text: 'Presence'),
    Tab(text: '能力/通话'),
    Tab(text: 'Raw Ops'),
    Tab(text: 'Reset'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabController = useTabController(initialLength: _tabs.length);
    final state = ref.watch(sdkLabProvider);
    final notifier = ref.read(sdkLabProvider.notifier);
    final i18n = ref.watch(flareMessagesProvider);

    useEffect(() {
      Future.microtask(notifier.refresh);
      return null;
    }, const []);

    return Scaffold(
      backgroundColor: FlareImDesign.mobileCanvas,
      appBar: AppBar(
        title: Text(i18n.sdkLab.title),
        actions: [
          IconButton(
            tooltip: i18n.sdkLab.refresh,
            onPressed: state.busy ? null : notifier.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: tabController,
          isScrollable: true,
          tabs: _tabs,
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: tabController,
            children: [
              _DiagnosticsSection(state: state),
              _EventConsoleSection(state: state, onClear: notifier.clearLogs),
              _BuilderSection(state: state, notifier: notifier),
              _MediaSection(state: state, notifier: notifier),
              _PresenceSection(state: state, notifier: notifier),
              _CapabilitySection(state: state, notifier: notifier),
              _RawOpsSection(state: state, notifier: notifier),
              _ResetSection(state: state, notifier: notifier),
            ],
          ),
          if (state.loading) const LinearProgressIndicator(minHeight: 2),
          if (state.runningOperation != null)
            _RunningOperationBanner(operation: state.runningOperation!),
          if (state.error != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: _ErrorBanner(message: state.error!),
            ),
        ],
      ),
    );
  }
}

class _DiagnosticsSection extends StatelessWidget {
  const _DiagnosticsSection({required this.state});

  final SdkLabSnapshot state;

  @override
  Widget build(BuildContext context) {
    return _SectionList(
      children: [
        _JsonBlock(title: 'Runtime Diagnostics', data: state.diagnostics),
        _JsonBlock(
          title: 'Last Operation Result',
          data: state.lastResult?.toJson() ?? const <String, Object?>{},
        ),
        _FailureLedger(failures: state.failures),
      ],
    );
  }
}

class _EventConsoleSection extends StatelessWidget {
  const _EventConsoleSection({required this.state, required this.onClear});

  final SdkLabSnapshot state;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _SectionList(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Bounded Event Console (${state.events.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.cleaning_services_outlined, size: 18),
              label: const Text('清空'),
            ),
          ],
        ),
        if (state.events.isEmpty)
          const _EmptyHint(text: '暂无事件。登录、同步、发送消息或执行 Lab 操作后会记录。')
        else
          for (final event in state.events)
            _TimelineTile(
              title: '${event.domain}.${event.name}',
              subtitle: event.timestamp.toIso8601String(),
              payload: event.toJson(),
            ),
      ],
    );
  }
}

class _BuilderSection extends HookWidget {
  const _BuilderSection({required this.state, required this.notifier});

  final SdkLabSnapshot state;
  final SdkLabNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final entries = state.builderOperations;
    final selectedOp = useState<String?>(null);
    final selectedEntry = entries.isEmpty
        ? null
        : entries.firstWhere(
            (entry) => entry['op'] == selectedOp.value,
            orElse: () => entries.first,
          );
    final payloadController = useTextEditingController(
      text: selectedEntry == null
          ? '{}'
          : sdkLabDefaultBuilderPayloadJson(selectedEntry),
    );

    return _SectionList(
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Message Builder Catalog',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              if (entries.isEmpty)
                const _EmptyHint(text: '暂无 builder catalog，刷新后查看 SDK 返回的构建能力。')
              else ...[
                DropdownButtonFormField<String>(
                  initialValue:
                      '${selectedEntry?['op'] ?? entries.first['op']}',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Build Operation',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final entry in entries)
                      DropdownMenuItem(
                        value: '${entry['op']}',
                        child: Text(
                          '${entry['method']} · ${entry['contentType']}',
                        ),
                      ),
                  ],
                  onChanged: state.busy
                      ? null
                      : (value) {
                          if (value == null) return;
                          final next = entries.firstWhere(
                            (entry) => entry['op'] == value,
                          );
                          selectedOp.value = value;
                          payloadController.text =
                              sdkLabDefaultBuilderPayloadJson(next);
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: payloadController,
                  enabled: !state.busy,
                  minLines: 7,
                  maxLines: 12,
                  keyboardType: TextInputType.multiline,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.28,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Build Payload JSON',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: state.busy
                        ? null
                        : () => unawaited(
                            notifier.runBuilderOperation(
                              '${selectedEntry?['op'] ?? entries.first['op']}',
                              payloadController.text,
                            ),
                          ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Build Raw'),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (entries.isEmpty)
          const SizedBox.shrink()
        else
          for (final entry in entries) _CatalogTile(entry: entry),
      ],
    );
  }
}

class _MediaSection extends HookWidget {
  const _MediaSection({required this.state, required this.notifier});

  final SdkLabSnapshot state;
  final SdkLabNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final mediaIdController = useTextEditingController();
    final fileIdController = useTextEditingController();
    final downloadKeyController = useTextEditingController(
      text: 'sdk-lab-download',
    );
    final displayFileNameController = useTextEditingController(
      text: 'flare-sdk-lab.bin',
    );
    final sourceUrlController = useTextEditingController();
    final sourcePathController = useTextEditingController();

    return _SectionList(
      children: [
        _ActionGrid(
          disabled: state.busy,
          actions: [
            _LabAction(
              icon: Icons.cleaning_services_outlined,
              label: '清理缓存',
              onPressed: notifier.clearMediaCache,
            ),
            _LabAction(
              icon: Icons.sd_storage_outlined,
              label: '设 256MB 上限',
              onPressed: notifier.setMediaCacheMaxBytes,
            ),
            _LabAction(
              icon: Icons.folder_outlined,
              label: '下载目录',
              onPressed: notifier.getUserDownloadSubfolder,
            ),
            _LabAction(
              icon: Icons.create_new_folder_outlined,
              label: '设 Lab 目录',
              onPressed: notifier.setUserDownloadSubfolder,
            ),
          ],
        ),
        _MediaDiagnosticsPanel(state: state),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload Probes',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              _ActionGrid(
                disabled: state.busy,
                actions: [
                  _LabAction(
                    icon: Icons.upload_file_outlined,
                    label: '上传文件',
                    onPressed: () => _pickAndUpload(notifier, kind: 'file'),
                  ),
                  _LabAction(
                    icon: Icons.image_outlined,
                    label: '上传图片',
                    onPressed: () => _pickAndUpload(notifier, kind: 'image'),
                  ),
                  _LabAction(
                    icon: Icons.video_file_outlined,
                    label: '上传视频',
                    onPressed: () => _pickAndUpload(notifier, kind: 'video'),
                  ),
                  _LabAction(
                    icon: Icons.data_object_outlined,
                    label: '上传 Bytes',
                    onPressed: notifier.uploadBytesSample,
                  ),
                ],
              ),
            ],
          ),
        ),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Access / Cache',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: mediaIdController,
                enabled: !state.busy,
                decoration: const InputDecoration(
                  labelText: 'media_id',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fileIdController,
                enabled: !state.busy,
                decoration: const InputDecoration(
                  labelText: 'file_id',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              _ActionGrid(
                disabled: state.busy,
                actions: [
                  _LabAction(
                    icon: Icons.link_outlined,
                    label: 'Media URL',
                    onPressed: () =>
                        notifier.getMediaUrl(mediaIdController.text),
                  ),
                  _LabAction(
                    icon: Icons.download_outlined,
                    label: 'Temp URL',
                    onPressed: () =>
                        notifier.getTempDownloadUrl(fileIdController.text),
                  ),
                  _LabAction(
                    icon: Icons.verified_outlined,
                    label: 'Resolve',
                    onPressed: () =>
                        notifier.resolveMediaAccess(fileIdController.text),
                  ),
                  _LabAction(
                    icon: Icons.cached_outlined,
                    label: 'Cache Remote',
                    onPressed: () =>
                        notifier.cacheRemoteMedia(fileIdController.text),
                  ),
                ],
              ),
            ],
          ),
        ),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Downloads',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: downloadKeyController,
                enabled: !state.busy,
                decoration: const InputDecoration(
                  labelText: 'download_key',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: displayFileNameController,
                enabled: !state.busy,
                decoration: const InputDecoration(
                  labelText: 'display_file_name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sourcePathController,
                enabled: !state.busy,
                decoration: const InputDecoration(
                  labelText: 'source_path',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sourceUrlController,
                enabled: !state.busy,
                decoration: const InputDecoration(
                  labelText: 'source_url',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              _ActionGrid(
                disabled: state.busy,
                actions: [
                  _LabAction(
                    icon: Icons.folder_open_outlined,
                    label: '选择源文件',
                    onPressed: () async {
                      final path = await _pickPath();
                      if (path != null) sourcePathController.text = path;
                    },
                  ),
                  _LabAction(
                    icon: Icons.download_for_offline_outlined,
                    label: '下载/保存',
                    onPressed: () => notifier.downloadFileToDownloads(
                      downloadKey: downloadKeyController.text,
                      displayFileName: displayFileNameController.text,
                      sourcePath: sourcePathController.text,
                      sourceUrl: sourceUrlController.text,
                      remoteFileId: fileIdController.text,
                    ),
                  ),
                  _LabAction(
                    icon: Icons.manage_search_outlined,
                    label: '查询保存路径',
                    onPressed: () => notifier.getUserDownloadSavedPath(
                      downloadKeyController.text,
                    ),
                  ),
                  _LabAction(
                    icon: Icons.cancel_outlined,
                    label: '取消下载',
                    onPressed: () => notifier.cancelUserFileDownload(
                      downloadKeyController.text,
                    ),
                  ),
                  _LabAction(
                    icon: Icons.delete_outline,
                    label: '删除记录',
                    onPressed: () => notifier.deleteUserDownloadRecord(
                      downloadKeyController.text,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _JsonBlock(title: 'Media Cache', data: state.mediaCache),
      ],
    );
  }

  Future<void> _pickAndUpload(
    SdkLabNotifier notifier, {
    required String kind,
  }) async {
    final path = await _pickPath(kind: kind);
    if (path == null) return;
    await notifier.uploadMediaPath(path, kind: kind);
  }

  Future<String?> _pickPath({String kind = 'file'}) async {
    final type = switch (kind) {
      'image' => FileType.image,
      'video' => FileType.video,
      _ => FileType.any,
    };
    final result = await FilePicker.platform.pickFiles(type: type);
    return result?.files.single.path;
  }
}

class _PresenceSection extends StatelessWidget {
  const _PresenceSection({required this.state, required this.notifier});

  final SdkLabSnapshot state;
  final SdkLabNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return _SectionList(
      children: [
        _ActionGrid(
          disabled: state.busy,
          actions: [
            _LabAction(
              icon: Icons.person_search_outlined,
              label: '查询当前用户',
              onPressed: notifier.getCurrentUserPresence,
            ),
            _LabAction(
              icon: Icons.groups_outlined,
              label: '批量查询',
              onPressed: notifier.batchGetCurrentUserPresence,
            ),
            _LabAction(
              icon: Icons.notifications_active_outlined,
              label: '订阅 Presence',
              onPressed: notifier.subscribeCurrentUserPresence,
            ),
          ],
        ),
        _JsonBlock(title: 'Presence Snapshot', data: state.presence),
      ],
    );
  }
}

class _CapabilitySection extends StatelessWidget {
  const _CapabilitySection({required this.state, required this.notifier});

  final SdkLabSnapshot state;
  final SdkLabNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return _SectionList(
      children: [
        const _InfoPanel(
          icon: Icons.extension_outlined,
          title: 'Optional Capability Surface',
          body:
              'Call/SFU controls run through capability discovery first; unavailable runtimes return typed diagnostics instead of opening a call surface.',
        ),
        _ActionGrid(
          disabled: state.busy,
          actions: [
            _LabAction(
              icon: Icons.route_outlined,
              label: 'Dispatch Probe',
              onPressed: notifier.dispatchCapabilityProbe,
            ),
            _LabAction(
              icon: Icons.add_moderator_outlined,
              label: 'Grant Call',
              onPressed: notifier.grantCallCapability,
            ),
            _LabAction(
              icon: Icons.remove_moderator_outlined,
              label: 'Revoke Call',
              onPressed: notifier.revokeCallCapability,
            ),
            _LabAction(
              icon: Icons.call_outlined,
              label: 'Discover + Signal',
              onPressed: notifier.sendCallSignalProbe,
            ),
          ],
        ),
        _JsonBlock(title: 'Global Capabilities', data: state.capabilities),
        _JsonBlock(
          title: 'Current User Capabilities',
          data: state.userCapabilities,
        ),
      ],
    );
  }
}

class _RawOpsSection extends HookWidget {
  const _RawOpsSection({required this.state, required this.notifier});

  final SdkLabSnapshot state;
  final SdkLabNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final selectedId = useState(sdkLabOperationTemplates.first.id);
    final selectedTemplate = sdkLabOperationTemplates.firstWhere(
      (template) => template.id == selectedId.value,
      orElse: () => sdkLabOperationTemplates.first,
    );
    final payloadController = useTextEditingController(
      text: selectedTemplate.defaultJson,
    );

    return _SectionList(
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedTemplate.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'SDK Operation Template',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final template in sdkLabOperationTemplates)
                    DropdownMenuItem(
                      value: template.id,
                      child: Text('${template.family} · ${template.title}'),
                    ),
                ],
                onChanged: state.busy
                    ? null
                    : (value) {
                        if (value == null) return;
                        final next = sdkLabOperationTemplates.firstWhere(
                          (template) => template.id == value,
                        );
                        selectedId.value = next.id;
                        payloadController.text = next.defaultJson;
                      },
              ),
              const SizedBox(height: 10),
              Text(
                selectedTemplate.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: FlareImDesign.mutedForeground,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: payloadController,
                enabled: !state.busy,
                minLines: 8,
                maxLines: 14,
                keyboardType: TextInputType.multiline,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.28,
                ),
                decoration: const InputDecoration(
                  labelText: 'Payload JSON',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: state.busy
                      ? null
                      : () => unawaited(
                          notifier.runTemplateOperation(
                            selectedTemplate.id,
                            payloadController.text,
                          ),
                        ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('执行模板'),
                ),
              ),
            ],
          ),
        ),
        _ActionGrid(
          disabled: state.busy,
          actions: [
            _LabAction(
              icon: Icons.sync_outlined,
              label: '同步会话摘要',
              onPressed: notifier.syncConversationSummaries,
            ),
            _LabAction(
              icon: Icons.bug_report_outlined,
              label: 'Raw 会话',
              onPressed: notifier.listRawConversations,
            ),
            _LabAction(
              icon: Icons.view_list_outlined,
              label: '分页会话',
              onPressed: notifier.listConversationsPaginated,
            ),
          ],
        ),
        _JsonBlock(
          title: 'Last Raw Operation',
          data: state.lastResult?.toJson() ?? const <String, Object?>{},
        ),
      ],
    );
  }
}

class _ResetSection extends HookWidget {
  const _ResetSection({required this.state, required this.notifier});

  final SdkLabSnapshot state;
  final SdkLabNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final ttlController = useTextEditingController(text: '3600');

    return _SectionList(
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Token Renewal',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ttlController,
                enabled: !state.busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ttlSecs',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: state.busy
                      ? null
                      : () => unawaited(
                          notifier.renewAccessToken(
                            ttlSecs: int.tryParse(ttlController.text) ?? 3600,
                          ),
                        ),
                  icon: const Icon(Icons.key_outlined, size: 18),
                  label: const Text('Update Access Token'),
                ),
              ),
            ],
          ),
        ),
        const _InfoPanel(
          icon: Icons.warning_amber_outlined,
          title: 'Lifecycle Controls',
          body:
              'These controls intentionally expose destructive SDK lifecycle operations for integration testing.',
        ),
        _ActionGrid(
          disabled: state.busy,
          actions: [
            _LabAction(
              icon: Icons.health_and_safety_outlined,
              label: 'Runtime Health',
              onPressed: notifier.runtimeHealth,
            ),
            _LabAction(
              icon: Icons.network_check_outlined,
              label: 'Network Change',
              onPressed: notifier.notifyNetworkChangeProbe,
            ),
            _LabAction(
              icon: Icons.monitor_heart_outlined,
              label: 'Heartbeat',
              onPressed: notifier.heartbeatEffectiveInterval,
            ),
            _LabAction(
              icon: Icons.visibility_outlined,
              label: 'Foreground',
              onPressed: notifier.setHeartbeatForeground,
            ),
            _LabAction(
              icon: Icons.visibility_off_outlined,
              label: 'Background',
              onPressed: notifier.setHeartbeatBackground,
            ),
            _LabAction(
              icon: Icons.timer_outlined,
              label: 'NAT 60s',
              onPressed: notifier.setHeartbeatNatTimeout,
            ),
            _LabAction(
              icon: Icons.link_off_outlined,
              label: 'Disconnect',
              onPressed: notifier.disconnect,
            ),
            _LabAction(
              icon: Icons.event_busy_outlined,
              label: 'Unsubscribe All',
              onPressed: notifier.unsubscribeAllEvents,
            ),
            _LabAction(
              icon: Icons.power_settings_new_outlined,
              label: 'Uninit',
              onPressed: notifier.uninit,
            ),
            _LabAction(
              icon: Icons.restart_alt_outlined,
              label: 'Hard Reset',
              onPressed: notifier.hardReset,
            ),
          ],
        ),
        _FailureLedger(failures: state.failures),
      ],
    );
  }
}

class _SectionList extends StatelessWidget {
  const _SectionList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: children.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => children[index],
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions, required this.disabled});

  final List<_LabAction> actions;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final action in actions)
          OutlinedButton.icon(
            onPressed: disabled ? null : () => unawaited(action.onPressed()),
            icon: Icon(action.icon, size: 18),
            label: Text(action.label),
          ),
      ],
    );
  }
}

class _LabAction {
  const _LabAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onPressed;
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({required this.entry});

  final Map<String, Object?> entry;

  @override
  Widget build(BuildContext context) {
    final method = '${entry['method'] ?? ''}';
    final op = '${entry['op'] ?? ''}';
    final stability = '${entry['stability'] ?? ''}';
    return _Panel(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(method.isEmpty ? op : method),
        subtitle: Text(
          '${entry['contentType']} · ${entry['requestType']} · ${entry['summary']}',
        ),
        trailing: Chip(
          label: Text(stability.isEmpty ? 'unknown' : stability),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.title,
    required this.subtitle,
    required this.payload,
  });

  final String title;
  final String subtitle;
  final Object? payload;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(subtitle),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              _pretty(payload),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureLedger extends StatelessWidget {
  const _FailureLedger({required this.failures});

  final List<SdkLabFailureEntry> failures;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Command Failure Ledger',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          if (failures.isEmpty)
            const _EmptyHint(text: '暂无命令失败。')
          else
            for (final failure in failures.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SelectableText(_pretty(failure.toJson())),
              ),
        ],
      ),
    );
  }
}

class _MediaDiagnosticsPanel extends StatelessWidget {
  const _MediaDiagnosticsPanel({required this.state});

  final SdkLabSnapshot state;

  @override
  Widget build(BuildContext context) {
    final mediaEvents = state.events
        .where((event) => event.domain == 'media')
        .take(5)
        .toList(growable: false);
    final mediaFailures = state.failures
        .where((failure) => failure.operation.startsWith('media.'))
        .take(5)
        .toList(growable: false);
    final cacheSummary = state.mediaCache.isEmpty
        ? 'cache stats unavailable'
        : _pretty(state.mediaCache);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Media Runtime Diagnostics',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          _DiagnosticLine(
            icon: Icons.storage_outlined,
            label: 'Cache',
            value: cacheSummary,
          ),
          _DiagnosticLine(
            icon: Icons.event_note_outlined,
            label: 'Recent Media Events',
            value: mediaEvents.isEmpty
                ? 'none'
                : mediaEvents
                      .map((event) => '${event.name} @ ${event.timestamp}')
                      .join('\n'),
          ),
          _DiagnosticLine(
            icon: Icons.error_outline,
            label: 'Recent Media Failures',
            value: mediaFailures.isEmpty
                ? 'none'
                : mediaFailures
                      .map(
                        (failure) =>
                            '${failure.operation}: ${failure.code} · ${failure.message}',
                      )
                      .join('\n'),
          ),
          const SizedBox(height: 8),
          const _EmptyHint(
            text:
                '文件上传请先确认已登录且 SDK 已初始化；下载/保存至少提供 source_path、source_url 或 remoteFileId 之一。',
          ),
        ],
      ),
    );
  }
}

class _DiagnosticLine extends StatelessWidget {
  const _DiagnosticLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: FlareImDesign.brandPurple),
          const SizedBox(width: 8),
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: FlareImDesign.mutedForeground,
                height: 1.28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JsonBlock extends StatelessWidget {
  const _JsonBlock({required this.title, required this.data});

  final String title;
  final Object? data;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          SelectableText(
            _pretty(data),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: FlareImDesign.brandPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: FlareImDesign.mutedForeground,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FlareImDesign.mobileDivider),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: FlareImDesign.mutedForeground),
    );
  }
}

class _RunningOperationBanner extends StatelessWidget {
  const _RunningOperationBanner({required this.operation});

  final String operation;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: FlareImDesign.brandPurple.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Running $operation',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FlareImDesign.destructive.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: FlareImDesign.destructive.withValues(alpha: 0.28),
          ),
        ),
        child: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

String _pretty(Object? value) {
  if (value == null) return '{}';
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return value.toString();
  }
}
