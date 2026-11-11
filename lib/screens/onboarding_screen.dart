import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _companyController = TextEditingController(
    text: 'Steel Inventory',
  );
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _companyController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final companyName = _companyController.text.trim();
    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
    });

    try {
      final accountCreated = await _databaseHelper.createAdminUser(
        companyName: companyName.isEmpty ? 'Steel Inventory' : companyName,
        fullName: fullName,
        username: username,
        password: password,
      );

      if (!accountCreated) {
        throw StateError('Required account details are missing.');
      }

      if (!mounted) return;

      _showMessage('Setup complete. Please sign in.', isError: false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } on SetupAlreadyCompletedException {
      if (!mounted) return;

      _showMessage('Setup is already complete. Please sign in.', isError: true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } on UsernameAlreadyExistsException {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
      _showMessage(
        'This username already has an account on this device. Use a different username or sign in.',
        isError: true,
      );
    } catch (error, stackTrace) {
      if (!mounted) return;

      debugPrint('Account setup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      setState(() {
        _isLoading = false;
      });

      _showMessage('Unable to complete setup: $error', isError: true);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create your account',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Set up the admin account for your inventory.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildField(
                      controller: _companyController,
                      label: 'Business name',
                      icon: Icons.business_outlined,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Company name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _fullNameController,
                      label: 'Admin full name',
                      icon: Icons.person_outline,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Admin name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _usernameController,
                      label: 'Username',
                      icon: Icons.account_circle_outlined,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Username is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      keyboardType: TextInputType.visiblePassword,
                      textCapitalization: TextCapitalization.none,
                      autocorrect: false,
                      enableSuggestions: false,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () => setState(() {
                            _obscurePassword = !_obscurePassword;
                          }),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      keyboardType: TextInputType.visiblePassword,
                      textCapitalization: TextCapitalization.none,
                      autocorrect: false,
                      enableSuggestions: false,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: const Icon(Icons.lock_reset_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscureConfirmPassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () => setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          }),
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _createAccount,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.person_add_alt_1_rounded),
                        label: Text(
                          _isLoading ? 'Creating account...' : 'Create account',
                        ),
                      ),
                    ),

                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                      child: const Text('Already have an account? Sign in'),
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}
