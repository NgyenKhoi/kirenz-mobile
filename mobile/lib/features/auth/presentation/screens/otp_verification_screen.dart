import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/otp_controller.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({this.email, this.otpWasSent = false, super.key});

  final String? email;
  final bool otpWasSent;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
  Timer? _clock;
  bool _autoSubmitted = false;

  OtpArguments get _arguments => OtpArguments(
    email: widget.email?.trim() ?? '',
    otpWasSent: widget.otpWasSent,
  );

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_handleCodeChanged);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _codeFocusNode.requestFocus());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _codeController
      ..removeListener(_handleCodeChanged)
      ..dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  void _handleCodeChanged() {
    ref.read(otpControllerProvider(_arguments).notifier).clearError();
    if (_codeController.text.length < 6) _autoSubmitted = false;
    if (_codeController.text.length == 6 && !_autoSubmitted) {
      _autoSubmitted = true;
      _verify();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final otp = ref.watch(otpControllerProvider(_arguments));
    final isVerifying = otp.pendingAction == OtpPendingAction.verify;
    final isSending = otp.pendingAction == OtpPendingAction.resend;
    final cooldown = otp.cooldownSeconds(DateTime.now());
    final canVerify = otp.email.isNotEmpty && _codeController.text.length == 6;

    ref.listen(otpControllerProvider(_arguments), (previous, next) {
      if (next.verified && previous?.verified != true) context.go('/login');
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Verify email')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Enter your code', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  otp.email.isEmpty
                      ? 'Return to registration and enter your email again.'
                      : 'We use a six-digit code for ${_maskedEmail(otp.email)}. The code is valid for five minutes.',
                ),
                if (!otp.otpWasAutoSent) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Automatic delivery was not confirmed. Tap Send code to try again.',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 28),
                Semantics(
                  label: 'Six-digit verification code',
                  textField: true,
                  child: Stack(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) {
                          final value = _codeController.text;
                          return Container(
                            width: 48,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: otp.errorMessage == null
                                    ? theme.colorScheme.outline
                                    : theme.colorScheme.error,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              index < value.length ? value[index] : '',
                              style: theme.textTheme.headlineSmall,
                            ),
                          );
                        }),
                      ),
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.01,
                          child: TextField(
                            controller: _codeController,
                            focusNode: _codeFocusNode,
                            enabled: !otp.isPending,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (otp.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    otp.errorMessage!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: canVerify && !otp.isPending ? _verify : null,
                  child: isVerifying
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: otp.email.isEmpty || otp.isPending || cooldown > 0
                      ? null
                      : _sendCode,
                  child: isSending
                      ? const Text('Sending…')
                      : Text(cooldown > 0 ? 'Resend in 00:${cooldown.toString().padLeft(2, '0')}' : 'Send code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _verify() async {
    final success = await ref
        .read(otpControllerProvider(_arguments).notifier)
        .verify(_codeController.text);
    if (!success && mounted) {
      _codeController.clear();
      _autoSubmitted = false;
      _codeFocusNode.requestFocus();
    }
  }

  Future<void> _sendCode() async {
    final sent = await ref.read(otpControllerProvider(_arguments).notifier).resend();
    if (sent) {
      _codeController.clear();
      _autoSubmitted = false;
      _codeFocusNode.requestFocus();
    }
  }
}

String _maskedEmail(String email) {
  final separator = email.indexOf('@');
  if (separator <= 1) return email;
  return '${email[0]}${'*' * (separator - 1)}${email.substring(separator)}';
}
