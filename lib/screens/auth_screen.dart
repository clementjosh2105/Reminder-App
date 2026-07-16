import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/leaderboard_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/social_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isCreatingAccount = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _runAuth(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
      // Let the Firebase auth state propagate to token caches
      await Future.delayed(const Duration(milliseconds: 600));

      final settings = ref.read(settingsProvider);
      try {
        await ref
            .read(socialServiceProvider)
            .syncCurrentUserPublicProfile(
              shareActivityWithFriends: settings.shareActivityWithFriends,
              socialNotifications: settings.socialNotifications,
              friendRequestMode: settings.friendRequestMode,
            );
      } catch (e) {
        debugPrint("Profile sync deferred: $e");
      }

      try {
        await ref
            .read(leaderboardServiceProvider)
            .syncCurrentUserScore(ref.read(habitNotifierProvider));
      } catch (e) {
        debugPrint("Leaderboard sync deferred: $e");
      }

      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? e.code);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final service = ref.read(authServiceProvider);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    await _runAuth(() async {
      if (_isCreatingAccount) {
        await service.createAccountWithEmail(
          email: email,
          password: password,
          displayName: _nameController.text,
        );
      } else {
        await service.signInWithEmail(email: email, password: password);
      }
    });
  }

  Future<void> _signInWithGoogle() async {
    await _runAuth(() => ref.read(authServiceProvider).signInWithGoogle());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Image.asset(
                'assets/streakmind-icon.png',
                width: 92,
                height: 92,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isCreatingAccount
                  ? 'Create your StreakMind account'
                  : 'Sign in to StreakMind',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Sync your profile and compete on the weekly leaderboard.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _signInWithGoogle,
              icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  if (_isCreatingAccount) ...[
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        prefixIcon: Icon(Icons.badge_rounded),
                      ),
                      validator: (value) {
                        if (!_isCreatingAccount) return null;
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.length < 2) {
                          return 'Enter at least 2 characters';
                        }
                        if (trimmed.length > 40) {
                          return 'Keep it under 40 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_rounded),
                    ),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (!trimmed.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_rounded),
                    ),
                    validator: (value) {
                      if ((value ?? '').length < 6) {
                        return 'Use at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitEmail,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _isCreatingAccount
                                  ? Icons.person_add_rounded
                                  : Icons.login_rounded,
                            ),
                      label: Text(
                        _isCreatingAccount ? 'Create account' : 'Sign in',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() => _isCreatingAccount = !_isCreatingAccount);
                    },
              child: Text(
                _isCreatingAccount
                    ? 'Already have an account? Sign in'
                    : 'New here? Create an account',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
