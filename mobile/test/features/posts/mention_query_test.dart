import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/features/posts/presentation/mention_query.dart';

void main() {
  test('opens suggestions only for an active @ token', () {
    expect(_query('@'), '');
    expect(_query('Hello @ma'), 'ma');
    expect(_query('Hello friend'), isNull);
    expect(_query('mail@example.com'), isNull);
    expect(_query('Hello @ma,'), isNull);
  });

  test('uses the mention token at the current cursor', () {
    const text = 'Hi @mai and @linh';
    final first = postMentionAtCursor(
      const TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: 7),
      ),
    );
    final second = postMentionAtCursor(
      const TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: 17),
      ),
    );

    expect(first?.query, 'mai');
    expect(first?.start, 3);
    expect(second?.query, 'linh');
    expect(second?.start, 12);
  });
}

String? _query(String text) => postMentionAtCursor(
  TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  ),
)?.query;
