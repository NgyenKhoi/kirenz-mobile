import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>(
      (ref) => SessionController(),
    );

enum SessionStatus { checking, unauthenticated, authenticated }

class SessionState {
  const SessionState({required this.status, this.user});

  const SessionState.checking() : status = SessionStatus.checking, user = null;

  const SessionState.unauthenticated()
    : status = SessionStatus.unauthenticated,
      user = null;

  const SessionState.authenticated(this.user)
    : status = SessionStatus.authenticated;

  final SessionStatus status;
  final AppUser? user;

  bool get isAuthenticated => status == SessionStatus.authenticated;
}

class SessionController extends StateNotifier<SessionState> {
  SessionController() : super(const SessionState.unauthenticated());

  void signInForDevelopment() {
    state = const SessionState.authenticated(
      AppUser(
        id: 'dev-user',
        displayName: 'Kirenz Developer',
        email: 'developer@kirenz.local',
      ),
    );
  }

  void signOut() {
    state = const SessionState.unauthenticated();
  }
}
