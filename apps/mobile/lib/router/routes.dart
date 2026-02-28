import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../features/chat/chat_screen.dart";
import "../features/dashboard/dashboard_screen.dart";
import "../features/notifications/notifications_screen.dart";
import "../features/settings/settings_screen.dart";
import "../features/tasks/tasks_screen.dart";
import "../features/timeline/timeline_screen.dart";

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: "/chat",
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return _AppShell(child: child);
        },
        routes: [
          GoRoute(
            path: "/chat",
            pageBuilder: (context, state) => const NoTransitionPage(child: ChatScreen()),
          ),
          GoRoute(
            path: "/dashboard",
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: "/timeline",
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: TimelineScreen()),
          ),
          GoRoute(
            path: "/tasks",
            pageBuilder: (context, state) => const NoTransitionPage(child: TasksScreen()),
          ),
          GoRoute(
            path: "/me",
            pageBuilder: (context, state) => const NoTransitionPage(child: SettingsScreen()),
          ),
        ],
      ),
      GoRoute(
        path: "/notifications",
        pageBuilder: (context, state) => const NoTransitionPage(child: NotificationsScreen()),
      ),
    ],
  );
});

class _AppShell extends StatelessWidget {
  const _AppShell({required this.child});

  final Widget child;

  static const _tabs = [
    _TabItem(label: "Chat", icon: Icons.chat_bubble_outline, path: "/chat"),
    _TabItem(label: "Dashboard", icon: Icons.dashboard_outlined, path: "/dashboard"),
    _TabItem(label: "Timeline", icon: Icons.timeline, path: "/timeline"),
    _TabItem(label: "Tasks", icon: Icons.check_box_outlined, path: "/tasks"),
    _TabItem(label: "Me", icon: Icons.person_outline, path: "/me"),
  ];

  int _locationToIndex(String location) {
    for (var i = 0; i < _tabs.length; i += 1) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _locationToIndex(location);
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        items: _tabs
            .map(
              (tab) => BottomNavigationBarItem(
                icon: Icon(tab.icon),
                label: tab.label,
              ),
            )
            .toList(),
        onTap: (next) => context.go(_tabs[next].path),
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
