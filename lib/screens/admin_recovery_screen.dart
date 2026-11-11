import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../database/database_helper.dart';

class AdminRecoveryScreen extends StatefulWidget {
  const AdminRecoveryScreen({super.key});

  @override
  State<AdminRecoveryScreen> createState() => _AdminRecoveryScreenState();
}

class _AdminRecoveryScreenState extends State<AdminRecoveryScreen> {
  static const _recoveryAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final _database = DatabaseHelper.instance;
  final _recoveryCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _adminAccounts = [];
  int? _selectedAdminId;
  bool _hasRecoveryCode = false;
  bool _isLoading = true;
  bool _isAuthenticating = false;
  bool _isSaving = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _loadRecoveryState();
  }

  @override
  void dispose() {
    _recoveryCodeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadRecoveryState() async {
    try {
      final results = await Future.wait<Object>([
        _database.getAdministratorAccounts(),
        _database.hasAdminRecoveryCode(),
      ]);
      if (!mounted) return;
      final admins = results[0] as List<Map<String, dynamic>>;
      setState(() {
        _adminAccounts = admins;
        _hasRecoveryCode = results[1] as bool;
        _selectedAdminId = admins.isEmpty
            ? null
            : int.tryParse(admins.first['id']?.toString() ?? '');
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Unable to load Administrator recovery: $error', true);
    }
  }

  Future<bool> _authenticateDeviceOwner() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      _showMessage(
        'Device-owner recovery is currently available on Android only.',
        true,
      );
      return false;
    }

    setState(() => _isAuthenticating = true);
    try {
      final localAuth = LocalAuthentication();
      if (!await localAuth.isDeviceSupported()) {
        if (!mounted) return false;
        setState(() => _isAuthenticating = false);
        _showMessage(
          'Set up a screen lock, PIN, pattern, or biometric on this phone '
          'before recovering Administrator access.',
          true,
        );
        return false;
      }

      final authenticated = await localAuth.authenticate(
        localizedReason:
            'Verify this phone owner to reset Administrator access',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (!mounted) return false;
      setState(() => _isAuthenticating = false);
      if (!authenticated) {
        _showMessage('Device verification was not completed.', true);
      }
      return authenticated;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _isAuthenticating = false);
      _showMessage(
        'Device verification failed. Check that this phone has a screen lock '
        'or biometric configured. Details: $error',
        true,
      );
      return false;
    }
  }

  String _generateRecoveryCode() {
    final random = Random.secure();
    final characters = List.generate(
      16,
      (_) => _recoveryAlphabet[random.nextInt(_recoveryAlphabet.length)],
    );
    final grouped = <String>[];
    for (var index = 0; index < characters.length; index += 4) {
      grouped.add(characters.skip(index).take(4).join());
    }
    return grouped.join('-');
  }

  Future<void> _resetPassword({bool verifyDeviceOwner = false}) async {
    if (_selectedAdminId == null || !_formKey.currentState!.validate()) return;
    if (!verifyDeviceOwner && _recoveryCodeController.text.trim().isEmpty) {
      _showMessage('Enter the recovery code.', true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      if (verifyDeviceOwner && !await _authenticateDeviceOwner()) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      final newRecoveryCode = verifyDeviceOwner
          ? _generateRecoveryCode()
          : null;
      if (newRecoveryCode != null) {
        await _database.resetAdministratorPasswordWithDeviceAuth(
          userId: _selectedAdminId!,
          newPassword: _passwordController.text,
          newRecoveryCode: newRecoveryCode,
        );
      } else {
        await _database.resetAdministratorPasswordWithRecoveryCode(
          userId: _selectedAdminId!,
          recoveryCode: _recoveryCodeController.text,
          newPassword: _passwordController.text,
        );
      }

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _hasRecoveryCode = true;
        _passwordController.clear();
        _confirmPasswordController.clear();
        _recoveryCodeController.clear();
      });

      if (newRecoveryCode != null) {
        await _showRecoveryCode(newRecoveryCode);
      } else {
        _showMessage(
          'Administrator password reset. Sign in with the new password.',
          false,
        );
      }
    } on UserManagementException catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage(error.message, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('Unable to reset Administrator password: $error', true);
    }
  }

  Future<void> _showRecoveryCode(String code) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Save your recovery code'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I saved the code'),
          ),
        ],
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        semanticLabel: 'Administrator recovery code',
        icon: const Icon(Icons.key_outlined),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Administrator password was reset. Save this code '
              'somewhere private. It will not be shown again.',
            ),
            const SizedBox(height: 16),
            SelectableText(
              code,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message, bool isError) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administrator recovery')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _adminAccounts.isEmpty
          ? const Center(child: Text('No Administrator account was found.'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(Icons.admin_panel_settings_outlined, size: 52),
                const SizedBox(height: 12),
                Text(
                  _hasRecoveryCode
                      ? 'Reset Administrator password'
                      : 'Set up Administrator recovery',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  _hasRecoveryCode
                      ? 'Use your recovery code, or verify this phone owner '
                            'to reset the password and replace the code.'
                      : 'This account has no recovery code yet. Verify this '
                            'phone owner to reset its password and create a '
                            'one-time recovery code. Your inventory data will '
                            'not be changed.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                DropdownButtonFormField<int>(
                  initialValue: _selectedAdminId,
                  decoration: const InputDecoration(
                    labelText: 'Administrator account',
                    border: OutlineInputBorder(),
                  ),
                  items: _adminAccounts.map((admin) {
                    final id = int.tryParse(admin['id']?.toString() ?? '');
                    return DropdownMenuItem<int>(
                      value: id,
                      child: Text(
                        '${admin['full_name']} · ${admin['username']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) => setState(() => _selectedAdminId = value),
                ),
                if (_hasRecoveryCode) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _recoveryCodeController,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Recovery code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        keyboardType: TextInputType.visiblePassword,
                        textCapitalization: TextCapitalization.none,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: 'New password',
                          border: const OutlineInputBorder(),
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
                        validator: (value) => value == null || value.length < 8
                            ? 'Use at least 8 characters'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        keyboardType: TextInputType.visiblePassword,
                        textCapitalization: TextCapitalization.none,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: 'Confirm new password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _obscureConfirmPassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => value != _passwordController.text
                            ? 'Passwords do not match'
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!_hasRecoveryCode)
                  FilledButton.icon(
                    onPressed: _isAuthenticating || _isSaving
                        ? null
                        : () => _resetPassword(verifyDeviceOwner: true),
                    icon: _isAuthenticating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fingerprint),
                    label: Text(
                      _isAuthenticating
                          ? 'Verifying phone owner...'
                          : 'Verify phone and reset password',
                    ),
                  ),
                if (_hasRecoveryCode)
                  FilledButton.icon(
                    onPressed: _isSaving ? null : () => _resetPassword(),
                    icon: const Icon(Icons.lock_reset),
                    label: const Text('Reset with recovery code'),
                  ),
                if (_hasRecoveryCode)
                  OutlinedButton.icon(
                    onPressed: _isAuthenticating || _isSaving
                        ? null
                        : () => _resetPassword(verifyDeviceOwner: true),
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Verify phone and replace recovery code'),
                  ),
              ],
            ),
    );
  }
}
