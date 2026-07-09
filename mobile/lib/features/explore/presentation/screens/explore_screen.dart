import 'package:flutter/material.dart';

import '../../../../shared/widgets/feature_placeholder_screen.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: 'Explore',
      icon: Icons.travel_explore_outlined,
      items: ['Search content and users', 'Public posts', 'User discovery'],
    );
  }
}
