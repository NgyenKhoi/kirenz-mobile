import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/repositories/auth_repository.dart';

final otpControllerProvider = StateNotifierProvider.autoDispose
    .family<OtpController, OtpState, OtpArguments>((ref, arguments) {
      return OtpController(
        ref.watch(authRepositoryProvider),
        email: arguments.email,
        otpWasSent: arguments.otpWasSent,
      );
    });

class OtpArguments {
  const OtpArguments({required this.email, required this.otpWasSent});

  final String email;
  final bool otpWasSent;

  @override
  bool operator ==(Object other) =>
      other is OtpArguments &&
      other.email == email &&
      other.otpWasSent == otpWasSent;

  @override
  int get hashCode => Object.hash(email, otpWasSent);
}

enum OtpPendingAction { verify, resend }

enum OtpFailureKind { invalidCode, expired, rateLimited, transport, other }

class OtpState {
  const OtpState({
    required this.email,
    required this.otpWasAutoSent,
    this.cooldownEndsAt,
    this.pendingAction,
    this.errorMessage,
    this.verified = false,
    this.failureKind,
  });

  final String email;
  final bool otpWasAutoSent;
  final DateTime? cooldownEndsAt;
  final OtpPendingAction? pendingAction;
  final String? errorMessage;
  final bool verified;
  final OtpFailureKind? failureKind;

  bool get isPending => pendingAction != null;

  int cooldownSeconds(DateTime now) {
    final end = cooldownEndsAt;
    if (end == null) return 0;
    final milliseconds = end.difference(now).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  OtpState copyWith({
    DateTime? cooldownEndsAt,
    bool clearCooldown = false,
    OtpPendingAction? pendingAction,
    bool clearPending = false,
    String? errorMessage,
    bool clearError = false,
    bool? verified,
    bool? otpWasAutoSent,
    OtpFailureKind? failureKind,
    bool clearFailure = false,
  }) {
    return OtpState(
      email: email,
      otpWasAutoSent: otpWasAutoSent ?? this.otpWasAutoSent,
      cooldownEndsAt: clearCooldown
          ? null
          : cooldownEndsAt ?? this.cooldownEndsAt,
      pendingAction: clearPending ? null : pendingAction ?? this.pendingAction,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      verified: verified ?? this.verified,
      failureKind: clearFailure ? null : failureKind ?? this.failureKind,
    );
  }
}

class OtpController extends StateNotifier<OtpState> {
  OtpController(
    this._repository, {
    required String email,
    required bool otpWasSent,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(
         OtpState(
           email: email.trim(),
           otpWasAutoSent: otpWasSent,
           cooldownEndsAt: otpWasSent
               ? (now ?? DateTime.now)().add(const Duration(seconds: 60))
               : null,
         ),
       );

  final AuthRepository _repository;
  final DateTime Function() _now;

  void clearError() {
    if (state.errorMessage != null) state = state.copyWith(clearError: true);
  }

  Future<bool> verify(String code) async {
    if (state.isPending || state.email.isEmpty || code.length != 6) {
      return false;
    }
    state = state.copyWith(
      pendingAction: OtpPendingAction.verify,
      clearError: true,
      clearFailure: true,
    );
    try {
      await _repository.verifyOtp(email: state.email, code: code);
      state = state.copyWith(
        verified: true,
        clearPending: true,
        clearError: true,
        clearFailure: true,
      );
      return true;
    } on ApiException catch (error) {
      final alreadyVerified = error.message.toLowerCase().contains(
        'already verified',
      );
      state = state.copyWith(
        verified: alreadyVerified,
        errorMessage: alreadyVerified ? null : error.message,
        failureKind: alreadyVerified ? null : _classifyFailure(error),
        clearError: alreadyVerified,
        clearFailure: alreadyVerified,
        clearPending: true,
      );
      return alreadyVerified;
    } catch (error) {
      state = state.copyWith(
        errorMessage: error.toString(),
        failureKind: OtpFailureKind.other,
        clearPending: true,
      );
      return false;
    }
  }

  Future<bool> resend() async {
    if (state.isPending ||
        state.email.isEmpty ||
        state.cooldownSeconds(_now()) > 0) {
      return false;
    }
    state = state.copyWith(
      pendingAction: OtpPendingAction.resend,
      clearError: true,
      clearFailure: true,
    );
    try {
      await _repository.sendOtp(email: state.email);
      state = state.copyWith(
        cooldownEndsAt: _now().add(const Duration(seconds: 60)),
        otpWasAutoSent: true,
        clearPending: true,
        clearError: true,
        clearFailure: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        errorMessage: error.toString(),
        failureKind: error is ApiException
            ? _classifyFailure(error)
            : OtpFailureKind.other,
        clearPending: true,
      );
      return false;
    }
  }

  OtpFailureKind _classifyFailure(ApiException error) {
    final message = error.message.toLowerCase();
    if (message.contains('expired')) return OtpFailureKind.expired;
    if (error.statusCode == 429 ||
        message.contains('rate limit') ||
        message.contains('too many') ||
        message.contains('please wait')) {
      return OtpFailureKind.rateLimited;
    }
    if (error.statusCode == null &&
        (message.contains('cannot reach') ||
            message.contains('network') ||
            message.contains('connection') ||
            message.contains('timeout'))) {
      return OtpFailureKind.transport;
    }
    if (message.contains('invalid') || message.contains('incorrect')) {
      return OtpFailureKind.invalidCode;
    }
    return OtpFailureKind.other;
  }
}
