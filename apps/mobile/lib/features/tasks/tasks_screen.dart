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
      ref.read(tasksControllerProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tasksControllerProvider);
    final notifier = ref.read(tasksControllerProvider.notifier);

    return Scaffold(
      body: Column(
        children: [
          _TasksHeader(onRefresh: () => notifier.loadAll()),
          const SizedBox(height: 6),
          // Scope tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Row(
              children: [
                _ScopeTab(
                  label: "今天",
                  count: state.todayTasks.length,
                  selected: state.activeScope == TaskScope.today,
                  onTap: () => notifier.setScope(TaskScope.today),
                ),
                const SizedBox(width: 8),
                _ScopeTab(
                  label: "逾期",
                  count: state.overdueTasks.length,
                  selected: state.activeScope == TaskScope.overdue,
                  onTap: () => notifier.setScope(TaskScope.overdue),
                  badgeColor:
                      state.overdueTasks.isNotEmpty ? AppColors.danger : null,
                ),
                const SizedBox(width: 8),
                _ScopeTab(
                  label: "全部",
                  count: state.allTasks.length,
                  selected: state.activeScope == TaskScope.all,
                  onTap: () => notifier.setScope(TaskScope.all),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Task list
          Expanded(child: _buildBody(state, notifier)),
        ],
      ),
      // Quick-add via chat
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go("/chat", extra: {"prefill": "新建任务："}),
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
          onPressed: () => notifier.loadAll(),
          icon: const Icon(Icons.refresh),
          label: const Text("重试"),
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
              onPressed: () => context.go("/chat", extra: {"prefill": "新建任务："}),
              icon: const Icon(Icons.add),
              label: const Text("新建任务"),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => context.go("/chat"),
              child: const Text("去聊天添加"),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => notifier.loadAll(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return _TaskCard(
            task: task,
            onComplete: () => notifier.completeTask(task.taskId),
            onPostpone: () => context.go(
              "/chat",
              extra: {"prefill": "延期任务：${task.title}"},
            ),
          );
        },
      ),
    );
  }

  String _emptyMessage(TaskScope scope) {
    switch (scope) {
      case TaskScope.today:
        return "今天没有待办任务 🎉";
      case TaskScope.overdue:
        return "没有逾期任务，做得好！";
      case TaskScope.all:
        return "暂无任务，去 Chat 页面创建吧";
    }
  }
}

// ─── Widgets ─────────────────────────────────────────

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
                    "把待办一件件完成",
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
            color: selected ? AppColors.accent.withOpacity(0.12) : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.divider,
            ),
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

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onComplete,
    required this.onPostpone,
  });

  final TaskDto task;
  final VoidCallback onComplete;
  final VoidCallback onPostpone;

  @override
  Widget build(BuildContext context) {
    final isOverdue = task.isOverdue;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOverdue ? AppColors.danger.withAlpha(80) : AppColors.divider,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Checkbox
              GestureDetector(
                onTap: onComplete,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: task.isDone ? AppColors.success : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: task.isDone
                          ? AppColors.success
                          : isOverdue
                              ? AppColors.danger
                              : AppColors.divider,
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
            ],
          ),
          if (task.dueAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 36), // align with title
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: isOverdue ? AppColors.danger : AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  formatIsoToLocal(task.dueAt!),
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isOverdue ? AppColors.danger : AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (!task.isDone)
                  GestureDetector(
                    onTap: onPostpone,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "延期",
                        style: const TextStyle(
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
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(
                task.note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          ],
          if (task.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: task.tags
                    .map((tag) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.accent),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
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
        label = "高";
        break;
      case "low":
        color = AppColors.textSecondary;
        label = "低";
        break;
      default:
        color = AppColors.accent;
        label = "中";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
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
