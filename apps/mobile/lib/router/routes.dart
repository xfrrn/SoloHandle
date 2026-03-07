import "dart:ui";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../features/chat/chat_screen.dart";
import "../features/dashboard/dashboard_screen.dart";
import "../features/notifications/notifications_screen.dart";
import "../features/settings/settings_screen.dart";
import "../features/settings/developer_settings_screen.dart";
import "../features/tasks/tasks_screen.dart";
import "../features/timeline/timeline_screen.dart";

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: "/chat",
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: "/chat",
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ChatScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: "/dashboard",
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: DashboardScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: "/timeline",
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: TimelineScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: "/tasks",
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: TasksScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: "/me",
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: SettingsScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: "/developer-settings",
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: DeveloperSettingsScreen()),
      ),
      GoRoute(
        path: "/notifications",
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: NotificationsScreen()),
      ),
    ],
  );
});

class _AppShell extends StatelessWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    _TabItem(label: "Chat", icon: Icons.chat_bubble_outline, path: "/chat"),
    _TabItem(
        label: "Dashboard", icon: Icons.dashboard_outlined, path: "/dashboard"),
    _TabItem(label: "Timeline", icon: Icons.timeline, path: "/timeline"),
    _TabItem(label: "Tasks", icon: Icons.check_box_outlined, path: "/tasks"),
    _TabItem(label: "Me", icon: Icons.person_outline, path: "/me"),
  ];

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;
    final hideTabBar = index == 0;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: hideTabBar
          ? null
          : _RoundedTabBar(
              currentIndex: index,
              onTap: (next) => navigationShell.goBranch(
                next,
                initialLocation: next == navigationShell.currentIndex,
              ),
              tabs: _tabs,
            ),
    );
  }
}

class _TabItem {
  const _TabItem({required this.label, required this.icon, required this.path});

  final String label;
  final IconData icon;
  final String path;
}

class _RoundedTabBar extends StatelessWidget {
  const _RoundedTabBar({
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_TabItem> tabs;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.65),
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: _TabButton(
                      item: tabs[i],
                      selected: i == currentIndex,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _TabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 220),
              scale: selected ? 1.05 : 1.0,
              child: Icon(item.icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
