import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/api_exception.dart';
import '../../data/repositories/auth_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  Map<String, String> _fieldErrors = const {};
  String? _formError;

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasMeaningfulInput && !_isSubmitting,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _isSubmitting) return;
        if (await _confirmDiscard() && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Register')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextFormField(
                  controller: _displayNameController,
                  enabled: !_isSubmitting,
                  onChanged: (_) => _clearFieldError('displayName'),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Display name',
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  validator: (value) {
                    final displayName = value?.trim() ?? '';
                    if (displayName.length > 100) {
                      return 'Display name must be 100 characters or fewer';
                    }

                    return _fieldErrors['displayName'];
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  enabled: !_isSubmitting,
                  onChanged: (_) => _clearFieldError('username'),
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (value) {
                    final username = value?.trim() ?? '';
                    if (username.length < 3 || username.length > 50) {
                      return 'Username must be 3 to 50 characters';
                    }
                    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(username)) {
                      return 'Use only letters, numbers, dots, dashes, or underscores';
                    }
                    return _fieldErrors['username'];
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  enabled: !_isSubmitting,
                  onChanged: (_) => _clearFieldError('email'),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.mail_outline),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.length < 5 ||
                        email.length > 255 ||
                        !RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(email)) {
                      return 'Enter a valid email address';
                    }

                    return _fieldErrors['email'];
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  enabled: !_isSubmitting,
                  onChanged: (_) => _clearFieldError('password'),
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }

                    return _fieldErrors['password'];
                  },
                ),
                if (_formError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _formError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    semanticsLabel: 'Registration error: $_formError',
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create account'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          if (await _confirmDiscard() && context.mounted) {
                            context.go('/login');
                          }
                        },
                  child: const Text('Back to login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _fieldErrors = const {};
      _formError = null;
    });

    try {
      final result = await ref
          .read(authRepositoryProvider)
          .register(
            displayName: _displayNameController.text.trim(),
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (!mounted) {
        return;
      }

      context.go(
        '/verify-otp?email=${Uri.encodeComponent(result.email)}&otpSent=${result.otpSent}',
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _fieldErrors = error.fieldErrors;
        _formError = error.fieldErrors.isEmpty ? error.message : null;
      });
      _formKey.currentState?.validate();
    } catch (error) {
      if (mounted) setState(() => _formError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _clearFieldError(String field) {
    if (!_fieldErrors.containsKey(field) && _formError == null) return;
    setState(() {
      _fieldErrors = Map<String, String>.from(_fieldErrors)..remove(field);
      _formError = null;
    });
  }

  bool get _hasMeaningfulInput =>
      _displayNameController.text.trim().isNotEmpty ||
      _usernameController.text.trim().isNotEmpty ||
      _emailController.text.trim().isNotEmpty ||
      _passwordController.text.isNotEmpty;

  Future<bool> _confirmDiscard() async {
    if (!_hasMeaningfulInput) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard registration?'),
            content: const Text(
              'Your entered account details will be lost. Your password is never saved.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
