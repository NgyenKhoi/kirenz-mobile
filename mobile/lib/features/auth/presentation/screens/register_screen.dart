import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    return Scaffold(
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
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Display name is required';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                enabled: !_isSubmitting,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: (value) {
                  final username = value?.trim() ?? '';
                  if (username.length < 3 || username.length > 50) {
                    return 'Username must be 3 to 50 characters';
                  }
                  if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(username)) {
                    return 'Use only letters, numbers, dots, dashes, or underscores';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.length < 5 ||
                      email.length > 255 ||
                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Enter a valid email address';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                enabled: !_isSubmitting,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (value) {
                  if (value == null || value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }

                  return null;
                },
              ),
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
                onPressed: _isSubmitting ? null : () => context.go('/login'),
                child: const Text('Back to login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

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
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
