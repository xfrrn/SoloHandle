import "package:flutter/material.dart";

import "../../core/constants.dart";
import "../../data/storage/local_store.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _tokenController = TextEditingController();
  final _store = LocalStore();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final baseUrl = await _store.getBaseUrl();
    final token = await _store.getToken();
    _baseUrlController.text = baseUrl ?? "http://127.0.0.1:8000";
    _tokenController.text = token ?? "";
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    await _store.setBaseUrl(_baseUrlController.text.trim());
    await _store.setToken(_tokenController.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("已保存")),
    );
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Me")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text("API Base URL", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(controller: _baseUrlController),
                const SizedBox(height: 16),
                Text("Token", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(controller: _tokenController),
                const SizedBox(height: 16),
                _SettingTile(
                  title: "Draft policy",
                  value: "记账/任务默认需确认",
                ),
                _SettingTile(
                  title: "默认时区",
                  value: "Asia/Shanghai",
                ),
                _SettingTile(
                  title: "Export data",
                  value: "JSON",
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _save,
                    style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                    child: const Text("保存"),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
