import 'package:flutter/material.dart';

import '../../../../shared/widgets/feature_placeholder_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: 'Profile',
      icon: Icons.account_circle_outlined,
      showProfileAction: true,
      items: [
        'Profile details',
        'Avatar upload',
        'Cover photo upload',
        'Photos and friends tabs',
      ],
    );
  }
}
