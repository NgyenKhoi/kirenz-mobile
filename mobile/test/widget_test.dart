import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/app/bootstrap.dart';
import 'package:kirenz_mobile/app/kirenz_app.dart';
import 'package:kirenz_mobile/features/auth/presentation/controllers/session_controller.dart';

void main() {
  testWidgets('shows login when unauthenticated', (tester) async {
    final container = await bootstrap();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KirenzApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('shows home after development sign in', (tester) async {
    final container = await bootstrap();
    container.read(sessionControllerProvider.notifier).signInForDevelopment();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KirenzApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
  });
}
