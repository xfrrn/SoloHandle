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
        message: state.searchQuery.isNotEmpty ? "没有找到匹配的记录" : "暂无记录，去 Chat 页面记录吧",
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
              ...events.map((event) => _TimelineCard(event: event)),
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
              Icon(icon, size: 16, color: selected ? AppColors.accent : iconColor),
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
  const _TimelineCard({required this.event});

  final EventDto event;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(4),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
