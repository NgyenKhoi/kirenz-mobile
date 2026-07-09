import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/session_controller.dart';

class FeaturePlaceholderScreen extends ConsumerWidget {
  const FeaturePlaceholderScreen({
    required this.title,
    required this.icon,
    required this.items,
    this.showProfileAction = false,
    super.key,
  });

  final String title;
  final IconData icon;
  final List<String> items;
  final bool showProfileAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (showProfileAction)
            IconButton(
              onPressed: () => context.push('/privacy'),
              icon: const Icon(Icons.shield_outlined),
            ),
          if (showProfileAction)
            IconButton(
              onPressed: () {
                ref.read(sessionControllerProvider.notifier).signOut();
              },
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {},
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _HeaderCard(title: title, icon: icon);
              }

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
                leading: Icon(icon),
                title: Text(items[index - 1]),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemCount: items.length + 1,
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
