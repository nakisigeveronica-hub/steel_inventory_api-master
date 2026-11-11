import 'package:flutter/material.dart';

import 'database/database_helper.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/onboarding_screen.dart';
import 'services/auth_session.dart';
import 'services/user_permissions.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SteelInventoryApp());
}

class SteelInventoryApp extends StatelessWidget {
  const SteelInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeMode,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Steel Inventory',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: themeMode,
          home: const AppGate(),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pulse = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primaryContainer,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final safeScale = (0.85 + (pulse.value * 0.15)).clamp(0.0, 1.5);
                final safeOpacity = (0.5 + (pulse.value * 0.5)).clamp(0.0, 1.0);

                return Transform.scale(
                  scale: safeScale,
                  child: Opacity(
                    opacity: safeOpacity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 122,
                          height: 122,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 26,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Text(
                          'Steel Inventory',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Managing stock with precision',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: 120,
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.18,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool _isLoading = true;
  bool _needsOnboarding = false;
  Map<String, dynamic>? _activeUser;

  @override
  void initState() {
    super.initState();
    _checkStartupState();
  }

  Future<void> _checkStartupState() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      final hasUsers = await DatabaseHelper.instance.hasUsers();
      if (!mounted) return;

      if (!hasUsers) {
        setState(() {
          _needsOnboarding = true;
          _isLoading = false;
        });
        return;
      }

      final savedUser = await AuthSession.getCurrentUser();
      Map<String, dynamic>? activeUser;
      if (savedUser != null) {
        final userId = int.tryParse(savedUser['id']?.toString() ?? '') ?? 0;
        final databaseUser = await DatabaseHelper.instance.getUserById(userId);
        final role = UserPermissions.normalizeRole(databaseUser?['role']);
        if (databaseUser == null || role.isEmpty) {
          await AuthSession.clearSession();
        } else {
          activeUser = {...databaseUser, 'role': role};
          await AuthSession.saveCurrentUser(activeUser);
        }
      }
      if (!mounted) return;

      setState(() {
        _activeUser = activeUser;
        _needsOnboarding = false;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _needsOnboarding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SplashScreen();
    }

    if (_needsOnboarding) {
      return const OnboardingScreen();
    }

    if (_activeUser != null) {
      return MainNavigation(user: _activeUser!);
    }

    return const LoginScreen();
  }
}
