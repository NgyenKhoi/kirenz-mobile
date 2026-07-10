import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import '../../domain/entities/app_user.dart';

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>(
      (ref) => SessionController(ref.watch(authRepositoryProvider)),
    );

enum SessionStatus { checking, unauthenticated, authenticating, authenticated }

class SessionState {
  const SessionState({required this.status, this.user, this.errorMessage});

  const SessionState.checking()
    : status = SessionStatus.checking,
      user = null,
      errorMessage = null;

  const SessionState.unauthenticated({this.errorMessage})
    : status = SessionStatus.unauthenticated,
      user = null;

  const SessionState.authenticating()
    : status = SessionStatus.authenticating,
      user = null,
      errorMessage = null;

  const SessionState.authenticated(this.user)
    : status = SessionStatus.authenticated,
      errorMessage = null;

  final SessionStatus status;
  final AppUser? user;
  final String? errorMessage;

  bool get isAuthenticated => status == SessionStatus.authenticated;
  bool get isBusy =>
      status == SessionStatus.checking ||
      status == SessionStatus.authenticating;
}

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._authRepository)
    : super(const SessionState.checking()) {
    restoreSession();
  }

  final AuthRepository _authRepository;

  Future<void> restoreSession() async {
    state = const SessionState.checking();
    final user = await _authRepository.restoreSession();
    state = user == null
        ? const SessionState.unauthenticated()
        : SessionState.authenticated(user);
  }

  Future<bool> login({required String email, required String password}) async {
    state = const SessionState.authenticating();

    try {
      final user = await _authRepository.login(
        email: email,
        password: password,
      );
      state = SessionState.authenticated(user);
      return true;
    } catch (error) {
      state = SessionState.unauthenticated(errorMessage: error.toString());
      return false;
    }
  }

  void signInForDevelopment() {
    state = const SessionState.authenticated(
      AppUser(
        id: 'dev-user',
        displayName: 'Kirenz Developer',
        email: 'developer@kirenz.local',
      ),
    );
  }

  Future<void> signOut() async {
    await _authRepository.logout();
    state = const SessionState.unauthenticated();
  }
}
