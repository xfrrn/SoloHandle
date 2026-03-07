import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../core/constants.dart";
import "../../data/api/api_client.dart";
import "dart:convert";

import "package:flutter/services.dart";

import "../../data/api/events_api.dart";
import "../../data/api/tasks_api.dart";
import "../../data/storage/local_store.dart";

enum ConnectionStatus { unknown, success, failed }

class DeveloperSettingsScreen extends StatefulWidget {
  const DeveloperSettingsScreen({super.key});

  @override
  State<DeveloperSettingsScreen> createState() => _DeveloperSettingsScreenState();
}

class _DeveloperSettingsScreenState extends State<DeveloperSettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _tokenController = TextEditingController();
  final _store = LocalStore();
  bool _loading = true;
  bool _dirty = false;
  bool _showToken = false;
  ConnectionStatus _connection = ConnectionStatus.unknown;
  String? _baseUrlError;
  DateTime? _lastSavedAt;
  String? _connectionModel;
  String? _connectionBaseUrl;
  bool _exporting = false;
  bool _clearing = false;

  String _draftPolicy = "记账/任务默认需确认";
  String _timezone = "Asia/Shanghai";
  String _exportFormat = "JSON";

  @override
  void initState() {
    super.initState();
    _load();
    _baseUrlController.addListener(_markDirty);
    _tokenController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final baseUrl = await _store.getBaseUrl();
    final token = await _store.getToken();
    final draftPolicy = await _store.getDraftPolicy();
    final timezone = await _store.getDefaultTimezone();
    _baseUrlController.text = baseUrl ?? "http://127.0.0.1:8000";
    _tokenController.text = token ?? "";
    _draftPolicy = draftPolicy ?? _draftPolicy;
    _timezone = timezone ?? _timezone;
    setState(() => _loading = false);
  }

  void _markDirty() {
    if (!_dirty) {
      setState(() => _dirty = true);
    }
  }

  bool _validateBaseUrl() {
    final value = _baseUrlController.text.trim();
    if (value.isEmpty) {
      setState(() => _baseUrlError = "Base URL 不能为空");
      return false;
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      setState(() => _baseUrlError = "请输入有效 URL");
      return false;
    }
    setState(() => _baseUrlError = null);
    return true;
  }

  Future<void> _save() async {
    if (!_validateBaseUrl()) return;
    await _store.setBaseUrl(_baseUrlController.text.trim());
    await _store.setToken(_tokenController.text.trim());
    await _store.setDraftPolicy(_draftPolicy);
    await _store.setDefaultTimezone(_timezone);
    setState(() {
      _dirty = false;
      _lastSavedAt = DateTime.now();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("设置已保存")),
    );
  }

  Future<void> _testConnection() async {
    if (!_validateBaseUrl()) return;
    setState(() => _connection = ConnectionStatus.unknown);
    try {
      final dio = await ApiClient(store: _store).dio;
      final resp = await dio.get("/router/health");
      final data = resp.data as Map?;
      final ok = data?["llm_configured"] == true;
      _connectionModel = data?["model"]?.toString();
      _connectionBaseUrl = data?["base_url"]?.toString();
      setState(() => _connection = ok ? ConnectionStatus.success : ConnectionStatus.failed);
    } catch (_) {
      setState(() => _connection = ConnectionStatus.failed);
    }
  }

  Future<void> _exportData() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final dio = await ApiClient(store: _store).dio;
      final events = await EventsApi(dio).list(limit: 200, offset: 0);
      final tasks = await TasksApi(dio).list(limit: 200, offset: 0);
      final payload = {
        "exported_at": DateTime.now().toIso8601String(),
        "events": events.items.map((e) => {
              "event_id": e.eventId,
              "type": e.type,
              "happened_at": e.happenedAt,
              "data": e.data,
              "tags": e.tags,
              "source": e.source,
              "confidence": e.confidence,
              "commit_id": e.commitId,
              "created_at": e.createdAt,
              "updated_at": e.updatedAt,
            }).toList(),
        "tasks": tasks.items.map((t) => {
              "task_id": t.taskId,
              "title": t.title,
              "status": t.status,
              "priority": t.priority,
              "due_at": t.dueAt,
              "remind_at": t.remindAt,
              "tags": t.tags,
              "project": t.project,
              "note": t.note,
              "commit_id": t.commitId,
              "created_at": t.createdAt,
              "updated_at": t.updatedAt,
              "completed_at": t.completedAt,
              "is_deleted": t.isDeleted,
            }).toList(),
      };
      final jsonText = const JsonEncoder.withIndent("  ").convert(payload);
      await Clipboard.setData(ClipboardData(text: jsonText));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("已导出并复制到剪贴板")),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("导出失败，请检查连接设置")),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _clearCache() async {
    if (_clearing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("清除本地缓存"),
        content: const Text("将清除本地配置与缓存数据，是否继续？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("清除"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _clearing = true);
    await _store.clearAll();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("已清除本地缓存")),
    );
    setState(() => _clearing = false);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go("/me");
          }
        },
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                      children: [
                        _Header(
                          onBack: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go("/me");
                            }
                          },
                        ),
                      const SizedBox(height: 12),
                      _Group(
                        title: "连接",
                        children: [
                          _TextFieldItem(
                            label: "API Base URL",
                            helperText: "用于连接后端服务",
                            controller: _baseUrlController,
                            errorText: _baseUrlError,
                            suffix: TextButton(
                              onPressed: () {
                                _baseUrlController.text =
                                    "http://127.0.0.1:8000";
                              },
                              child: const Text("恢复默认"),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _TextFieldItem(
                            label: "Token",
                            helperText: "用于接口鉴权",
                            controller: _tokenController,
                            obscureText: !_showToken,
                            suffix: IconButton(
                              onPressed: () =>
                                  setState(() => _showToken = !_showToken),
                              icon: Icon(
                                _showToken
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _ConnectionRow(
                            status: _connection,
                            model: _connectionModel,
                            baseUrl: _connectionBaseUrl,
                            onTest: _testConnection,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Group(
                        title: "行为策略",
                        children: [
                          _SettingRow(
                            title: "Draft policy",
                            subtitle: "草稿确认策略",
                            value: _draftPolicy,
                            onTap: () async {
                              final value = await _pickDraftPolicy(context);
                              if (value != null) {
                                setState(() {
                                  _draftPolicy = value;
                                  _dirty = true;
                                });
                              }
                            },
                          ),
                          _SettingRow(
                            title: "默认时区",
                            subtitle: "记录与提醒使用的时区",
                            value: _timezone,
                            onTap: () async {
                              final value = await _pickTimezone(context);
                              if (value != null) {
                                setState(() {
                                  _timezone = value;
                                  _dirty = true;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Group(
                        title: "数据与导出",
                        children: [
                          _SettingRow(
                            title: "导出数据",
                            subtitle: "导出为 $_exportFormat",
                            value: _exporting ? "导出中..." : "导出",
                            onTap: _exporting ? null : _exportData,
                          ),
                          _SettingRow(
                            title: "清除本地缓存",
                            subtitle: "清空本地数据与缓存",
                            value: _clearing ? "清除中..." : "清除",
                            onTap: _clearing ? null : _clearCache,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                        _Group(
                          title: "调试与诊断",
                          children: [
                            _SettingRow(
                              title: "App Version",
                              subtitle: "当前版本",
                              value: "0.1.0",
                            ),
                            _SettingRow(
                              title: "环境",
                              subtitle: "本地 / 开发",
                              value: "Dev",
                            ),
                            _SettingRow(
                              title: "最近一次保存",
                              subtitle: _lastSavedAt == null
                                  ? "尚未保存"
                                  : _lastSavedAt!.toLocal().toString(),
                              value: _lastSavedAt == null ? "—" : "已保存",
                            ),
                          ],
                        ),
                      ],
                    ),
                    _SaveBar(
                      enabled: _dirty,
                      onSave: _save,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<String?> _pickDraftPolicy(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BottomSheetItem(
              label: "记账/任务默认需确认",
              onTap: () => Navigator.pop(context, "记账/任务默认需确认"),
            ),
            _BottomSheetItem(
              label: "总是确认",
              onTap: () => Navigator.pop(context, "总是确认"),
            ),
            _BottomSheetItem(
              label: "自动提交优先",
              onTap: () => Navigator.pop(context, "自动提交优先"),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickTimezone(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BottomSheetItem(
              label: "Asia/Shanghai",
              onTap: () => Navigator.pop(context, "Asia/Shanghai"),
            ),
            _BottomSheetItem(
              label: "America/Los_Angeles",
              onTap: () => Navigator.pop(context, "America/Los_Angeles"),
            ),
            _BottomSheetItem(
              label: "Europe/London",
              onTap: () => Navigator.pop(context, "Europe/London"),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Developer Settings",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                "连接、行为与调试配置",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _TextFieldItem extends StatelessWidget {
  const _TextFieldItem({
    required this.label,
    required this.controller,
    this.helperText,
    this.errorText,
    this.obscureText = false,
    this.suffix,
  });

  final String label;
  final String? helperText;
  final String? errorText;
  final TextEditingController controller;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            errorText: errorText,
            suffixIcon: suffix,
            filled: true,
            fillColor: AppColors.background,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({
    required this.status,
    required this.onTest,
    this.model,
    this.baseUrl,
  });

  final ConnectionStatus status;
  final VoidCallback onTest;
  final String? model;
  final String? baseUrl;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ConnectionStatus.success => "已连接",
      ConnectionStatus.failed => "连接失败",
      _ => "未验证",
    };
    final color = switch (status) {
      ConnectionStatus.success => AppColors.success,
      ConnectionStatus.failed => AppColors.danger,
      _ => AppColors.textSecondary,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "连接状态：$label",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                    ),
              ),
              if (model != null && model!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  "Model: $model",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
              if (baseUrl != null && baseUrl!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  "Base URL: $baseUrl",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onTest,
          icon: const Icon(Icons.wifi_tethering, size: 16),
          label: const Text("测试连接"),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.enabled, required this.onSave});

  final bool enabled;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -6),
            )
          ],
        ),
        child: SafeArea(
          top: false,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: enabled ? 1 : 0.5,
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: enabled ? onSave : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text("保存设置"),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomSheetItem extends StatelessWidget {
  const _BottomSheetItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      onTap: onTap,
    );
  }
}
