import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/core/errors/api_exception.dart';
import 'package:kirenz_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:kirenz_mobile/features/auth/presentation/controllers/otp_controller.dart';

void main() {
  test('uses an absolute cooldown when the code was sent', () {
    final now = DateTime(2026, 7, 15, 12);
    final controller = OtpController(
      _FakeAuthRepository(),
      email: 'user@example.com',
      otpWasSent: true,
      now: () => now,
    );

    expect(controller.state.email, 'user@example.com');
    expect(controller.state.cooldownEndsAt, now.add(const Duration(seconds: 60)));
    expect(controller.state.cooldownSeconds(now), 60);
    expect(controller.state.cooldownSeconds(now.add(const Duration(seconds: 61))), 0);
  });

  test('only one concurrent verification reaches the repository', () async {
    final repository = _FakeAuthRepository()..verifyCompleter = Completer<void>();
    final controller = OtpController(
      repository,
      email: 'user@example.com',
      otpWasSent: false,
    );

    final first = controller.verify('123456');
    final second = await controller.verify('123456');
    expect(second, isFalse);
    expect(repository.verifyCalls, 1);

    repository.verifyCompleter!.complete();
    expect(await first, isTrue);
    expect(controller.state.verified, isTrue);
  });

  test('failed resend remains available and keeps backend message', () async {
    final now = DateTime(2026, 7, 15, 12);
    final repository = _FakeAuthRepository(
      resendError: const ApiException('Please wait before requesting another code.'),
    );
    final controller = OtpController(
      repository,
      email: 'user@example.com',
      otpWasSent: false,
      now: () => now,
    );

    expect(await controller.resend(), isFalse);
    expect(controller.state.errorMessage, 'Please wait before requesting another code.');
    expect(controller.state.cooldownSeconds(now), 0);
    expect(controller.state.pendingAction, isNull);
  });

  test('already verified response completes the flow', () async {
    final controller = OtpController(
      _FakeAuthRepository(
        verifyError: const ApiException('Email is already verified.'),
      ),
      email: 'user@example.com',
      otpWasSent: false,
    );

    expect(await controller.verify('123456'), isTrue);
    expect(controller.state.verified, isTrue);
    expect(controller.state.errorMessage, isNull);
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.verifyError, this.resendError});

  final Object? verifyError;
  final Object? resendError;
  Completer<void>? verifyCompleter;
  int verifyCalls = 0;

  @override
  Future<void> verifyOtp({required String email, required String code}) async {
    verifyCalls++;
    if (verifyError != null) throw verifyError!;
    await verifyCompleter?.future;
  }

  @override
  Future<void> sendOtp({required String email}) async {
    if (resendError != null) throw resendError!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
