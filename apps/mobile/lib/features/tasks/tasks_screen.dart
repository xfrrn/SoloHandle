import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../core/constants.dart";
import "../../core/time.dart";
import "../../data/api/models.dart";
import "tasks_controller.dart";

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final state = ref.read(tasksControllerProvider);
      if (state.allTasks.isEmpty && !state.loading) {
        ref.read(tasksControllerProvider.notifier).loadAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tasksControllerProvider);
    final notifier = ref.read(tasksControllerProvider.notifier);

    return Scaffold(
      body: Column(
        children: [
          _TasksHeader(onRefresh: notifier.loadAll),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Row(
              children: [
                _ScopeTab(
                  label: "\u4eca\u5929",
                  count: state.todayTasks.length,
                  selected: state.activeScope == TaskScope.today,
                  onTap: () => notifier.setScope(TaskScope.today),
                ),
                const SizedBox(width: 8),
                _ScopeTab(
                  label: "\u903e\u671f",
                  count: state.overdueTasks.length,
                  selected: state.activeScope == TaskScope.overdue,
                  onTap: () => notifier.setScope(TaskScope.overdue),
                  badgeColor:
                      state.overdueTasks.isNotEmpty ? AppColors.danger : null,
                ),
                const SizedBox(width: 8),
                _ScopeTab(
                  label: "\u5168\u90e8",
                  count: state.allTasks.length,
                  selected: state.activeScope == TaskScope.all,
                  onTap: () => notifier.setScope(TaskScope.all),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(state, notifier)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context
            .go("/chat", extra: {"prefill": "\u65b0\u5efa\u4efb\u52a1\uff1a"}),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(TasksState state, TasksController notifier) {
    if (state.loading && state.activeTasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.activeTasks.isEmpty) {
      return _EmptyState(
        icon: Icons.error_outline,
        message: state.error!,
        action: TextButton.icon(
          onPressed: notifier.loadAll,
          icon: const Icon(Icons.refresh),
          label: const Text("\u91cd\u8bd5"),
        ),
      );
    }

    final tasks = state.activeTasks;
    if (tasks.isEmpty) {
      return _EmptyState(
        icon: Icons.check_circle_outline,
        message: _emptyMessage(state.activeScope),
        action: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () => context.go("/chat",
                  extra: {"prefill": "\u65b0\u5efa\u4efb\u52a1\uff1a"}),
              icon: const Icon(Icons.add),
              label: const Text("\u65b0\u5efa\u4efb\u52a1"),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: notifier.loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return _TaskCard(
            task: task,
            onToggleDone: () {
              if (task.isDone) {
                notifier.waitingTask(task.taskId);
              } else {
                notifier.completeTask(task.taskId);
              }
            },
            onPostpone: () => context.go(
              "/chat",
              extra: {"prefill": "\u5ef6\u671f\u4efb\u52a1\uff1a${task.title}"},
            ),
            onDelete: () =>
                _confirmDelete(context, () => notifier.deleteTask(task.taskId)),
            onEdit: () => _showEditTaskSheet(context, task, notifier),
            onMarkWaiting:
                task.isDone ? () => notifier.waitingTask(task.taskId) : null,
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, VoidCallback onConfirm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("\u5220\u9664\u4efb\u52a1"),
        content: const Text(
            "\u786e\u8ba4\u5220\u9664\u8fd9\u6761\u4efb\u52a1\u5417\uff1f"),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("\u53d6\u6d88")),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text("\u5220\u9664")),
        ],
      ),
    );
    if (ok == true) onConfirm();
  }

  Future<void> _showEditTaskSheet(
    BuildContext context,
    TaskDto task,
    TasksController notifier,
  ) async {
    final titleCtl = TextEditingController(text: task.title);
    final noteCtl = TextEditingController(text: task.note ?? "");
    String selectedPriority =
        _priorityValues.contains(task.priority) ? task.priority : "medium";
    DateTime? selectedDueAt =
        task.dueAt != null ? DateTime.tryParse(task.dueAt!)?.toLocal() : null;
    final formKey = GlobalKey<FormState>();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("\u7f16\u8f91\u4efb\u52a1",
                        style: Theme.of(ctx).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: titleCtl,
                      decoration:
                          const InputDecoration(labelText: "\u6807\u9898"),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? "\u6807\u9898\u4e0d\u80fd\u4e3a\u7a7a"
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: noteCtl,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(labelText: "\u5907\u6ce8"),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPriority,
                      decoration: const InputDecoration(
                          labelText: "\u4f18\u5148\u7ea7"),
                      items: const [
                        DropdownMenuItem(
                            value: "high",
                            child: Text("\u9ad8\u4f18\u5148\u7ea7")),
                        DropdownMenuItem(
                            value: "medium",
                            child: Text("\u4e2d\u4f18\u5148\u7ea7")),
                        DropdownMenuItem(
                            value: "low",
                            child: Text("\u4f4e\u4f18\u5148\u7ea7")),
                      ],
                      onChanged: (v) {
                        if (v == null) {
                          return;
                        }
                        setModalState(() => selectedPriority = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedDueAt == null
                                ? "\u672a\u8bbe\u7f6e\u5230\u671f\u65f6\u95f4"
                                : "\u5230\u671f\uff1a${formatIsoToLocal(toIsoWithOffset(selectedDueAt!))}",
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDueAt ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (!ctx.mounted) return;
                            if (pickedDate == null) return;
                            final pickedTime = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(
                                selectedDueAt ?? DateTime.now(),
                              ),
                            );
                            if (!ctx.mounted) return;
                            if (pickedTime == null) return;
                            setModalState(() {
                              selectedDueAt = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          },
                          child: const Text("\u8bbe\u7f6e\u65f6\u95f4"),
                        ),
                        if (selectedDueAt != null)
                          TextButton(
                            onPressed: () =>
                                setModalState(() => selectedDueAt = null),
                            child: const Text("\u6e05\u9664"),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text("\u53d6\u6d88"),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            if (formKey.currentState?.validate() != true) {
                              return;
                            }
                            Navigator.of(ctx).pop(true);
                          },
                          child: const Text("\u4fdd\u5b58"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (ok == true) {
      await notifier.updateTask(
        task.taskId,
        title: titleCtl.text.trim(),
        note: noteCtl.text.trim(),
        priority: selectedPriority,
        dueAt: selectedDueAt == null ? null : toIsoWithOffset(selectedDueAt!),
        clearDueAt: selectedDueAt == null && task.dueAt != null,
      );
    }
  }

  String _emptyMessage(TaskScope scope) {
    switch (scope) {
      case TaskScope.today:
        return "\u4eca\u5929\u6ca1\u6709\u5f85\u529e\u4efb\u52a1";
      case TaskScope.overdue:
        return "\u6ca1\u6709\u903e\u671f\u4efb\u52a1\uff0c\u505a\u5f97\u5f88\u597d";
      case TaskScope.all:
        return "\u6682\u65e0\u4efb\u52a1\uff0c\u53bb Chat \u9875\u9762\u521b\u5efa\u5427";
    }
  }
}

const _priorityValues = {"high", "medium", "low"};

class _TasksHeader extends StatelessWidget {
  const _TasksHeader({required this.onRefresh});
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tasks",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "\u628a\u5f85\u529e\u4e00\u4ef6\u4ef6\u5b8c\u6210",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.badgeColor,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.12)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? AppColors.accent : AppColors.divider),
          ),
          child: Column(
            children: [
              Text(
                "$count",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: badgeColor ??
                      (selected ? AppColors.accent : AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatefulWidget {
  const _TaskCard({
    required this.task,
    required this.onToggleDone,
    required this.onPostpone,
    required this.onDelete,
    required this.onEdit,
    this.onMarkWaiting,
  });

  final TaskDto task;
  final VoidCallback onToggleDone;
  final VoidCallback onPostpone;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback? onMarkWaiting;

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _noteExpanded = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isOverdue = task.isOverdue;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOverdue
              ? AppColors.danger.withValues(alpha: 0.35)
              : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: widget.onToggleDone,
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: task.isDone ? AppColors.success : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: task.isDone
                          ? AppColors.success
                          : (isOverdue ? AppColors.danger : AppColors.divider),
                      width: 2,
                    ),
                  ),
                  child: task.isDone
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        decoration:
                            task.isDone ? TextDecoration.lineThrough : null,
                        color: task.isDone ? AppColors.textSecondary : null,
                      ),
                ),
              ),
              _PriorityBadge(priority: task.priority),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == "edit") widget.onEdit();
                  if (v == "delete") widget.onDelete();
                  if (v == "waiting" && widget.onMarkWaiting != null) {
                    widget.onMarkWaiting!();
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                      value: "edit", child: Text("\u4fee\u6539")),
                  if (widget.onMarkWaiting != null)
                    const PopupMenuItem(
                        value: "waiting",
                        child: Text("\u6807\u8bb0\u7b49\u5f85")),
                  const PopupMenuItem(
                      value: "delete", child: Text("\u5220\u9664")),
                ],
              ),
            ],
          ),
          if (task.dueAt != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const SizedBox(width: 24),
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: isOverdue ? AppColors.danger : AppColors.textSecondary,
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    formatIsoToLocal(task.dueAt!),
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue
                          ? AppColors.danger
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (!task.isDone)
                  InkWell(
                    onTap: widget.onPostpone,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "\u5ef6\u671f",
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (task.note != null && task.note!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _ExpandableTaskNote(
                text: task.note!,
                expanded: _noteExpanded,
                onToggle: () => setState(() => _noteExpanded = !_noteExpanded),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpandableTaskNote extends StatelessWidget {
  const _ExpandableTaskNote({
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
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
                    expanded ? "\u6536\u8d77" : "\u5c55\u5f00\u5907\u6ce8"),
              ),
          ],
        );
      },
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});
  final String priority;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (priority) {
      case "high":
        color = AppColors.danger;
        label = "\u9ad8";
        break;
      case "low":
        color = AppColors.textSecondary;
        label = "\u4f4e";
        break;
      default:
        color = AppColors.accent;
        label = "\u4e2d";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
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
