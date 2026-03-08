import "dart:convert";

import "package:flutter/material.dart";

import "../../../core/constants.dart";
import "../../../core/time.dart";
import "../../../data/api/dto.dart";

class CardRenderer extends StatefulWidget {
  const CardRenderer({
    super.key,
    required this.card,
    required this.onConfirm,
    required this.onEdit,
    this.onComplete,
    this.onPostpone,
    this.onDelete,
  });

  final CardDto card;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;
  final VoidCallback? onComplete;
  final VoidCallback? onPostpone;
  final VoidCallback? onDelete;

  @override
  State<CardRenderer> createState() => _CardRendererState();
}

class _CardRendererState extends State<CardRenderer> {
  bool _showActions = false;

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final isDraft = card.status == "draft";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDraft
              ? AppColors.accent.withValues(alpha: 0.45)
              : AppColors.divider,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _showActions = !_showActions),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CardAvatar(type: card.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayTitle(card),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _headerSubtitle(card),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: card.status),
              ],
            ),
            const SizedBox(height: 12),
            _buildContent(context, card),
            const SizedBox(height: 12),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _showActions ? 1 : 0,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: _showActions ? _buildActions(card) : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayTitle(CardDto card) {
    if (card.title.isNotEmpty) return card.title;
    return switch (card.type) {
      "income" => "收入",
      "expense" => "支出",
      "transfer" => "转账",
      "meal" => "餐食",
      "mood" => "心情",
      "lifelog" => "日志",
      "task" => "任务",
      _ => "记录",
    };
  }

  String _headerSubtitle(CardDto card) {
    if (card.type == "income") {
      return _moneySubtitle(card, isIncome: true);
    }
    if (card.type == "expense") {
      return _moneySubtitle(card, isIncome: false);
    }
    if (card.type == "transfer") {
      final from = _firstNonEmpty([card.data["from_account_name"]?.toString()]);
      final to = _firstNonEmpty([card.data["to_account_name"]?.toString()]);
      final note = _firstNonEmpty([card.data["note"]?.toString()]);
      if (note.isNotEmpty) return note;
      if (from.isNotEmpty && to.isNotEmpty) return "$from → $to";
      return "账户转账";
    }
    if (card.type == "meal") {
      final mealType = _mealTypeLabel(card.data["meal_type"]?.toString());
      final items = _firstNonEmpty([
        card.data["items"]?.toString(),
        card.data["note"]?.toString(),
      ]);
      return items.isNotEmpty ? "$mealType · $items" : mealType;
    }
    if (card.type == "mood") {
      final mood = _firstNonEmpty([
        card.data["mood"]?.toString(),
        card.data["valence"]?.toString(),
      ]);
      return mood.isNotEmpty ? "心情 · $mood" : "心情记录";
    }
    if (card.type == "lifelog") {
      final title = _firstNonEmpty([
        card.data["title"]?.toString(),
        card.data["note"]?.toString(),
      ]);
      return title.isNotEmpty ? title : "生活记录";
    }
    if (card.type == "task") {
      return _subtitleFromData(card.data);
    }
    return card.subtitle.isNotEmpty ? card.subtitle : _subtitleFromData(card.data);
  }

  String _moneySubtitle(CardDto card, {required bool isIncome}) {
    final amount = _asNum(card.data["amount"]);
    final category = _categoryLabel(card.data["category"]?.toString());
    final accountName = _firstNonEmpty([card.data["account_name"]?.toString()]);
    final parts = <String>[category];
    if (accountName.isNotEmpty) {
      parts.add(accountName);
    }
    if (amount != null) {
      final prefix = isIncome ? "" : "¥";
      return "$prefix${_formatAmount(amount)} · ${parts.join(" · ")}";
    }
    return parts.join(" · ");
  }

  Widget _buildContent(BuildContext context, CardDto card) {
    switch (card.type) {
      case "income":
        return _buildMoneyContent(card, isIncome: true);
      case "expense":
        return _buildMoneyContent(card, isIncome: false);
      case "transfer":
        return _buildTransferContent(card);
      case "meal":
        return _buildMealContent(card);
      case "mood":
        return _buildMoodContent(card);
      case "lifelog":
        return _buildLifelogContent(card);
      case "task":
        return _buildTaskContent(card);
      default:
        return _buildGenericContent(card);
    }
  }

  Widget _buildMoneyContent(CardDto card, {required bool isIncome}) {
    final amount = _asNum(card.data["amount"]);
    final currencyValue = card.data["currency"]?.toString().trim();
    final currency = (currencyValue?.isNotEmpty ?? false) ? currencyValue! : "CNY";
    final category = _categoryLabel(card.data["category"]?.toString());
    final accountName = _firstNonEmpty([card.data["account_name"]?.toString()]);
    final note = _firstNonEmpty([card.data["note"]?.toString()]);
    final time = _friendlyTime(card.data["happened_at"] ?? card.data["time"]);
    final secondaryParts = <String>[category];
    if (accountName.isNotEmpty) {
      secondaryParts.add(accountName);
    }
    if (note.isNotEmpty) {
      secondaryParts.add(note);
    }
    final sign = isIncome ? "+" : "¥";
    return _CardBody(
      primary: amount != null ? "$sign${_formatAmount(amount)} $currency" : "",
      secondary: secondaryParts.join(" · "),
      tertiary: time,
    );
  }

  Widget _buildMealContent(CardDto card) {
    final mealType = _mealTypeLabel(card.data["meal_type"]?.toString());
    final items = _firstNonEmpty([
      card.data["items"]?.toString(),
      card.data["note"]?.toString(),
    ]);
    final time = _friendlyTime(card.data["happened_at"] ?? card.data["time"]);
    return _CardBody(
      primary: mealType,
      secondary: items,
      tertiary: time,
    );
  }

  Widget _buildTransferContent(CardDto card) {
    final amount = _asNum(card.data["amount"]);
    final currencyValue = card.data["currency"]?.toString().trim();
    final currency = (currencyValue?.isNotEmpty ?? false) ? currencyValue! : "CNY";
    final from = _firstNonEmpty([card.data["from_account_name"]?.toString()]);
    final to = _firstNonEmpty([card.data["to_account_name"]?.toString()]);
    final note = _firstNonEmpty([card.data["note"]?.toString()]);
    final time = _friendlyTime(card.data["happened_at"] ?? card.data["time"]);
    final secondary = note.isNotEmpty
        ? note
        : (from.isNotEmpty && to.isNotEmpty ? "$from → $to" : "");
    return _CardBody(
      primary: amount != null ? "¥${_formatAmount(amount)} $currency" : "",
      secondary: secondary,
      tertiary: time,
    );
  }

  Widget _buildMoodContent(CardDto card) {
    final mood = _firstNonEmpty([
      card.data["mood"]?.toString(),
      card.data["valence"]?.toString(),
    ]);
    final note = _firstNonEmpty([card.data["note"]?.toString()]);
    final time = _friendlyTime(card.data["happened_at"] ?? card.data["time"]);
    return _CardBody(
      primary: mood.isNotEmpty ? mood : "心情记录",
      secondary: note,
      tertiary: time,
    );
  }

  Widget _buildLifelogContent(CardDto card) {
    final title = _firstNonEmpty([
      card.data["title"]?.toString(),
      card.data["text"]?.toString(),
      card.data["note"]?.toString(),
      card.data["content"]?.toString(),
    ]);
    final images = _readImageBase64List(card.data["images"]);
    final time = _friendlyTime(card.data["happened_at"] ?? card.data["time"]);
    if (images.isEmpty) {
      return _CardBody(
        primary: title.isNotEmpty ? title : "生活记录",
        secondary: "",
        tertiary: time,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty || time.isNotEmpty)
          _CardBody(
            primary: title,
            secondary: "",
            tertiary: time,
          ),
        if (title.isNotEmpty || time.isNotEmpty) const SizedBox(height: 8),
        _InlineImageGrid(images: images),
      ],
    );
  }

  Widget _buildTaskContent(CardDto card) {
    final title = _firstNonEmpty([
      card.data["title"]?.toString(),
      card.title,
    ]);
    final due = card.data["due_at"]?.toString();
    final remind = card.data["remind_at"]?.toString();
    final time = _firstNonEmpty([
      due != null ? "截止 ${formatIsoToFriendly(due)}" : "",
      remind != null ? "提醒 ${formatIsoToFriendly(remind)}" : "",
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CardBody(
          primary: title.isNotEmpty ? title : "任务",
          secondary: time,
          tertiary: "",
        ),
        if (_taskBadges(card.data).isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _taskBadges(card.data).map((text) => _Badge(text: text)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildGenericContent(CardDto card) {
    final note = _firstNonEmpty([card.data["note"]?.toString()]);
    final time = _friendlyTime(card.data["happened_at"] ?? card.data["time"]);
    return _CardBody(
      primary: card.subtitle,
      secondary: note,
      tertiary: time,
    );
  }

  String _friendlyTime(Object? value) {
    if (value is String && value.isNotEmpty) {
      return formatIsoToFriendly(value);
    }
    return "";
  }

  double? _asNum(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? "");
  }

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String _categoryLabel(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "未分类";
    }
    return value.trim();
  }

  String _mealTypeLabel(String? value) {
    return switch (value) {
      "breakfast" => "早餐",
      "lunch" => "午餐",
      "dinner" => "晚餐",
      "snack" => "加餐",
      _ => "餐食",
    };
  }

  String _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return "";
  }

  List<String> _readImageBase64List(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Widget _buildActions(CardDto card) {
    if (card.status == "draft") {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: widget.onEdit,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text("修改"),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: widget.onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text("确认提交"),
          ),
        ],
      );
    }

    if (card.type == "task" &&
        (widget.onComplete != null || widget.onPostpone != null || widget.onDelete != null)) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (widget.onPostpone != null) ...[
            OutlinedButton(
              onPressed: widget.onPostpone,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.divider),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("延期"),
            ),
            const SizedBox(width: 8),
          ],
          if (widget.onDelete != null) ...[
            OutlinedButton(
              onPressed: widget.onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.dangerLight),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("删除"),
            ),
            const SizedBox(width: 8),
          ],
          if (widget.onComplete != null)
            ElevatedButton(
              onPressed: widget.onComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("完成"),
            ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  String _subtitleFromData(Map<String, dynamic> data) {
    final due = data["due_at"];
    final remind = data["remind_at"];
    final priority = data["priority"];
    final parts = <String>[];
    if (due is String && due.isNotEmpty) {
      parts.add("截止：${formatIsoToFriendly(due)}");
    }
    if (remind is String && remind.isNotEmpty) {
      parts.add("提醒：${formatIsoToFriendly(remind)}");
    }
    if (priority is String && priority.isNotEmpty) {
      parts.add("优先级：${_priorityLabel(priority)}");
    }
    if (parts.isNotEmpty) return parts.join(" · ");
    final time = data["time"] ?? data["happened_at"];
    if (time is String && time.isNotEmpty) {
      return "时间：${formatIsoToFriendly(time)}";
    }
    return "";
  }

  String _priorityLabel(String value) {
    return switch (value) {
      "low" => "低",
      "high" => "高",
      _ => "中",
    };
  }

  List<String> _taskBadges(Map<String, dynamic> data) {
    final priority = data["priority"];
    final status = data["status"];
    final badges = <String>[];
    if (priority is String && priority.isNotEmpty) {
      badges.add(_priorityLabel(priority));
    }
    if (status is String && status.isNotEmpty) {
      badges.add(_statusLabel(status));
    }
    return badges;
  }

  String _statusLabel(String value) {
    return switch (value) {
      "done" => "已完成",
      "canceled" => "已取消",
      _ => "进行中",
    };
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  final String primary;
  final String secondary;
  final String tertiary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (primary.isNotEmpty)
          Text(
            primary,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
          ),
        if (secondary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            secondary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
        ],
        if (tertiary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            tertiary,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF444444),
            ),
      ),
    );
  }
}

class _InlineImageGrid extends StatelessWidget {
  const _InlineImageGrid({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          base64Decode(images.first),
          fit: BoxFit.cover,
          height: 160,
          width: double.infinity,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: images.length > 6 ? 6 : images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            base64Decode(images[index]),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFF2F2F2),
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined, size: 18),
            ),
          ),
        );
      },
    );
  }
}

class _CardAvatar extends StatelessWidget {
  const _CardAvatar({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    Color bgColor;
    Color iconColor;

    switch (type) {
      case "income":
        iconData = Icons.savings_outlined;
        bgColor = AppColors.successLight;
        iconColor = AppColors.success;
        break;
      case "expense":
        iconData = Icons.receipt_long;
        bgColor = AppColors.warningLight;
        iconColor = AppColors.warning;
        break;
      case "transfer":
        iconData = Icons.swap_horiz;
        bgColor = AppColors.accentLight;
        iconColor = AppColors.accent;
        break;
      case "task":
        iconData = Icons.check_circle_outline;
        bgColor = AppColors.accentLight;
        iconColor = AppColors.accent;
        break;
      case "mood":
        iconData = Icons.mood;
        bgColor = AppColors.successLight;
        iconColor = AppColors.success;
        break;
      default:
        iconData = Icons.event_note;
        bgColor = const Color(0xFFF1F5F9);
        iconColor = const Color(0xFF64748B);
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    if (status == "draft") {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          "草稿",
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (status == "failed") {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          "失败",
          style: TextStyle(
            color: AppColors.danger,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Text(
      "已提交",
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
    );
  }
}
