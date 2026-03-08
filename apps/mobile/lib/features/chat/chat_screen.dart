import "dart:convert";
import "dart:typed_data";
import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:image_picker/image_picker.dart";
import "package:path_provider/path_provider.dart";
import "package:record/record.dart";

import "../../core/constants.dart";
import "../../core/time.dart";
import "../../data/api/api_client.dart";
import "../../data/api/dto.dart";
import "../../data/api/finance_api.dart";
import "../../shared/widgets/error_banner.dart";
import "chat_controller.dart";
import "widgets/card_edit_sheet.dart";
import "widgets/card_renderer.dart";
import "widgets/confirm_bar.dart";
import "widgets/input_bar.dart";
import "widgets/message_bubble.dart";
import "widgets/typing_indicator.dart";

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _TagHighlightController _controller = _TagHighlightController();
  final ScrollController _scrollController = ScrollController();
  String? _lastPrefill;
  final ImagePicker _picker = ImagePicker();
  List<Uint8List> _selectedImageBytes = [];
  List<String> _selectedImageBase64 = [];
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _sendingLock = false;
  bool _shouldAutoScroll = true;
  int _lastMessageCount = 0;
  bool _showTypeHintOptions = false;
  String _typeHintQuery = "";
  final FinanceApi _financeApi = FinanceApi(ApiClient());
  List<_ChatAccountOption> _accounts = const [];
  bool _loadingAccounts = false;
  int? _selectedAccountId;
  String? _selectedCategory;
  int? _selectedFromAccountId;
  int? _selectedToAccountId;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is Map && extra["prefill"] is String) {
      final text = extra["prefill"] as String;
      if (text != _lastPrefill) {
        _controller.text = text;
        _onInputChanged(text);
        _lastPrefill = text;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent + 120;
    if (jump) {
      _scrollController.jumpTo(target);
    } else {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path =
            "${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a";
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
          path: path,
        );
        setState(() {
          _isRecording = true;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("录音需要麦克风权限")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("录音失败: $e")),
      );
    }
  }

  Future<void> _stopRecording(ChatController notifier) async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      if (path != null) {
        final bytes = await XFile(path).readAsBytes();
        final base64String = base64Encode(bytes);
        notifier.sendText(audioBase64: base64String);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("处理录音失败: $e")),
      );
    }
  }

  Future<void> _pickImage() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      List<XFile> images = [];
      if (source == ImageSource.gallery) {
        images = await _picker.pickMultiImage(
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );
      } else {
        final single = await _picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );
        if (single != null) images = [single];
      }
      if (images.isEmpty) return;
      final bytesList = <Uint8List>[];
      final base64List = <String>[];
      for (final image in images) {
        final bytes = await image.readAsBytes();
        bytesList.add(bytes);
        base64List.add(base64Encode(bytes));
      }
      setState(() {
        _selectedImageBytes = [..._selectedImageBytes, ...bytesList];
        _selectedImageBase64 = [..._selectedImageBase64, ...base64List];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("选择图片失败: $e")),
      );
    }
  }

  void _removeImageAt(int index) {
    setState(() {
      if (index >= 0 && index < _selectedImageBytes.length) {
        _selectedImageBytes.removeAt(index);
        _selectedImageBase64.removeAt(index);
      }
    });
  }

  void _clearImages() {
    setState(() {
      _selectedImageBytes = [];
      _selectedImageBase64 = [];
    });
  }

  Future<void> _handleSend(ChatController notifier) async {
    if (_sendingLock) return;
    final text = _controller.text.trim();
    final imageBase64 = _selectedImageBase64;
    if (text.isEmpty && imageBase64.isEmpty) return;
    final currentTypeHint = _currentFinanceTypeHint;
    final draftDefaults = <String, dynamic>{};
    if ((currentTypeHint == "expense" || currentTypeHint == "income") &&
        _selectedAccountId != null) {
      draftDefaults["account_id"] = _selectedAccountId;
    }
    if ((currentTypeHint == "expense" || currentTypeHint == "income") &&
        _selectedCategory != null &&
        _selectedCategory!.isNotEmpty) {
      draftDefaults["category"] = _selectedCategory;
    }
    if ((currentTypeHint == "transfer" || currentTypeHint == "repayment") &&
        _selectedFromAccountId != null &&
        _selectedToAccountId != null) {
      draftDefaults["from_account_id"] = _selectedFromAccountId;
      draftDefaults["to_account_id"] = _selectedToAccountId;
      if (currentTypeHint == "repayment") {
        draftDefaults["note"] = "还款";
      }
    }

    setState(() => _sendingLock = true);
    _controller.clear();
    _clearImages();
    setState(() {
      _showTypeHintOptions = false;
      _typeHintQuery = "";
      _selectedAccountId = null;
      _selectedCategory = null;
      _selectedFromAccountId = null;
      _selectedToAccountId = null;
    });
    _shouldAutoScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(jump: true);
    });
    notifier.sendText(
      text: text.isEmpty ? null : text,
      imageBase64: imageBase64.isEmpty ? null : imageBase64,
      draftDefaults: draftDefaults.isEmpty ? null : draftDefaults,
    );
    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    setState(() => _sendingLock = false);
  }

  void _onInputChanged(String value) {
    final cursor = _controller.selection.baseOffset;
    final uptoCursor = (cursor >= 0 && cursor <= value.length)
        ? value.substring(0, cursor)
        : value;
    final match = RegExp(r"(?:^|\s)@([a-zA-Z_]*)$").firstMatch(uptoCursor);
    setState(() {
      _showTypeHintOptions = match != null;
      _typeHintQuery = match?.group(1)?.toLowerCase() ?? "";
      final typeHint = _extractFinanceTypeHint(value);
      if (typeHint != "expense" && typeHint != "income") {
        _selectedAccountId = null;
        _selectedCategory = null;
      } else if (_selectedAccountId != null &&
          !_accountOptionsFor(typeHint).any((account) => account.id == _selectedAccountId)) {
        _selectedAccountId = null;
      }
      if (_selectedCategory != null &&
          !_categoryOptionsFor(typeHint)
              .any((option) => option.id == _selectedCategory)) {
        _selectedCategory = null;
      }
      if (typeHint != "transfer" && typeHint != "repayment") {
        _selectedFromAccountId = null;
        _selectedToAccountId = null;
      } else {
        final fromAccounts = _fromAccountOptionsFor(typeHint);
        final toAccounts = _toAccountOptionsFor(typeHint, _selectedFromAccountId);
        if (_selectedFromAccountId != null &&
            !fromAccounts.any((account) => account.id == _selectedFromAccountId)) {
          _selectedFromAccountId = null;
        }
        if (_selectedToAccountId != null &&
            !toAccounts.any((account) => account.id == _selectedToAccountId)) {
          _selectedToAccountId = null;
        }
      }
    });
  }

  String? get _currentFinanceTypeHint => _extractFinanceTypeHint(_controller.text);

  String? _extractFinanceTypeHint(String value) {
    final match = RegExp(
      r"(?:^|\s)@(expense|income|transfer|repayment)\b",
      caseSensitive: false,
    ).firstMatch(value);
    return match?.group(1)?.toLowerCase();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loadingAccounts = true);
    try {
      final rows = await _financeApi.getAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = rows.map(_ChatAccountOption.fromJson).toList();
        _loadingAccounts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAccounts = false);
    }
  }

  List<_ChatAccountOption> _accountOptionsFor(String? typeHint) {
    if (typeHint == "income") {
      return _accounts.where((account) => account.kind == "asset").toList();
    }
    if (typeHint == "expense") {
      return _accounts;
    }
    return const [];
  }

  List<_ChatAccountOption> _fromAccountOptionsFor(String? typeHint) {
    if (typeHint == "repayment") {
      return _accounts.where((account) => account.kind == "asset").toList();
    }
    if (typeHint == "transfer") {
      return _accounts;
    }
    return const [];
  }

  List<_ChatAccountOption> _toAccountOptionsFor(String? typeHint, int? fromAccountId) {
    final base = typeHint == "repayment"
        ? _accounts.where((account) => account.kind == "liability").toList()
        : typeHint == "transfer"
            ? _accounts
            : const <_ChatAccountOption>[];
    return base.where((account) => account.id != fromAccountId).toList();
  }

  List<_CategoryOption> _categoryOptionsFor(String? typeHint) {
    if (typeHint == "expense") {
      return const [
        _CategoryOption("food", "餐饮"),
        _CategoryOption("transport", "交通"),
        _CategoryOption("shopping", "购物"),
        _CategoryOption("entertainment", "娱乐"),
        _CategoryOption("housing", "住房"),
        _CategoryOption("bills", "账单"),
        _CategoryOption("medical", "医疗"),
        _CategoryOption("education", "教育"),
        _CategoryOption("personal_care", "个人护理"),
        _CategoryOption("other", "其他"),
      ];
    }
    if (typeHint == "income") {
      return const [
        _CategoryOption("salary", "工资"),
        _CategoryOption("bonus", "奖金"),
        _CategoryOption("freelance", "副业"),
        _CategoryOption("refund", "退款"),
        _CategoryOption("gift", "礼金"),
        _CategoryOption("investment", "投资"),
        _CategoryOption("other", "其他"),
      ];
    }
    return const [];
  }

  List<_TypeHintOption> get _typeHintOptions {
    const options = [
      _TypeHintOption(id: "income", label: "收入", alias: "income"),
      _TypeHintOption(id: "expense", label: "支出", alias: "expense"),
      _TypeHintOption(id: "transfer", label: "转账", alias: "transfer"),
      _TypeHintOption(id: "repayment", label: "还款", alias: "repayment"),
      _TypeHintOption(id: "lifelog", label: "日志", alias: "lifelog"),
      _TypeHintOption(id: "meal", label: "餐食", alias: "meal"),
      _TypeHintOption(id: "task", label: "任务", alias: "task"),
    ];
    if (_typeHintQuery.isEmpty) return options;
    return options
        .where((e) =>
            e.id.contains(_typeHintQuery) ||
            e.alias.contains(_typeHintQuery) ||
            e.label.contains(_typeHintQuery))
        .toList();
  }

  void _applyTypeHint(_TypeHintOption option) {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset.clamp(0, text.length).toInt();
    final left = text.substring(0, cursor);
    final right = text.substring(cursor);
    final match = RegExp(r"@([a-zA-Z_]*)$").firstMatch(left);
    var newLeft = left;
    if (match != null) {
      newLeft = left.replaceRange(match.start, match.end, "@${option.id} ");
    }
    final merged = "$newLeft$right";
    final nextCursor = newLeft.length;
    _controller.value = TextEditingValue(
      text: merged,
      selection: TextSelection.collapsed(offset: nextCursor),
    );
    setState(() {
      _showTypeHintOptions = false;
      _typeHintQuery = "";
    });
  }

  Widget _buildTypeHintPicker() {
    final options = _typeHintOptions;
    if (!_showTypeHintOptions || options.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: options.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final item = options[i];
            return ActionChip(
              label: Text("@${item.id} · ${item.label}"),
              onPressed: () => _applyTypeHint(item),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAccountPicker() {
    final typeHint = _currentFinanceTypeHint;
    if (typeHint != "expense" && typeHint != "income") {
      return const SizedBox.shrink();
    }

    final accounts = _accountOptionsFor(typeHint);
    final label = typeHint == "income" ? "入账账户" : "支付账户";

    if (_loadingAccounts) {
      return const LinearProgressIndicator(minHeight: 2);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(
            typeHint == "income" ? Icons.savings_outlined : Icons.account_balance_wallet_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<int?>(
              initialValue:
                  accounts.any((account) => account.id == _selectedAccountId)
                      ? _selectedAccountId
                      : null,
              decoration: InputDecoration(
                labelText: label,
                isDense: true,
                border: InputBorder.none,
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text("不指定账户"),
                ),
                ...accounts.map(
                  (account) => DropdownMenuItem<int?>(
                    value: account.id,
                    child: Text(account.name),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _selectedAccountId = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPicker() {
    final typeHint = _currentFinanceTypeHint;
    if (typeHint != "expense" && typeHint != "income") {
      return const SizedBox.shrink();
    }
    final options = _categoryOptionsFor(typeHint);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.category_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: options.any((option) => option.id == _selectedCategory)
                  ? _selectedCategory
                  : null,
              decoration: const InputDecoration(
                labelText: "分类",
                isDense: true,
                border: InputBorder.none,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text("不指定分类"),
                ),
                ...options.map(
                  (option) => DropdownMenuItem<String?>(
                    value: option.id,
                    child: Text(option.label),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _selectedCategory = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferPicker() {
    final typeHint = _currentFinanceTypeHint;
    if (typeHint != "transfer" && typeHint != "repayment") {
      return const SizedBox.shrink();
    }
    final fromAccounts = _fromAccountOptionsFor(typeHint);
    final toAccounts = _toAccountOptionsFor(typeHint, _selectedFromAccountId);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<int?>(
            initialValue: fromAccounts.any((account) => account.id == _selectedFromAccountId)
                ? _selectedFromAccountId
                : null,
            decoration: InputDecoration(
              labelText: typeHint == "repayment" ? "还款账户" : "转出账户",
              isDense: true,
              border: InputBorder.none,
            ),
            items: fromAccounts
                .map(
                  (account) => DropdownMenuItem<int?>(
                    value: account.id,
                    child: Text(account.name),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _selectedFromAccountId = value;
              if (_selectedToAccountId == value) {
                _selectedToAccountId = null;
              }
            }),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            initialValue: toAccounts.any((account) => account.id == _selectedToAccountId)
                ? _selectedToAccountId
                : null,
            decoration: InputDecoration(
              labelText: typeHint == "repayment" ? "负债账户" : "转入账户",
              isDense: true,
              border: InputBorder.none,
            ),
            items: toAccounts
                .map(
                  (account) => DropdownMenuItem<int?>(
                    value: account.id,
                    child: Text(account.name),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedToAccountId = value),
          ),
        ],
      ),
    );
  }

  Widget? _buildInputTopContent() {
    final showMoneyPicker = _currentFinanceTypeHint == "expense" ||
        _currentFinanceTypeHint == "income";
    final showTransferPicker = _currentFinanceTypeHint == "transfer" ||
        _currentFinanceTypeHint == "repayment";
    if (!_showTypeHintOptions && !showMoneyPicker && !showTransferPicker) {
      return null;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showTypeHintOptions) _buildTypeHintPicker(),
        if (_showTypeHintOptions && (showMoneyPicker || showTransferPicker))
          const SizedBox(height: 8),
        if (showMoneyPicker) _buildAccountPicker(),
        if (showMoneyPicker) const SizedBox(height: 8),
        if (showMoneyPicker) _buildCategoryPicker(),
        if (showTransferPicker) _buildTransferPicker(),
      ],
    );
  }

  void _showMoreMenu(BuildContext context, ChatController notifier) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.dashboard_outlined),
                title: const Text("Dashboard"),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.go("/dashboard");
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text("Finance"),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.go("/finance");
                },
              ),
              ListTile(
                leading: const Icon(Icons.timeline),
                title: const Text("Timeline"),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.go("/timeline");
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_box_outlined),
                title: const Text("Tasks"),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.go("/tasks");
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text("Me"),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.go("/me");
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_none),
                title: const Text("Notifications"),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.push("/notifications");
                },
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.clear_all, color: AppColors.danger),
                title: const Text('清空当前上下文',
                    style: TextStyle(color: AppColors.danger)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  notifier.clearSession();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已清空当前聊天记忆')),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    final notifier = ref.read(chatControllerProvider.notifier);
    ref.listen<ChatState>(chatControllerProvider, (prev, next) {
      if (_lastMessageCount != next.messages.length) {
        _lastMessageCount = next.messages.length;
        if (_shouldAutoScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      }
    });

    final hasMessages = state.messages.isNotEmpty;

    return Scaffold(
      body: Column(
        children: [
          _Header(
            onNotifications: () => _openNotifications(context),
            onMore: () => _showMoreMenu(context, notifier),
            showDot: state.drafts.isNotEmpty,
            compact: hasMessages,
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  final metrics = notification.metrics;
                  final isNearBottom = metrics.extentAfter < 120;
                  _shouldAutoScroll = isNearBottom;
                }
                return false;
              },
              child: ListView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(16, hasMessages ? 8 : 12, 16, 16),
                children: [
                  if (!hasMessages) const _WelcomeSection(),
                  for (var i = 0; i < state.messages.length; i++)
                    Builder(
                      builder: (_) {
                        final message = state.messages[i];
                        final prevRole =
                            i > 0 ? state.messages[i - 1].role : null;
                        final nextRole = i < state.messages.length - 1
                            ? state.messages[i + 1].role
                            : null;
                        final mergeTop = prevRole == message.role;
                        final mergeBottom = nextRole == message.role;
                        final hasCards =
                            message.cards != null && message.cards!.isNotEmpty;
                        final cardsColumn = hasCards
                            ? Column(
                                children: message.cards!
                                    .map((c) => _buildCard(c, notifier))
                                    .toList(),
                              )
                            : null;
                        return MessageBubble(
                          message: message,
                          compactTop: mergeTop,
                          mergeTop: mergeTop,
                          mergeBottom: mergeBottom,
                          bottom: hasCards
                              ? _DelayedReveal(
                                  delay: const Duration(milliseconds: 140),
                                  child: cardsColumn!,
                                )
                              : null,
                        );
                      },
                    ),
                  if (state.loading)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: TypingIndicator(),
                    ),
                  if (state.clarifyQuestion != null)
                    _ClarifyBlock(text: state.clarifyQuestion!),
                  if (state.status != null) _StatusLine(text: state.status!),
                  if (state.hasError && state.lastFailedRequest != null)
                    ErrorBanner(
                      message: state.status ?? "请求失败",
                      onRetry: () => notifier.retry(),
                    ),
                ],
              ),
            ),
          ),
          AnimatedSlide(
            duration: const Duration(milliseconds: 250),
            offset:
                state.drafts.length > 1 ? Offset.zero : const Offset(0, 0.2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: state.drafts.length > 1 ? 1 : 0,
              child: ConfirmBar(
                count: state.drafts.length,
                onConfirmAll: () => notifier.confirmDrafts(
                  state.drafts.map((d) => d.draftId).toList(),
                ),
              ),
            ),
          ),
          InputBar(
            controller: _controller,
            loading: state.loading || _sendingLock,
            isRecording: _isRecording,
            selectedImages: _selectedImageBytes,
            onChanged: _onInputChanged,
            topContent: _buildInputTopContent(),
            onPickImage: _pickImage,
            onRemoveImageAt: _removeImageAt,
            onStartRecord: _startRecording,
            onStopRecord: () => _stopRecording(notifier),
            onSend: () => _handleSend(notifier),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(CardDto card, ChatController notifier) {
    final taskId = _extractTaskId(card);
    return CardRenderer(
      card: card,
      onConfirm: () => notifier.confirmDrafts([card.cardId]),
      onEdit: () => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => CardEditSheet(
          card: card,
          onSubmit: (patch) => notifier.editDraft(card.cardId, patch),
        ),
      ),
      onComplete:
          card.type == "task" && card.status != "draft" && taskId != null
              ? () => notifier.taskAction(taskId: taskId, op: "complete")
              : null,
      onPostpone:
          card.type == "task" && card.status != "draft" && taskId != null
              ? () => _postponeTask(taskId, notifier)
              : null,
      onDelete: card.type == "task" && card.status != "draft" && taskId != null
          ? () => notifier.taskAction(taskId: taskId, op: "delete")
          : null,
    );
  }

  void _openNotifications(BuildContext context) {
    context.push("/notifications");
  }

  // 撤销提示已移动至 Timeline

  int? _extractTaskId(CardDto card) {
    final value = card.data["task_id"];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  Future<void> _postponeTask(int taskId, ChatController notifier) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (!mounted) return;
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (!mounted) return;
    if (time == null) return;
    final dt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    notifier.taskAction(
      taskId: taskId,
      op: "postpone",
      payload: {"due_at": toIsoWithOffset(dt)},
    );
  }
}

class _TagHighlightController extends TextEditingController {
  static final RegExp _tagPattern =
      RegExp(
        r"(?:^|\s)(@(expense|income|transfer|repayment|lifelog|meal|task)\b)",
        caseSensitive: false,
      );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final textValue = text;
    if (textValue.isEmpty) {
      return TextSpan(style: style, text: textValue);
    }

    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in _tagPattern.allMatches(textValue)) {
      final full = match.group(0)!;
      final leadingSpace = full.startsWith(" ") ? 1 : 0;
      final tagStart = match.start + leadingSpace;
      final tagEnd = match.end;

      if (tagStart > start) {
        spans.add(TextSpan(text: textValue.substring(start, tagStart), style: style));
      }
      spans.add(
        TextSpan(
          text: textValue.substring(tagStart, tagEnd),
          style: (style ?? const TextStyle()).copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      start = tagEnd;
    }

    if (start < textValue.length) {
      spans.add(TextSpan(text: textValue.substring(start), style: style));
    }
    return TextSpan(style: style, children: spans);
  }
}

class _TypeHintOption {
  const _TypeHintOption({
    required this.id,
    required this.label,
    required this.alias,
  });

  final String id;
  final String label;
  final String alias;
}

class _ChatAccountOption {
  const _ChatAccountOption({
    required this.id,
    required this.name,
    required this.kind,
  });

  final int id;
  final String name;
  final String kind;

  factory _ChatAccountOption.fromJson(Map<String, dynamic> json) {
    return _ChatAccountOption(
      id: json["id"] as int? ?? 0,
      name: json["name"] as String? ?? "",
      kind: json["kind"] as String? ?? "asset",
    );
  }
}

class _CategoryOption {
  const _CategoryOption(this.id, this.label);

  final String id;
  final String label;
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.icon, required this.showDot});

  final IconData icon;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (showDot)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _ClarifyBlock extends StatelessWidget {
  const _ClarifyBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text("需要补充：$text"),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 14, color: AppColors.success),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onNotifications,
    required this.onMore,
    required this.showDot,
    required this.compact,
  });

  final VoidCallback onNotifications;
  final VoidCallback onMore;
  final bool showDot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(16, compact ? 10 : 14, 16, compact ? 6 : 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Assistant",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 4),
                    Text(
                      "说句话，我来帮你记录、整理和提醒",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: onNotifications,
              icon: _BadgeIcon(
                icon: Icons.notifications_none,
                showDot: showDot,
              ),
            ),
            IconButton(
              onPressed: onMore,
              icon: const Icon(Icons.more_horiz),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeSection extends StatefulWidget {
  const _WelcomeSection();

  @override
  State<_WelcomeSection> createState() => _WelcomeSectionState();
}

class _WelcomeSectionState extends State<_WelcomeSection> {
  _DailyQuote? _quote;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchQuote();
  }

  Future<void> _fetchQuote() async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );
      final resp = await dio.get("https://v1.hitokoto.cn/");
      final data = (resp.data as Map?)?.cast<String, dynamic>();
      if (data == null) return;
      final hitokoto = data["hitokoto"] as String?;
      final from = data["from"] as String?;
      if (!mounted) return;
      setState(() {
        _quote = _DailyQuote(
          text: (hitokoto == null || hitokoto.trim().isEmpty)
              ? "\u4e16\u95f4\u6240\u6709\u7684\u76f8\u9047\uff0c\u90fd\u662f\u4e45\u522b\u91cd\u9022\u3002"
              : hitokoto.trim(),
          from: (from == null || from.trim().isEmpty) ? "\u672a\u77e5" : from.trim(),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _quote = const _DailyQuote(
          text: "\u4e16\u95f4\u6240\u6709\u7684\u76f8\u9047\uff0c\u90fd\u662f\u4e45\u522b\u91cd\u9022\u3002",
          from: "\u4e00\u4ee3\u5b97\u5e08",
        );
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote ??
        const _DailyQuote(
          text: "\u4e16\u95f4\u6240\u6709\u7684\u76f8\u9047\uff0c\u90fd\u662f\u4e45\u522b\u91cd\u9022\u3002",
          from: "\u4e00\u4ee3\u5b97\u5e08",
        );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.accentLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                Text(
                  "\u6bcf\u65e5\u4e00\u8a00",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(minHeight: 2),
              )
            else ...[
              Text(
                "\"${quote.text}\"",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                "\u2014\u2014\u300a${quote.from}\u300b",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
class _DailyQuote {
  const _DailyQuote({required this.text, required this.from});

  final String text;
  final String from;
}
class _DelayedReveal extends StatefulWidget {
  const _DelayedReveal({
    required this.child,
    this.delay = const Duration(milliseconds: 120),
  });

  final Widget child;
  final Duration delay;

  @override
  State<_DelayedReveal> createState() => _DelayedRevealState();
}

class _DelayedRevealState extends State<_DelayedReveal> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        offset: _visible ? Offset.zero : const Offset(0, 0.03),
        child: widget.child,
      ),
    );
  }
}
