import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../services/auth_session.dart';
import '../services/user_permissions.dart';
import 'admin_recovery_screen.dart';
import 'main_navigation.dart';
import 'onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _selectedRole;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedRole == null) {
      _showMessage('Select the role assigned to your account.', isError: true);
      return;
    }

    final username = _usernameController.text.trim();

    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
    });

    try {
      final db = await _databaseHelper.database;

final savedUsers = await db.query(
  'users',
  columns: ['id', 'username', 'role'],
);

debugPrint('DATABASE USERS: $savedUsers');
debugPrint('LOGIN USERNAME: ${usernameController.text.trim()}');

      final users = await db.query(
        'users',
        where: 'username = ? COLLATE NOCASE',
        whereArgs: [username],
        limit: 1,
      );

      if (!mounted) return;

      if (users.isEmpty) {
        setState(() {
          _isLoading = false;
        });

        _showMessage(
          'No account was found for that username. Check its spelling or '
          'create the account on this device.',
          isError: true,
        );

        return;
      }

      final user = Map<String, dynamic>.from(users.first);
      final storedPassword = (user['password'] ?? '').toString();

      if (!DatabaseHelper.passwordMatches(password, storedPassword)) {
        setState(() {
          _isLoading = false;
        });

        _showMessage(
          'The password does not match this account. Passwords are '
          'case-sensitive; use Show password to check what you entered.',
          isError: true,
        );
        return;
      }

      final role = UserPermissions.normalizeRole(user['role']);
      if (role.isEmpty) {
        setState(() => _isLoading = false);
        _showMessage(
          'This account has an invalid role. Contact an Administrator.',
          isError: true,
        );
        return;
      }
      if (role != _selectedRole) {
        setState(() => _isLoading = false);
        _showMessage(
          'This account is assigned to $role. Select that role to sign in.',
          isError: true,
        );
        return;
      }
      user['role'] = role;

      setState(() {
        _isLoading = false;
      });

      await AuthSession.saveCurrentUser(user);

      // Navigate to the authenticated app shell.
      // The complete SQLite user record is passed,
      // including id, full_name, username and role.
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainNavigation(user: user)),
      );
    } catch (e, stackTrace) {
      if (!mounted) return;

      debugPrint('Login failed while accessing the local account database: $e');
      debugPrintStack(stackTrace: stackTrace);
      setState(() {
        _isLoading = false;
      });

      _showMessage('Unable to login. Please try again.', isError: true);
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : const Color(0xFF379805),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  IconData _roleIcon(String role) {
    if (role == UserPermissions.supervisor) {
      return Icons.supervisor_account_outlined;
    }
    if (role == UserPermissions.administrator) {
      return Icons.admin_panel_settings_outlined;
    }
    return Icons.inventory_2_outlined;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildLoginCard(),
                  const SizedBox(height: 16),
                  _buildOfflineInfo(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF379805),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF379805).withValues(alpha: 0.20),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset('assets/images/app_logo.png', fit: BoxFit.cover),
          ),
        ),

        const SizedBox(height: 14),

        Text(
          'Steel Inventory',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LOGIN CARD
  // ============================================================

  Widget _buildLoginCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose your role',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final role in UserPermissions.roles)
                    ChoiceChip(
                      avatar: Icon(
                        _roleIcon(role),
                        size: 18,
                        color: _selectedRole == role
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.primary,
                      ),
                      label: Text(role),
                      selected: _selectedRole == role,
                      onSelected: _isLoading
                          ? null
                          : (_) => setState(() => _selectedRole = role),
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: _selectedRole == role
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 18),

              Text(
                'Sign in as ${_selectedRole ?? 'a user'}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.text,
                enabled: !_isLoading,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter your username';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: _obscurePassword,
                keyboardType: TextInputType.visiblePassword,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter your password';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              // --------------------------------------------------
              // LOGIN BUTTON
              // --------------------------------------------------
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF379805),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login, size: 21),
                            SizedBox(width: 9),
                            Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OnboardingScreen(),
                            ),
                          );
                        },
                  child: Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Don\'t have an account? Sign up',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: TextButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const AdminRecoveryScreen(),
                            ),
                          );
                        },
                  icon: const Icon(Icons.lock_reset_outlined, size: 18),
                  label: const Text('Forgot Administrator password?'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // OFFLINE INFORMATION
  // ============================================================

  Widget _buildOfflineInfo() {
    return Text(
      'Your inventory data is stored on this device.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
