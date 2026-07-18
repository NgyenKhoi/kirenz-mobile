import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/controllers/session_controller.dart';
import '../controllers/conversation_controller.dart';

class ConversationScreen extends ConsumerWidget {
  const ConversationScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(sessionControllerProvider).user?.id;
    final list = ref.watch(conversationControllerProvider);
    final existing = list.value
        ?.where((item) => item.id == conversationId)
        .firstOrNull;
    if (existing == null) {
      return FutureBuilder(
        future: ref
            .read(conversationControllerProvider.notifier)
            .loadById(conversationId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(
                child: Text('Conversation unavailable: ${snapshot.error}'),
              ),
            );
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      );
    }
    final conversation = existing;
    return Scaffold(
      appBar: AppBar(
        title: Text(conversation.titleFor(currentUserId)),
        actions: [
          if (conversation.type.name == 'group')
            IconButton(
              tooltip: 'Group settings',
              onPressed: () => context.push('/chat/$conversationId/settings'),
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
