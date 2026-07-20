import 'package:flutter/material.dart';

import '../../domain/entities/conversation.dart';

class NicknameDialog extends StatefulWidget {
  const NicknameDialog({required this.participant, super.key});

  final ConversationParticipant participant;

  @override
  State<NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<NicknameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.participant.nickname ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Nickname for ${widget.participant.resolvedName}'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 100,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => Navigator.pop(context, _controller.text.trim()),
      decoration: const InputDecoration(
        labelText: 'Nickname',
        helperText: 'Leave empty to clear the nickname.',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Save'),
      ),
    ],
  );
}
