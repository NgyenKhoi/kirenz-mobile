import 'package:flutter/material.dart';

import '../../../../shared/widgets/feature_placeholder_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: 'Notifications',
      icon: Icons.notifications_active_outlined,
      items: [
        'Unread badge',
        'Social notifications',
        'Mark read',
        'Realtime updates',
      ],
    );
  }
}
