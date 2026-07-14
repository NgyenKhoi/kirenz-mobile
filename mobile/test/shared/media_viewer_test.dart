import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/shared/widgets/media_viewer.dart';

void main() {
  testWidgets('starts at the requested index and updates the count on swipe', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaViewer(
          urls: [
            'https://example.invalid/one.jpg',
            'https://example.invalid/two.jpg',
          ],
          initialIndex: 1,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('2 / 2'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(500, 0));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('1 / 2'), findsOneWidget);
  });
}
