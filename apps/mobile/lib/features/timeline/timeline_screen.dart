import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/constants.dart";
import "../../core/time.dart";
import "../../data/api/models.dart";
import "timeline_controller.dart";

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(timelineControllerProvider.notifier).loadEvents();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timelineControllerProvider);
    final notifier = ref.read(timelineControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text("Timeline")),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: "搜索记录...",
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          notifier.setSearchQuery("");
                          notifier.loadEvents();
                        },
                      )
                    : null,
              ),
              onSubmitted: (value) {
                notifier.setSearchQuery(value);
                notifier.loadEvents();
              },
            ),
          ),
          const SizedBox(height: 10),

          // Type filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: "全部",
                    selected: state.selectedTypes.isEmpty,
                    onTap: () => notifier.clearFilters(),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: "支出",
                    icon: Icons.receipt_long,
                    iconColor: AppColors.warning,
                    selected: state.selectedTypes.contains("expense"),
                    onTap: () => notifier.toggleType("expense"),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: "心情",
                    icon: Icons.mood,
                    iconColor: AppColors.success,
                    selected: state.selectedTypes.contains("mood"),
                    onTap: () => notifier.toggleType("mood"),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: "用餐",
                    icon: Icons.restaurant,
                    iconColor: const Color(0xFFE76F51),
                    selected: state.selectedTypes.contains("meal"),
                    onTap: () => notifier.toggleType("meal"),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: "日志",
                    icon: Icons.event_note,
                    iconColor: AppColors.accent,
                    selected: state.selectedTypes.contains("life_log"),
                    onTap: () => notifier.toggleType("life_log"),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Content
          Expanded(child: _buildBody(state, notifier)),
        ],
      ),
    );
  }

  Widget _buildBody(TimelineState state, TimelineController notifier) {
    if (state.loading && state.events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.events.isEmpty) {
      return _EmptyState(
        icon: Icons.error_outline,
        message: state.error!,
        action: TextButton.icon(
          onPressed: () => notifier.loadEvents(),
          icon: const Icon(Icons.refresh),
          label: const Text("重试"),
        ),
      );
    }

    final grouped = state.groupedByDate;
    if (grouped.isEmpty) {
      return _EmptyState(
        icon: Icons.timeline,
        message:
            state.searchQuery.isNotEmpty ? "没有找到匹配的记录" : "暂无记录，去 Chat 页面记录吧",
      );
    }

    final dateKeys = grouped.keys.toList();

    return RefreshIndicator(
      onRefresh: () => notifier.loadEvents(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: dateKeys.length,
        itemBuilder: (context, index) {
          final dateKey = dateKeys[index];
          final events = grouped[dateKey]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  dateKey,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
              ...events.map((event) {
                final expanded = state.expandedEventId == event.eventId;
                return Column(
                  children: [
                    _TimelineCard(
                      event: event,
                      expanded: expanded,
                      onTap: () => notifier.toggleExpanded(event.eventId),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: expanded ? 1 : 0,
                        child: expanded
                            ? _TimelineDetailCard(
                                event: event,
                                canUndo: event.commitId != null &&
                                    event.commitId!.isNotEmpty,
                                loading: state.undoLoading,
                                onUndo: () => notifier.undoCommit(event.commitId!),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

// ─── Widgets ─────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withAlpha(30) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 16, color: selected ? AppColors.accent : iconColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.accent : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.event,
    required this.onTap,
    required this.expanded,
  });

  final EventDto event;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: expanded ? AppColors.accentLight.withOpacity(0.5) : AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(14),
            bottom: Radius.circular(expanded ? 0 : 14),
          ),
          border: Border.all(
            color: expanded ? AppColors.accent.withOpacity(0.4) : AppColors.divider,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(expanded ? 0.10 : 0.04),
              blurRadius: expanded ? 14 : 8,
              offset: Offset(0, expanded ? 6 : 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _TypeAvatar(type: event.type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.displayTitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(event.happenedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            _TypeLabel(type: event.type),
          ],
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    return formatIsoToLocal(iso);
  }
}

class _TypeAvatar extends StatelessWidget {
  const _TypeAvatar({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    Color bgColor;
    Color iconColor;

    switch (type) {
      case "expense":
        iconData = Icons.receipt_long;
        bgColor = AppColors.warningLight;
        iconColor = AppColors.warning;
        break;
      case "meal":
        iconData = Icons.restaurant;
        bgColor = const Color(0xFFFFF0EB);
        iconColor = const Color(0xFFE76F51);
        break;
      case "mood":
        iconData = Icons.mood;
        bgColor = AppColors.successLight;
        iconColor = AppColors.success;
        break;
      case "life_log":
        iconData = Icons.event_note;
        bgColor = AppColors.accentLight;
        iconColor = AppColors.accent;
        break;
      default:
        iconData = Icons.circle;
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

class _TypeLabel extends StatelessWidget {
  const _TypeLabel({required this.type});

  final String type;

  String get _label {
    switch (type) {
      case "expense":
        return "支出";
      case "meal":
        return "用餐";
      case "mood":
        return "心情";
      case "life_log":
        return "日志";
      default:
        return type;
    }
  }

  Color get _color {
    switch (type) {
      case "expense":
        return AppColors.warning;
      case "meal":
        return const Color(0xFFE76F51);
      case "mood":
        return AppColors.success;
      case "life_log":
        return AppColors.accent;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.divider),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

class _TimelineDetailCard extends StatefulWidget {
  const _TimelineDetailCard({
    required this.event,
    required this.canUndo,
    required this.loading,
    required this.onUndo,
  });

  final EventDto event;
  final bool canUndo;
  final bool loading;
  final VoidCallback onUndo;

  @override
  State<_TimelineDetailCard> createState() => _TimelineDetailCardState();
}

class _TimelineDetailCardState extends State<_TimelineDetailCard> {
  bool _showMore = false;
  bool _noteExpanded = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final typeMeta = _DetailMeta.fromEvent(event);
    final note = event.data["note"]?.toString() ?? "";
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(14),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 1,
            color: AppColors.divider,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(typeMeta.icon, size: 16, color: typeMeta.color),
              const SizedBox(width: 6),
              Text(
                typeMeta.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: typeMeta.color,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailPrimary(event: event, meta: typeMeta),
          const SizedBox(height: 10),
          if (typeMeta.secondary.isNotEmpty)
            Text(
              typeMeta.secondary,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ExpandableNote(
              text: note,
              expanded: _noteExpanded,
              onToggle: () => setState(() => _noteExpanded = !_noteExpanded),
            ),
          ],
          const SizedBox(height: 10),
          _KeyValueList(items: _buildDetailItems(event, showMore: _showMore)),
          if (_hasMoreFields(event)) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _showMore = !_showMore),
                child: Text(_showMore ? "收起更多信息" : "更多信息"),
              ),
            ),
          ],
          if (widget.canUndo) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: widget.loading ? null : widget.onUndo,
                icon: widget.loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.undo),
                label: const Text("撤销这次提交"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(color: AppColors.danger.withOpacity(0.5)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailMeta {
  const _DetailMeta({
    required this.label,
    required this.icon,
    required this.color,
    required this.primary,
    required this.secondary,
    required this.primarySize,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String primary;
  final String secondary;
  final double primarySize;

  static _DetailMeta fromEvent(EventDto event) {
    switch (event.type) {
      case "expense":
        final amount = event.data["amount"];
        final cat = event.data["category"] ?? "unknown";
        final currency = event.data["currency"] ?? "CNY";
        final note = event.data["note"] ?? "";
        return _DetailMeta(
          label: "支出记录",
          icon: Icons.receipt_long,
          color: AppColors.warning,
          primary: "¥$amount",
          secondary: "$cat · $currency${note.toString().isNotEmpty ? " · $note" : ""}",
          primarySize: 26,
        );
      case "meal":
        final items = (event.data["items"] as List?)?.join("、") ?? "用餐记录";
        return _DetailMeta(
          label: "用餐记录",
          icon: Icons.restaurant,
          color: const Color(0xFFE76F51),
          primary: items,
          secondary: "餐别：${event.data["meal_type"] ?? "unknown"}",
          primarySize: 20,
        );
      case "mood":
        final mood = event.data["mood"] ?? event.data["emotion"] ?? "心情";
        return _DetailMeta(
          label: "心情记录",
          icon: Icons.mood,
          color: AppColors.success,
          primary: mood.toString(),
          secondary: "强度：${event.data["intensity"] ?? "-"}",
          primarySize: 20,
        );
      case "life_log":
        final text = event.data["text"] ?? event.data["description"] ?? "生活记录";
        return _DetailMeta(
          label: "日志记录",
          icon: Icons.event_note,
          color: AppColors.accent,
          primary: text.toString(),
          secondary: "",
          primarySize: 18,
        );
      default:
        return _DetailMeta(
          label: event.type,
          icon: Icons.circle,
          color: AppColors.textSecondary,
          primary: event.displayTitle,
          secondary: "",
          primarySize: 18,
        );
    }
  }
}

class _DetailPrimary extends StatelessWidget {
  const _DetailPrimary({required this.event, required this.meta});

  final EventDto event;
  final _DetailMeta meta;

  @override
  Widget build(BuildContext context) {
    return Text(
      meta.primary,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: meta.primarySize,
            color: AppColors.textPrimary,
          ),
    );
  }
}

class _KeyValueList extends StatelessWidget {
  const _KeyValueList({required this.items});

  final List<MapEntry<String, String>> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  item.key,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
              Expanded(
                flex: 7,
                child: Text(
                  item.value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

List<MapEntry<String, String>> _buildDetailItems(EventDto event,
    {required bool showMore}) {
  final items = <MapEntry<String, String>>[];
  items.add(MapEntry("时间", formatIsoToLocal(event.happenedAt)));
  if (event.data["topic"] != null && event.data["topic"].toString().isNotEmpty) {
    items.add(MapEntry("主题", event.data["topic"].toString()));
  }
  if (event.tags.isNotEmpty) {
    items.add(MapEntry("标签", event.tags.join(" · ")));
  }
  if (showMore) {
    if (event.data["currency"] != null &&
        event.data["currency"].toString().isNotEmpty) {
      items.add(MapEntry("币种", event.data["currency"].toString()));
    }
    items.add(MapEntry("来源", event.source));
    items.add(MapEntry("创建", formatIsoToLocal(event.createdAt)));
  }
  return items;
}

bool _hasMoreFields(EventDto event) {
  return (event.data["currency"] != null &&
          event.data["currency"].toString().isNotEmpty) ||
      event.source.isNotEmpty ||
      event.createdAt.isNotEmpty;
}

class _ExpandableNote extends StatelessWidget {
  const _ExpandableNote({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          maxLines: 2,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final overflow = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              maxLines: expanded ? null : 2,
              overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (overflow)
              TextButton(
                onPressed: onToggle,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(expanded ? "收起" : "展开备注"),
              ),
          ],
        );
      },
    );
  }
}
