import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/presentation/controllers/conversation_controller.dart';
import '../../features/notifications/presentation/controllers/notification_controller.dart';

class MainShell extends ConsumerWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread =
        ref
            .watch(conversationControllerProvider)
            .value
            ?.fold<int>(
              0,
              (sum, conversation) => sum + conversation.unreadCount,
            ) ??
        0;
    final socialUnread = ref.watch(
      notificationControllerProvider.select((state) => state.unreadCount),
    );
    final destinations = _destinations(unread, socialUnread);
    void selectDestination(int index) => navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 840;
        return Scaffold(
          body: useRail
              ? SafeArea(
                  child: Row(
                    children: [
                      NavigationRail(
                        selectedIndex: navigationShell.currentIndex,
                        onDestinationSelected: selectDestination,
                        labelType: NavigationRailLabelType.all,
                        groupAlignment: -0.65,
                        leading: Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 32,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        destinations: destinations
                            .map(
                              (item) => NavigationRailDestination(
                                icon: item.icon,
                                selectedIcon: item.selectedIcon,
                                label: Text(item.label),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      VerticalDivider(
                        width: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      Expanded(child: navigationShell),
                    ],
                  ),
                )
              : navigationShell,
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: selectDestination,
                  destinations: destinations,
                ),
        );
      },
    );
  }

  List<NavigationDestination> _destinations(int unread, int socialUnread) => [
    const NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    const NavigationDestination(
      icon: Icon(Icons.explore_outlined),
      selectedIcon: Icon(Icons.explore_rounded),
      label: 'Explore',
    ),
    const NavigationDestination(
      icon: Icon(Icons.people_outline_rounded),
      selectedIcon: Icon(Icons.people_rounded),
      label: 'Friends',
    ),
    NavigationDestination(
      icon: _badge(Icons.chat_bubble_outline_rounded, unread),
      selectedIcon: _badge(Icons.chat_bubble_rounded, unread),
      label: 'Chat',
    ),
    NavigationDestination(
      icon: _badge(Icons.notifications_outlined, socialUnread),
      selectedIcon: _badge(Icons.notifications_rounded, socialUnread),
      label: 'Alerts',
    ),
    const NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  Widget _badge(IconData icon, int count) => Badge(
    isLabelVisible: count > 0,
    label: Text(count > 99 ? '99+' : '$count'),
    child: Icon(icon),
  );
}
