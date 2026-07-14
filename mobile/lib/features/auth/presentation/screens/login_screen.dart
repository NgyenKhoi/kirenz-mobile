import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final session = ref.watch(sessionControllerProvider);
    final isBusy = session.status == SessionStatus.authenticating;

    ref.listen(sessionControllerProvider, (previous, next) {
      final message = next.errorMessage;
      if (message != null && message.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: colors.onPrimaryContainer,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Moments',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome back to Kirenz.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Sign in',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _emailController,
                            enabled: !isBusy,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email is required';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            enabled: !isBusy,
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => isBusy ? null : _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 22),
                          FilledButton(
                            onPressed: isBusy ? null : _submit,
                            child: isBusy
                                ? SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.onPrimary,
                                    ),
                                  )
                                : const Text('Continue'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.g_mobiledata_rounded),
                            label: const Text('Continue with Google'),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: isBusy ? null : () => context.go('/register'),
                            child: const Text('Create account'),
                          ),
                        ],
                      ),
                    ),
                  ),
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

    await ref
        .read(sessionControllerProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }
}
