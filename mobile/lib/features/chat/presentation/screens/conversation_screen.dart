import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/session_controller.dart';
import '../controllers/conversation_controller.dart';

class ConversationScreen extends ConsumerWidget {
  const ConversationScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(sessionControllerProvider).user?.id;
    final conversation = ref
        .watch(conversationControllerProvider)
        .value
        ?.where((item) => item.id == conversationId)
        .firstOrNull;
    if (conversation == null) {
      return const Scaffold(
        body: Center(child: Text('Conversation unavailable')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(conversation.titleFor(currentUserId)),
        actions: [
          if (conversation.type.name == 'group')
            IconButton(
              tooltip: 'Group settings',
              onPressed: null,
              icon: const Icon(Icons.settings_outlined),
            ),
        ],
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Conversation created. Message history and composer are enabled in the Messages feature.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
