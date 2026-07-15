import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/core/errors/api_exception.dart';
import 'package:kirenz_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:kirenz_mobile/features/auth/data/services/google_auth_client.dart';
import 'package:kirenz_mobile/features/auth/domain/entities/app_user.dart';
import 'package:kirenz_mobile/features/auth/presentation/controllers/session_cleanup.dart';
import 'package:kirenz_mobile/features/auth/presentation/controllers/session_controller.dart';

void main() {
  test('routes an unverified login result to retained OTP email', () async {
    final controller = SessionController(
      _FakeAuthRepository(
        loginError: const ApiException('Please verify your email first.'),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final success = await controller.login(
      email: 'user@example.com',
      password: 'password123',
    );

    expect(success, isFalse);
    expect(controller.state.otpEmail, 'user@example.com');
    expect(controller.state.errorMessage, isNull);
  });

  test('retains backend errors on their matching login fields', () async {
    final controller = SessionController(
      _FakeAuthRepository(
        loginError: const ApiException(
          'Invalid login request.',
          fieldErrors: {'email': 'Email does not exist.'},
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    await controller.login(
      email: 'missing@example.com',
      password: 'password123',
    );

    expect(controller.state.fieldErrors['email'], 'Email does not exist.');
    controller.clearFieldError('email');
    expect(controller.state.fieldErrors, isEmpty);
  });

  test('Google cancellation is neutral and does not call backend', () async {
    final repository = _FakeAuthRepository();
    final controller = SessionController(
      repository,
      googleAuthClient: _FakeGoogleAuthClient(idToken: null),
    );
    await Future<void>.delayed(Duration.zero);

    expect(await controller.loginWithGoogle(), isFalse);
    expect(controller.state.errorMessage, isNull);
    expect(repository.googleLoginCalls, 0);
  });

  test('Google id token is exchanged for the Kirenz session', () async {
    final repository = _FakeAuthRepository();
    final controller = SessionController(
      repository,
      googleAuthClient: _FakeGoogleAuthClient(idToken: 'google-id-token'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(await controller.loginWithGoogle(), isTrue);
    expect(repository.googleIdToken, 'google-id-token');
    expect(controller.state.isAuthenticated, isTrue);
  });

  test('logout clears repository and account-scoped state once', () async {
    final repository = _FakeAuthRepository();
    var disconnectCalls = 0;
    var clearStateCalls = 0;
    final controller = SessionController(
      repository,
      cleanup: SessionCleanup(
        disconnectGoogle: () async => disconnectCalls++,
        disconnectRealtime: () async {},
        clearPrivateDrafts: () async {},
        clearUserCache: () async {},
        clearAccountState: () => clearStateCalls++,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    controller.signInForDevelopment();

    await controller.signOut();

    expect(repository.logoutCalls, 1);
    expect(disconnectCalls, 1);
    expect(clearStateCalls, 1);
    expect(controller.state.status, SessionStatus.unauthenticated);
  });

  test('cleanup continues when Google disconnect fails', () async {
    var remainingSteps = 0;
    final cleanup = SessionCleanup(
      disconnectGoogle: () => throw StateError('not configured'),
      disconnectRealtime: () async => remainingSteps++,
      clearPrivateDrafts: () async => remainingSteps++,
      clearUserCache: () async => remainingSteps++,
      clearAccountState: () => remainingSteps++,
    );

    await cleanup.run();

    expect(remainingSteps, 4);
  });

  test('realtime connection failure does not invalidate saved login', () async {
    final controller = SessionController(
      _FakeAuthRepository(),
      connectRealtime: () => throw StateError('gateway unavailable'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      await controller.login(
        email: 'user@example.com',
        password: 'password123',
      ),
      isTrue,
    );
    expect(controller.state.isAuthenticated, isTrue);
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.loginError});

  final Object? loginError;
  int googleLoginCalls = 0;
  int logoutCalls = 0;
  String? googleIdToken;

  @override
  Future<AppUser?> restoreSession() async => null;

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    if (loginError != null) throw loginError!;
    return AppUser(id: '1', displayName: 'User', email: email);
  }

  @override
  Future<AppUser> loginWithGoogle({required String idToken}) async {
    googleLoginCalls++;
    googleIdToken = idToken;
    return const AppUser(
      id: 'google-user',
      displayName: 'Google User',
      email: 'google@example.com',
    );
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGoogleAuthClient implements GoogleAuthClient {
  _FakeGoogleAuthClient({required this.idToken});

  final String? idToken;

  @override
  Future<String?> authenticate() async => idToken;

  @override
  Future<void> disconnect() async {}
}
