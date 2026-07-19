import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/network/dio_provider.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/google_auth_client.dart';
import '../../domain/entities/app_user.dart';
import 'session_cleanup.dart';
import '../../../chat/presentation/controllers/chat_realtime_controller.dart';

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
      final controller = SessionController(
        ref.watch(authRepositoryProvider),
        googleAuthClient: ref.watch(googleAuthClientProvider),
        cleanup: ref.watch(sessionCleanupProvider),
        connectRealtime: ref
            .watch(chatRealtimeControllerProvider.notifier)
            .connect,
      );
      ref.listen<int>(sessionExpirationProvider, (previous, next) {
        if (next > 0 && next != previous) {
          unawaited(controller.expireSession());
        }
      });
      return controller;
    });

enum SessionStatus {
  checking,
  unauthenticated,
  authenticating,
  authenticated,
  unsupportedRole,
}

enum AuthPendingAction { passwordLogin, googleLogin, logout }

class SessionState {
  const SessionState({
    required this.status,
    this.user,
    this.errorMessage,
    this.fieldErrors = const {},
    this.otpEmail,
    this.pendingAction,
  });

  const SessionState.checking()
    : status = SessionStatus.checking,
      user = null,
      errorMessage = null,
      fieldErrors = const {},
      otpEmail = null,
      pendingAction = null;

  const SessionState.unauthenticated({
    this.errorMessage,
    this.fieldErrors = const {},
    this.otpEmail,
    this.pendingAction,
  }) : status = SessionStatus.unauthenticated,
       user = null;

  const SessionState.authenticating()
    : status = SessionStatus.authenticating,
      user = null,
      errorMessage = null,
      fieldErrors = const {},
      otpEmail = null,
      pendingAction = null;

  const SessionState.authenticated(this.user)
    : status = SessionStatus.authenticated,
      errorMessage = null,
      fieldErrors = const {},
      otpEmail = null,
      pendingAction = null;

  const SessionState.unsupportedRole(this.user)
    : status = SessionStatus.unsupportedRole,
      errorMessage = null,
      fieldErrors = const {},
      otpEmail = null,
      pendingAction = null;

  final SessionStatus status;
  final AppUser? user;
  final String? errorMessage;
  final Map<String, String> fieldErrors;
  final String? otpEmail;
  final AuthPendingAction? pendingAction;

  bool get isAuthenticated => status == SessionStatus.authenticated;
  bool get isBusy =>
      status == SessionStatus.checking ||
      status == SessionStatus.authenticating;
}

class SessionController extends StateNotifier<SessionState> {
  SessionController(
    this._authRepository, {
    this.googleAuthClient,
    this.cleanup,
    this.connectRealtime,
  }) : super(const SessionState.checking()) {
    restoreSession();
  }

  final AuthRepository _authRepository;
  final GoogleAuthClient? googleAuthClient;
  final SessionCleanup? cleanup;
  final Future<void> Function()? connectRealtime;
  int _generation = 0;

  Future<void> restoreSession() async {
    final generation = ++_generation;
    state = const SessionState.checking();
    final user = await _authRepository.restoreSession();
    if (generation != _generation) return;
    state = user == null
        ? const SessionState.unauthenticated()
        : !user.emailVerified
        ? SessionState.unauthenticated(otpEmail: user.email)
        : user.role == 'USER'
        ? SessionState.authenticated(user)
        : SessionState.unsupportedRole(user);
    if (user?.emailVerified == true && user?.role == 'USER') {
      await _connectRealtime();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    final generation = ++_generation;
    state = const SessionState(
      status: SessionStatus.authenticating,
      pendingAction: AuthPendingAction.passwordLogin,
    );
    try {
      final user = await _authRepository.login(
        email: email,
        password: password,
      );
      if (generation != _generation) return false;
      if (!user.emailVerified) {
        state = SessionState.unauthenticated(otpEmail: user.email);
        return false;
      }
      if (user.role != 'USER') {
        state = SessionState.unsupportedRole(user);
        return false;
      }
      state = SessionState.authenticated(user);
      await _connectRealtime();
      return true;
    } on ApiException catch (error) {
      if (generation != _generation) return false;
      final normalizedMessage = error.message.toLowerCase();
      final requiresVerification =
          normalizedMessage.contains('not verified') ||
          normalizedMessage.contains('unverified') ||
          normalizedMessage.contains('verify your email');
      state = SessionState.unauthenticated(
        errorMessage: requiresVerification ? null : error.message,
        fieldErrors: error.fieldErrors,
        otpEmail: requiresVerification ? email : null,
      );
      return false;
    } catch (error) {
      if (generation != _generation) return false;
      state = SessionState.unauthenticated(errorMessage: error.toString());
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    final client = googleAuthClient;
    if (client == null || state.isBusy) return false;
    final generation = ++_generation;
    state = const SessionState(
      status: SessionStatus.authenticating,
      pendingAction: AuthPendingAction.googleLogin,
    );
    try {
      final idToken = await client.authenticate();
      if (generation != _generation) return false;
      if (idToken == null) {
        state = const SessionState.unauthenticated();
        return false;
      }
      final user = await _authRepository.loginWithGoogle(idToken: idToken);
      if (generation != _generation) return false;
      if (!user.emailVerified) {
        state = SessionState.unauthenticated(otpEmail: user.email);
        return false;
      }
      if (user.role != 'USER') {
        state = SessionState.unsupportedRole(user);
        return false;
      }
      state = SessionState.authenticated(user);
      await _connectRealtime();
      return true;
    } on ApiException catch (error) {
      if (generation != _generation) return false;
      state = SessionState.unauthenticated(errorMessage: error.message);
      return false;
    } catch (error) {
      if (generation != _generation) return false;
      state = const SessionState.unauthenticated(
        errorMessage:
            'Google sign-in could not be completed. Please try again.',
      );
      return false;
    }
  }

  void clearFieldError(String field) {
    if (!state.fieldErrors.containsKey(field)) return;
    final nextErrors = Map<String, String>.from(state.fieldErrors)
      ..remove(field);
    state = SessionState.unauthenticated(
      errorMessage: state.errorMessage,
      fieldErrors: nextErrors,
      otpEmail: state.otpEmail,
    );
  }

  Future<void> _connectRealtime() async {
    try {
      await connectRealtime?.call();
    } on Object {
      return;
    }
  }

  Future<void> expireSession() async {
    _generation++;
    state = const SessionState.unauthenticated(
      errorMessage: 'Your session expired. Please sign in again.',
    );
    await cleanup?.run();
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

  void updateCurrentUser(AppUser user) {
    if (state.isAuthenticated && state.user?.id == user.id) {
      state = SessionState.authenticated(user);
    }
  }

  Future<void> signOut() async {
    if (state.pendingAction == AuthPendingAction.logout) return;
    _generation++;
    final user = state.user;
    state = SessionState(
      status: state.status,
      user: user,
      pendingAction: AuthPendingAction.logout,
    );
    try {
      await _authRepository.logout();
      await cleanup?.run();
    } finally {
      state = const SessionState.unauthenticated();
    }
  }
}
