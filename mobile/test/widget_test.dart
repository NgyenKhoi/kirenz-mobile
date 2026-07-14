import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/app/kirenz_app.dart';
import 'package:kirenz_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:kirenz_mobile/features/auth/domain/entities/app_user.dart';
import 'package:kirenz_mobile/features/auth/presentation/controllers/session_controller.dart';

void main() {
  testWidgets('shows login when unauthenticated', (tester) async {
    final container = await _container();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KirenzApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('shows home after development sign in', (tester) async {
    final container = await _container();
    container.read(sessionControllerProvider.notifier).signInForDevelopment();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KirenzApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
  });
}

Future<ProviderContainer> _container() async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_TestAuthRepository()),
    ],
  );
  await container.read(sessionControllerProvider.notifier).restoreSession();
  return container;
}

class _TestAuthRepository implements AuthRepository {
  @override
  Future<AppUser?> restoreSession() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
