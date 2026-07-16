import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/leaderboard_provider.dart';
import '../providers/social_provider.dart';
import 'onboarding_screen.dart';
import 'dashboard_screen.dart';
import 'auth_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isLoading = false;
  bool _continueOffline = false;
  bool _authChecked = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  Future<void> _navigateToNext({bool immediate = false}) async {
    if (!immediate) {
      await Future.delayed(const Duration(milliseconds: 1500));
    }
    if (!mounted) return;

    final settings = ref.read(settingsProvider);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => settings.completedOnboarding
            ? const DashboardScreen()
            : const OnboardingScreen(),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(authServiceProvider);
      await service.signInWithGoogle();

      // Sync public profile and leaderboard score
      final settings = ref.read(settingsProvider);
      await ref.read(socialServiceProvider).syncCurrentUserPublicProfile(
            shareActivityWithFriends: settings.shareActivityWithFriends,
            socialNotifications: settings.socialNotifications,
            friendRequestMode: settings.friendRequestMode,
          );
      await ref
          .read(leaderboardServiceProvider)
          .syncCurrentUserScore(ref.read(habitNotifierProvider));

      _navigateToNext(immediate: true);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithEmail() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
    // When they pop back, check if they successfully logged in
    final user = ref.read(authServiceProvider).currentUser;
    if (user != null) {
      _navigateToNext(immediate: true);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      next.whenOrNull(
        data: (user) {
          if (user != null && !_authChecked) {
            _authChecked = true;
            _navigateToNext();
          }
        },
      );
    });

    final authState = ref.watch(authStateProvider);
    final currentUser = authState.valueOrNull;
    final bool showLogin = currentUser == null && !authState.isLoading && !_continueOffline;

    Widget logoBranding = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF28D7F0), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF28D7F0).withValues(alpha: 0.45),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.coffee,
              color: Color(0xFF28D7F0),
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'NOOK & PIXEL',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 4.2,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'CREATIVE STUDIOS',
          style: TextStyle(
            color: Color(0xFF94A0B8),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.8,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );

    Widget loginOptions = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Sign in to sync your habits and compete with friends.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF94A0B8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 24),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF28D7F0),
            ),
          )
        else ...[
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0x33FFFFFF)),
              ),
            ),
            onPressed: _signInWithGoogle,
            icon: const Icon(Icons.g_mobiledata_rounded, color: Color(0xFF28D7F0), size: 28),
            label: const Text(
              'Continue with Google',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111726),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0x22FFFFFF)),
              ),
            ),
            onPressed: _signInWithEmail,
            icon: const Icon(Icons.email_outlined, color: Color(0xFF94A0B8), size: 20),
            label: const Text(
              'Sign In with Email',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              setState(() {
                _continueOffline = true;
              });
              _navigateToNext(immediate: true);
            },
            child: const Text(
              'CONTINUE OFFLINE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF555F75),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFF080A10),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;

            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isLandscape ? 700 : 360,
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: isLandscape
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(child: logoBranding),
                                  if (showLogin) ...[
                                    const VerticalDivider(
                                      color: Color(0x22FFFFFF),
                                      width: 40,
                                      indent: 20,
                                      endIndent: 20,
                                    ),
                                    Expanded(child: loginOptions),
                                  ] else ...[
                                    const Expanded(
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF28D7F0),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  logoBranding,
                                  const SizedBox(height: 40),
                                  if (showLogin)
                                    loginOptions
                                  else
                                    const CircularProgressIndicator(
                                      color: Color(0xFF28D7F0),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
