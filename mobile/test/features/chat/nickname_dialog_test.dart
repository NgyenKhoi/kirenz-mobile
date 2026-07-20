import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/features/chat/domain/entities/conversation.dart';
import 'package:kirenz_mobile/features/chat/presentation/widgets/nickname_dialog.dart';

void main() {
  testWidgets('saves nickname and disposes after dialog transition', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showDialog<String>(
                context: context,
                builder: (_) => const NicknameDialog(
                  participant: ConversationParticipant(
                    userId: 'user-2',
                    username: 'mai',
                    displayName: 'Mai Nguyen',
                    avatarUrl: null,
                    allowDirectMessages: true,
                    nickname: null,
                    admin: false,
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Mây  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, 'Mây');
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
