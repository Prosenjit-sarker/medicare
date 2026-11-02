import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth_repository.dart';
import 'auth_providers.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _consent = false;
  bool _showPassword = false;
  String? _verificationEmail;
  bool _verificationEmailSentAgain = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _resendVerificationEmail() async {
    final email = _verificationEmail;
    if (email == null) return;
    await ref.read(authControllerProvider.notifier).resendVerificationEmail(email, _pass.text);
    if (!mounted) return;
    if (!ref.read(authControllerProvider).hasError) {
      setState(() => _verificationEmailSentAgain = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyAuthError(next.error!))));
      }
    });
    final loading = ref.watch(authControllerProvider).isLoading;

    final verificationEmail = _verificationEmail;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: verificationEmail != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        IconButton(
                          alignment: Alignment.centerLeft,
                          onPressed: () => context.go('/login'),
                          icon: const Icon(Icons.arrow_back),
                          tooltip: 'Back to sign in',
                        ),
                        const SizedBox(height: 36),
                        Icon(Icons.mark_email_read_outlined, size: 58, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 24),
                        Text(
                          'Check your inbox',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'We sent a verification link to $verificationEmail. Verify your email before signing in.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Check Spam or Promotions if it is not in your inbox.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: loading || _verificationEmailSentAgain ? null : _resendVerificationEmail,
                          icon: loading
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.refresh),
                          label: Text(
                            loading
                                ? 'Sending...'
                                : _verificationEmailSentAgain
                                ? 'Verification email sent'
                                : 'Resend verification email',
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => context.go('/login'),
                          icon: const Icon(Icons.login),
                          label: const Text('Continue to sign in'),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Didn’t receive the email? Sign in with your password and we’ll send another link.',
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    )
                  : Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          IconButton(
                            alignment: Alignment.centerLeft,
                            onPressed: () => context.go('/login'),
                            icon: const Icon(Icons.arrow_back),
                            tooltip: 'Back to sign in',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'MediCare BD',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Create your account',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'A verified email keeps your health account secure.',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) => (value == null || value.trim().length < 2) ? 'Enter your name' : null,
                          ),
                          const SizedBox(height: 16),
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
                            autofillHints: const [AutofillHints.newPassword],
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
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _consent,
                            onChanged: (value) => setState(() => _consent = value ?? false),
                            title: const Text(
                              'I agree to the processing of my health data as described in Privacy & Data.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: (loading || !_consent)
                                ? null
                                : () async {
                                    if (_form.currentState!.validate()) {
                                      final email = _email.text.trim();
                                      await ref
                                          .read(authControllerProvider.notifier)
                                          .register(_name.text.trim(), email, _pass.text);
                                      if (mounted && !ref.read(authControllerProvider).hasError) {
                                        setState(() => _verificationEmail = email);
                                      }
                                    }
                                  },
                            icon: loading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.mark_email_unread_outlined),
                            label: Text(loading ? 'Sending verification link...' : 'Create account'),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Flexible(child: Text('Already have an account?')),
                              TextButton(onPressed: () => context.go('/login'), child: const Text('Sign in')),
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
