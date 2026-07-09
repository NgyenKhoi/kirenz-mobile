import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            SwitchListTile(
              value: true,
              onChanged: null,
              title: Text('Profile visibility'),
              subtitle: Text('Friends can view profile details'),
            ),
            SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.block_outlined),
              title: Text('Blocked users'),
              subtitle: Text('Block and unblock users'),
            ),
          ],
        ),
      ),
    );
  }
}
