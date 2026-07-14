import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/auth_repository.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({
    this.email,
    this.otpWasSent = false,
    super.key,
  });

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
  DateTime? _cooldownEndsAt;
  bool _isVerifying = false;
  bool _isSending = false;
  bool _autoSubmitted = false;
  String? _errorMessage;

  String get _email => widget.email?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    if (widget.otpWasSent) {
      _startCooldown();
    }
    _codeController.addListener(_handleCodeChanged);
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

  int get _cooldownSeconds {
    final end = _cooldownEndsAt;
    if (end == null) return 0;
    final milliseconds = end.difference(DateTime.now()).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  void _startCooldown() {
    _cooldownEndsAt = DateTime.now().add(const Duration(seconds: 60));
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_cooldownSeconds == 0) _clock?.cancel();
    });
  }

  void _handleCodeChanged() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
    if (_codeController.text.length < 6) _autoSubmitted = false;
    if (_codeController.text.length == 6 && !_autoSubmitted && !_isVerifying) {
      _autoSubmitted = true;
      _verify();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canVerify = _email.isNotEmpty && _codeController.text.length == 6;
    final cooldown = _cooldownSeconds;

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
                  _email.isEmpty
                      ? 'Return to registration and enter your email again.'
                      : 'We use a six-digit code for ${_maskedEmail(_email)}. The code is valid for five minutes.',
                ),
                if (!widget.otpWasSent) ...[
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
                          final digit = index < value.length ? value[index] : '';
                          return Container(
                            width: 44,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _errorMessage == null
                                    ? theme.colorScheme.outline
                                    : theme.colorScheme.error,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(digit, style: theme.textTheme.headlineSmall),
                          );
                        }),
                      ),
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.01,
                          child: TextField(
                            controller: _codeController,
                            focusNode: _codeFocusNode,
                            enabled: !_isVerifying,
                            autofocus: true,
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
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: canVerify && !_isVerifying ? _verify : null,
                  child: _isVerifying
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _email.isEmpty || _isSending || cooldown > 0
                      ? null
                      : _sendCode,
                  child: _isSending
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
    if (_isVerifying || _codeController.text.length != 6 || _email.isEmpty) {
      return;
    }
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyOtp(
            email: _email,
            code: _codeController.text,
          );
      if (mounted) context.go('/login');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _codeController.clear();
        _autoSubmitted = false;
      });
      _codeFocusNode.requestFocus();
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _sendCode() async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendOtp(email: _email);
      if (!mounted) return;
      _codeController.clear();
      _startCooldown();
      setState(() {});
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}

String _maskedEmail(String email) {
  final separator = email.indexOf('@');
  if (separator <= 1) return email;
  return '${email[0]}${'*' * (separator - 1)}${email.substring(separator)}';
}
