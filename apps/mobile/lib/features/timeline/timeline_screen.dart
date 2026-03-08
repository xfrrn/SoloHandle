import "dart:convert";

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
      final state = ref.read(timelineControllerProvider);
      if (state.events.isEmpty && !state.loading) {
        ref.read(timelineControllerProvider.notifier).loadEvents();
      }
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
      body: Column(
        children: [
          _Header(onRefresh: notifier.loadEvents),
          _buildSearch(notifier),
          const SizedBox(height: 8),
          _buildFilters(state, notifier),
          const SizedBox(height: 8),
          Expanded(child: _buildBody(state, notifier)),
        ],
      ),
    );
  }

  Widget _buildSearch(TimelineController notifier) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        onSubmitted: (v) {
          notifier.setSearchQuery(v);
          notifier.loadEvents();
        },
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, size: 18),
          hintText: "\u641C\u7D22\u8BB0\u5F55...",
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.accent),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    notifier.setSearchQuery("");
                    notifier.loadEvents();
                    setState(() {});
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilters(TimelineState state, TimelineController notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: "\u5168\u90E8",
              selected: state.selectedTypes.isEmpty,
              onTap: notifier.clearFilters,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: "\u652F\u51FA",
              selected: state.selectedTypes.contains("expense"),
              onTap: () => notifier.toggleType("expense"),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: "\u5FC3\u60C5",
              selected: state.selectedTypes.contains("mood"),
              onTap: () => notifier.toggleType("mood"),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: "\u7528\u9910",
              selected: state.selectedTypes.contains("meal"),
              onTap: () => notifier.toggleType("meal"),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: "\u65E5\u5FD7",
              selected: state.selectedTypes.contains("lifelog"),
              onTap: () => notifier.toggleType("lifelog"),
            ),
          ],
        ),
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
          onPressed: notifier.loadEvents,
          icon: const Icon(Icons.refresh),
          label: const Text("\u91CD\u8BD5"),
        ),
      );
    }

    final grouped = state.groupedByDate;
    if (grouped.isEmpty) {
      return _EmptyState(
        icon: Icons.timeline,
        message: state.searchQuery.isNotEmpty
            ? "\u6CA1\u6709\u5339\u914D\u7684\u8BB0\u5F55"
            : "\u8FD8\u6CA1\u6709\u8BB0\u5F55\uFF0C\u5148\u53BB Chat \u8BB0\u4E00\u6761\u5427",
      );
    }

    final dateKeys = grouped.keys.toList();
    return RefreshIndicator(
      onRefresh: notifier.loadEvents,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        itemCount: dateKeys.length,
        itemBuilder: (context, index) {
          final dateKey = dateKeys[index];
          final events = grouped[dateKey]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateHeader(label: dateKey),
              ...events.map((event) {
                final expanded = state.expandedEventId == event.eventId;
                return Column(
                  children: [
                    _EventCard(
                      event: event,
                      expanded: expanded,
                      onTap: () => notifier.toggleExpanded(event.eventId),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: expanded
                          ? _DetailCard(
                              event: event,
                              loading: state.undoLoading,
                              onUndo: (event.commitId != null &&
                                      event.commitId!.isNotEmpty)
                                  ? () => notifier.undoCommit(event.commitId!)
                                  : null,
                            )
                          : const SizedBox.shrink(),
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

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                "Timeline",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
              tooltip: "\u5237\u65b0",
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? AppColors.accent : AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.accent : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: AppColors.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.expanded,
    required this.onTap,
  });

  final EventDto event;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = _buildSummary(event);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: expanded
              ? AppColors.accentLight.withValues(alpha: 0.45)
              : Colors.white,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(14),
            bottom: Radius.circular(expanded ? 0 : 14),
          ),
          border: Border.all(
            color: expanded
                ? AppColors.accent.withValues(alpha: 0.4)
                : AppColors.divider,
          ),
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
                    summary.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatIsoToFriendly(event.happenedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  if (summary.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      summary.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            _TypeBadge(type: event.type),
          ],
        ),
      ),
    );
  }
}

class _TypeAvatar extends StatelessWidget {
  const _TypeAvatar({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color bg;
    Color fg;
    switch (type) {
      case "expense":
        icon = Icons.receipt_long;
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        break;
      case "meal":
        icon = Icons.restaurant;
        bg = const Color(0xFFFFF0EB);
        fg = const Color(0xFFE76F51);
        break;
      case "mood":
        icon = Icons.mood;
        bg = AppColors.successLight;
        fg = AppColors.success;
        break;
      default:
        icon = Icons.event_note;
        bg = AppColors.accentLight;
        fg = AppColors.accent;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 20, color: fg),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    switch (type) {
      case "expense":
        label = "\u652F\u51FA";
        color = AppColors.warning;
        break;
      case "meal":
        label = "\u7528\u9910";
        color = const Color(0xFFE76F51);
        break;
      case "mood":
        label = "\u5FC3\u60C5";
        color = AppColors.success;
        break;
      default:
        label = "\u65E5\u5FD7";
        color = AppColors.accent;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _DetailCard extends StatefulWidget {
  const _DetailCard({
    required this.event,
    required this.loading,
    required this.onUndo,
  });

  final EventDto event;
  final bool loading;
  final VoidCallback? onUndo;

  @override
  State<_DetailCard> createState() => _DetailCardState();
}

class _DetailCardState extends State<_DetailCard> {
  bool showMore = false;
  bool noteExpanded = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final note = event.type == "lifelog"
        ? _lifelogText(event)
        : (event.data["note"]?.toString() ?? "").trim();
    final lifelogImages = event.type == "lifelog" ? _lifelogImages(event) : const <String>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),
          _DetailTop(event: event),
          if (lifelogImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ImageGrid(images: lifelogImages),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ExpandableNote(
              text: note,
              expanded: noteExpanded,
              onToggle: () => setState(() => noteExpanded = !noteExpanded),
            ),
          ],
          const SizedBox(height: 10),
          _DetailFields(event: event, showMore: showMore),
          if (_hasMore(event))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => showMore = !showMore),
                child: Text(showMore
                    ? "\u6536\u8D77\u66F4\u591A\u4FE1\u606F"
                    : "\u66F4\u591A\u4FE1\u606F"),
              ),
            ),
          if (widget.onUndo != null)
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
                label: const Text("\u64A4\u9500\u8FD9\u6B21\u63D0\u4EA4"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(
                      color: AppColors.danger.withValues(alpha: 0.5)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailTop extends StatelessWidget {
  const _DetailTop({required this.event});
  final EventDto event;

  @override
  Widget build(BuildContext context) {
    String label;
    String primary;
    String secondary = "";
    IconData icon;
    Color color;
    double size = 20;

    switch (event.type) {
      case "expense":
        label = "\u652F\u51FA\u8BB0\u5F55";
        final amount = event.data["amount"]?.toString() ?? "0";
        final category =
            _mapCategory((event.data["category"] ?? "other").toString());
        final currency = event.data["currency"]?.toString() ?? "CNY";
        primary = "\u00A5$amount";
        secondary = "$category \u00B7 $currency";
        icon = Icons.receipt_long;
        color = AppColors.warning;
        size = 26;
        break;
      case "meal":
        label = "\u7528\u9910\u8BB0\u5F55";
        final mealType = _mapMealType(event.data["meal_type"]?.toString());
        final items = ((event.data["items"] as List?) ?? [])
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .join("\u3001");
        primary = items.isNotEmpty ? items : "\u7528\u9910\u8BB0\u5F55";
        secondary = mealType;
        icon = Icons.restaurant;
        color = const Color(0xFFE76F51);
        break;
      case "mood":
        label = "\u5FC3\u60C5\u8BB0\u5F55";
        final score = _readMoodScore(event.data);
        primary =
            "${_moodEmoji(event.data, score)} ${_moodLabel(score, event.data["mood"]?.toString())}";
        secondary = (event.data["topic"]?.toString() ?? "").trim();
        icon = Icons.mood;
        color = AppColors.success;
        break;
      default:
        label = "\u751F\u6D3B\u8BB0\u5F55";
        final text = ((event.data["title"] ??
                        event.data["text"] ??
                        event.data["description"] ??
                        event.data["note"])
                    ?.toString() ??
                "")
            .trim();
        primary = text.isNotEmpty ? text : "\u751F\u6D3B\u8BB0\u5F55";
        icon = Icons.event_note;
        color = AppColors.accent;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          primary,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: size,
              ),
        ),
        if (secondary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            secondary,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ],
    );
  }
}

class _DetailFields extends StatelessWidget {
  const _DetailFields({
    required this.event,
    required this.showMore,
  });

  final EventDto event;
  final bool showMore;

  @override
  Widget build(BuildContext context) {
    final fields = <MapEntry<String, String>>[
      MapEntry("\u65F6\u95F4", formatIsoToLocal(event.happenedAt)),
    ];

    final topic = (event.data["topic"]?.toString() ?? "").trim();
    if (topic.isNotEmpty) {
      fields.add(MapEntry("\u4E3B\u9898", topic));
    }
    if (event.tags.isNotEmpty) {
      fields.add(MapEntry("\u6807\u7B7E", event.tags.join(" \u00B7 ")));
    }

    if (showMore) {
      final currency = (event.data["currency"]?.toString() ?? "").trim();
      if (currency.isNotEmpty) {
        fields.add(MapEntry("\u5E01\u79CD", currency));
      }
      if (event.source.isNotEmpty) {
        fields.add(MapEntry("\u6765\u6E90", event.source));
      }
      if (event.createdAt.isNotEmpty) {
        fields.add(
            MapEntry("\u521B\u5EFA\u4E8E", formatIsoToLocal(event.createdAt)));
      }
    }

    return Column(
      children: fields
          .map(
            (item) => Padding(
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
            ),
          )
          .toList(),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: GestureDetector(
          onTap: () => _openImage(context, 0),
          child: Image.memory(
            base64Decode(images.first),
            fit: BoxFit.cover,
            height: 180,
            width: double.infinity,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
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
          borderRadius: BorderRadius.circular(8),
          child: GestureDetector(
            onTap: () => _openImage(context, index),
            child: Image.memory(
              base64Decode(images[index]),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFF1F1F1),
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined, size: 16),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openImage(BuildContext context, int index) {
    var currentIndex = index;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              PageView.builder(
                controller: PageController(initialPage: index),
                itemCount: images.length,
                onPageChanged: (value) => setState(() => currentIndex = value),
                itemBuilder: (context, i) {
                  return InteractiveViewer(
                    child: Image.memory(
                      base64Decode(images[i]),
                      fit: BoxFit.contain,
                    ),
                  );
                },
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${currentIndex + 1}/${images.length}",
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
              text: text, style: Theme.of(context).textTheme.bodyMedium),
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
            ),
            if (overflow)
              TextButton(
                onPressed: onToggle,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                    expanded ? "\u6536\u8D77" : "\u5C55\u5F00\u5907\u6CE8"),
              ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    this.action,
  });

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

class _Summary {
  _Summary({required this.title, this.subtitle});
  final String title;
  final String? subtitle;
}

_Summary _buildSummary(EventDto event) {
  switch (event.type) {
    case "expense":
      final amount = event.data["amount"]?.toString() ?? "0";
      final category =
          _mapCategory((event.data["category"] ?? "other").toString());
      final note = (event.data["note"]?.toString() ?? "").trim();
      return _Summary(
        title: "\u00A5$amount \u00B7 $category",
        subtitle: note.isNotEmpty ? note : null,
      );
    case "meal":
      final mealType = _mapMealType(event.data["meal_type"]?.toString());
      final items = ((event.data["items"] as List?) ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .join("\u3001");
      final note = (event.data["note"]?.toString() ?? "").trim();
      return _Summary(
        title: items.isNotEmpty
            ? "$mealType \u00B7 $items"
            : "$mealType\u8BB0\u5F55",
        subtitle: note.isNotEmpty ? note : null,
      );
    case "mood":
      final score = _readMoodScore(event.data);
      final emoji = _moodEmoji(event.data, score);
      final label = _moodLabel(score, event.data["mood"]?.toString());
      final note = (event.data["note"]?.toString() ?? "").trim();
      return _Summary(
        title: "$emoji $label",
        subtitle: note.isNotEmpty ? note : null,
      );
    default:
      final text = _lifelogText(event);
      final imageCount = _lifelogImages(event).length;
      if (text.isNotEmpty) {
        return _Summary(
          title: text,
          subtitle: imageCount > 0 ? "$imageCount 张图片" : null,
        );
      }
      return _Summary(
        title: imageCount > 0 ? "图片日志 · $imageCount 张" : "\u751F\u6D3B\u8BB0\u5F55",
      );
  }
}

String _lifelogText(EventDto event) {
  return ((event.data["title"] ??
              event.data["text"] ??
              event.data["description"] ??
              event.data["note"])
          ?.toString() ??
      "")
      .trim();
}

List<String> _lifelogImages(EventDto event) {
  final raw = event.data["images"];
  if (raw is! List) return const [];
  return raw
      .whereType<String>()
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

String _mapCategory(String value) {
  if (value == "other") return "\u5176\u4ED6";
  return value;
}

String _mapMealType(String? value) {
  switch (value) {
    case "breakfast":
      return "\u65E9\u9910";
    case "lunch":
      return "\u5348\u9910";
    case "dinner":
      return "\u665A\u9910";
    case "snack":
      return "\u52A0\u9910";
    default:
      return "\u7528\u9910";
  }
}

int _readMoodScore(Map<String, dynamic> data) {
  final direct = data["score"];
  if (direct is num) {
    return direct.toInt().clamp(1, 5);
  }
  final intensity = data["intensity"];
  if (intensity is num) {
    return (intensity.toDouble() * 4 + 1).round().clamp(1, 5);
  }
  return 3;
}

String _moodEmoji(Map<String, dynamic> data, int score) {
  final emoji = (data["emoji"]?.toString() ?? "").trim();
  if (emoji.isNotEmpty) return emoji;
  switch (score) {
    case 1:
      return "\uD83D\uDE1E";
    case 2:
      return "\uD83D\uDE10";
    case 3:
      return "\uD83D\uDE42";
    case 4:
      return "\uD83D\uDE04";
    default:
      return "\uD83E\uDD29";
  }
}

String _moodLabel(int score, String? fallbackMood) {
  final fallback = (fallbackMood ?? "").trim();
  if (fallback.isNotEmpty && fallback.length <= 12) return fallback;
  switch (score) {
    case 1:
      return "\u6709\u70B9\u4F4E\u843D";
    case 2:
      return "\u4E00\u822C";
    case 3:
      return "\u8FD8\u4E0D\u9519";
    case 4:
      return "\u72B6\u6001\u5F88\u597D";
    default:
      return "\u4ECA\u5929\u8D85\u68D2";
  }
}

bool _hasMore(EventDto event) {
  final currency = (event.data["currency"]?.toString() ?? "").trim();
  return currency.isNotEmpty ||
      event.source.isNotEmpty ||
      event.createdAt.isNotEmpty;
}
