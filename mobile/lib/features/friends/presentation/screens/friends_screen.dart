import 'package:flutter/material.dart';

import '../../../../shared/widgets/feature_placeholder_screen.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: 'Friends',
      icon: Icons.group_add_outlined,
      items: [
        'Friend suggestions',
        'Incoming requests',
        'Outgoing requests',
        'Friend list',
      ],
    );
  }
}
