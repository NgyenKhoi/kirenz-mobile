import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hub_outlined, size: 56),
                SizedBox(height: 16),
                Text(
                  'Kirenz',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text(AppConfig.apiBaseUrl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
