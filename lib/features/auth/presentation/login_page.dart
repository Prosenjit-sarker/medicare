import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth_repository.dart';
import 'auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _showPassword = false;
  bool _showResendVerification = false;
  bool _verificationEmailSent = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      setState(() {
        _showResendVerification = false;
        _verificationEmailSent = false;
      });
      ref.read(authControllerProvider.notifier).login(_email.text.trim(), _pass.text);
    }
  }

  Future<void> _resendVerification() async {
    await ref.read(authControllerProvider.notifier).resendVerificationEmail(_email.text.trim(), _pass.text);
    if (!mounted) return;
    if (!ref.read(authControllerProvider).hasError) {
      setState(() {
        _showResendVerification = false;
        _verificationEmailSent = true;
      });
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (!isValidEmailAddress(email)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your email first.')));
      return;
    }
    await ref.read(authControllerProvider.notifier).reset(email);
    if (mounted && !ref.read(authControllerProvider).hasError) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError) {
        final error = next.error;
        setState(() {
          _showResendVerification = error is FirebaseAuthException && error.code == 'email-not-verified';
          _verificationEmailSent = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyAuthError(next.error!))));
      }
    });
    final loading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 58,
                      width: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.health_and_safety_outlined,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'MediCare BD',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Welcome back',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue to your health services.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (value) => isValidEmailAddress(value) ? null : 'Enter a valid email address',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pass,
                      obscureText: !_showPassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => loading ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _showPassword ? 'Hide password' : 'Show password',
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                          icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        ),
                      ),
                      validator: (value) => (value == null || value.length < 6) ? 'At least 6 characters' : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(onPressed: loading ? null : _forgot, child: const Text('Forgot password?')),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: loading ? null : _submit,
                      icon: loading
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.login),
                      label: Text(loading ? 'Signing in...' : 'Sign in'),
                    ),
                    if (_showResendVerification) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: loading ? null : _resendVerification,
                        icon: const Icon(Icons.mark_email_unread_outlined),
                        label: const Text('Resend verification email'),
                      ),
                    ],
                    if (_verificationEmailSent)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Verification link sent. Check your inbox and spam folder.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Flexible(child: Text('New to MediCare BD?')),
                        TextButton(onPressed: () => context.go('/register'), child: const Text('Create account')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
