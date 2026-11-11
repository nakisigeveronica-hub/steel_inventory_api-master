import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../services/user_permissions.dart';

class UserManagementScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;

  const UserManagementScreen({super.key, required this.currentUser});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final DatabaseHelper _database = DatabaseHelper.instance;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  int get _currentUserId =>
      int.tryParse(widget.currentUser['id']?.toString() ?? '') ?? 0;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _database.getUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Unable to load user accounts: $error', isError: true);
    }
  }

  Future<void> _openUserForm({Map<String, dynamic>? user}) async {
    if (!UserPermissions.canManageUsers(widget.currentUser['role'])) return;
    final fullNameController = TextEditingController(
      text: user?['full_name']?.toString() ?? '',
    );
    final usernameController = TextEditingController(
      text: user?['username']?.toString() ?? '',
    );
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var selectedRole = UserPermissions.normalizeRole(user?['role']).isEmpty
        ? UserPermissions.inventoryPersonnel
        : UserPermissions.normalizeRole(user?['role']);
    var obscurePassword = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(user == null ? 'Create user account' : 'Edit user'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: fullNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: usernameController,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Username'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a username'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: UserPermissions.roles
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            ),
                          )
                          .toList(),
                      onChanged: (role) {
                        if (role != null) {
                          setDialogState(() => selectedRole = role);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      keyboardType: TextInputType.visiblePassword,
                      textCapitalization: TextCapitalization.none,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: user == null
                            ? 'Password (at least 6 characters)'
                            : 'New password (optional)',
                        suffixIcon: IconButton(
                          tooltip: obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () => setDialogState(
                            () => obscurePassword = !obscurePassword,
                          ),
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final password = value ?? '';
                        if (user == null && password.length < 6) {
                          return 'Use at least 6 characters';
                        }
                        if (password.isNotEmpty && password.length < 6) {
                          return 'Use at least 6 characters';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: Text(user == null ? 'Create account' : 'Save changes'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        final userId = int.tryParse(user?['id']?.toString() ?? '') ?? 0;
        if (user == null) {
          await _database.createManagedUser(
            fullName: fullNameController.text,
            username: usernameController.text,
            password: passwordController.text,
            role: selectedRole,
          );
        } else {
          await _database.updateManagedUser(
            userId: userId,
            currentUserId: _currentUserId,
            fullName: fullNameController.text,
            username: usernameController.text,
            password: passwordController.text,
            role: selectedRole,
          );
        }
        await _loadUsers();
        if (mounted) {
          _showMessage(
            user == null ? 'User account created.' : 'User updated.',
          );
        }
      } on UsernameAlreadyExistsException {
        _showMessage('That username is already in use.', isError: true);
      } on UserManagementException catch (error) {
        _showMessage(error.message, isError: true);
      } catch (error) {
        _showMessage('Unable to save user account: $error', isError: true);
      }
    }

    fullNameController.dispose();
    usernameController.dispose();
    passwordController.dispose();
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    if (!UserPermissions.canManageUsers(widget.currentUser['role'])) return;
    final userId = int.tryParse(user['id']?.toString() ?? '') ?? 0;
    final name = user['full_name']?.toString() ?? 'this user';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user account?'),
        content: Text('Delete the account for $name? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _database.deleteManagedUser(
        userId: userId,
        currentUserId: _currentUserId,
      );
      await _loadUsers();
      if (mounted) _showMessage('User account deleted.');
    } on UserManagementException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      _showMessage('Unable to delete user account: $error', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
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
    if (!UserPermissions.canManageUsers(widget.currentUser['role'])) {
      return Scaffold(
        appBar: AppBar(title: const Text('User management')),
        body: const Center(
          child: Text('Only an Administrator can manage user accounts.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('User management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadUsers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openUserForm(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add user'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? const Center(child: Text('No user accounts found.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final user = _users[index];
                final userId = int.tryParse(user['id']?.toString() ?? '') ?? 0;
                final isCurrentUser = userId == _currentUserId;
                final role = UserPermissions.normalizeRole(user['role']);
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        role == UserPermissions.administrator
                            ? Icons.admin_panel_settings_outlined
                            : role == UserPermissions.supervisor
                            ? Icons.supervisor_account_outlined
                            : Icons.inventory_2_outlined,
                      ),
                    ),
                    title: Text(user['full_name']?.toString() ?? ''),
                    subtitle: Text(
                      '@${user['username']} · $role'
                      '${isCurrentUser ? ' · You' : ''}',
                    ),
                    trailing: isCurrentUser
                        ? const Tooltip(
                            message:
                                'Manage your own account from your profile',
                            child: Icon(Icons.lock_outline),
                          )
                        : PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'edit') {
                                _openUserForm(user: user);
                              } else {
                                _deleteUser(user);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
    );
  }
}
