import 'package:flutter/material.dart';

import '../../../../shared/widgets/feature_placeholder_screen.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: 'Chat',
      icon: Icons.forum_outlined,
      items: [
        'Conversation list',
        'Direct messages',
        'Group chat',
        'Typing and presence',
      ],
    );
  }
}
