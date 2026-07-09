import 'package:flutter/material.dart';

import '../../../../shared/widgets/feature_placeholder_screen.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: 'Home',
      icon: Icons.dynamic_feed_outlined,
      items: [
        'Feed pagination',
        'Post composer',
        'Media upload',
        'Comments and reactions',
      ],
    );
  }
}
