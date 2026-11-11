import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../services/inventory_service.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final InventoryService inventoryService = InventoryService();

  static const Color primaryGreen = Color(0xFF379805);

  static const Color backgroundColor = Color(0xFFF5F7FA);

  Map<String, dynamic> currentUser = {};

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();

    currentUser = Map<String, dynamic>.from(widget.user);

    _loadUser();
  }

  // ============================================================
  // LOAD USER
  // ============================================================

  Future<void> _loadUser() async {
    final userId = int.tryParse(currentUser['id']?.toString() ?? '') ?? 0;

    if (userId <= 0) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
      return;
    }

    try {
      final user = await inventoryService.getUserById(userId);

      if (!mounted) return;

      if (user != null) {
        setState(() {
          currentUser = user;
          loading = false;
        });
      } else {
        setState(() {
          loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      _showMessage('Unable to load profile information.', isError: true);
    }
  }

  // ============================================================
  // USER ID
  // ============================================================

  int get userId {
    return int.tryParse(currentUser['id']?.toString() ?? '') ?? 0;
  }

  // ============================================================
  // USER INFORMATION
  // ============================================================

  String get fullName {
    return currentUser['full_name']?.toString().trim().isNotEmpty == true
        ? currentUser['full_name'].toString()
        : 'User';
  }

  String get username {
    return currentUser['username']?.toString().trim() ?? '';
  }

  String get role {
    return currentUser['role']?.toString().trim().isNotEmpty == true
        ? currentUser['role'].toString()
        : 'Staff';
  }

  String get createdAt {
    final value = currentUser['created_at']?.toString();

    if (value == null || value.trim().isEmpty) {
      return 'Not available';
    }

    try {
      final date = DateTime.parse(value);

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return value;
    }
  }

  // ============================================================
  // INITIALS
  // ============================================================

  String get initials {
    final names = fullName
        .trim()
        .split(' ')
        .where((name) => name.isNotEmpty)
        .toList();

    if (names.isEmpty) {
      return 'U';
    }

    if (names.length == 1) {
      return names.first[0].toUpperCase();
    }

    return '${names.first[0]}'
            '${names.last[0]}'
        .toUpperCase();
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
          backgroundColor: isError ? Colors.red : null,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ============================================================
  // EDIT PROFILE
  // ============================================================

  Future<void> _editProfile() async {
    final controller = TextEditingController(text: fullName);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Edit Profile',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Full Name',
              hintText: 'Enter your full name',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final name = controller.text.trim();

                if (name.isEmpty) {
                  _showMessage('Please enter your full name.', isError: true);
                  return;
                }

                Navigator.pop(dialogContext, name);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null || result.trim().isEmpty) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final success = await inventoryService.updateUserProfile(
        userId: userId,
        fullName: result.trim(),
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          currentUser = {...currentUser, 'full_name': result.trim()};
          saving = false;
        });

        _showMessage('Profile updated successfully.');
      } else {
        setState(() {
          saving = false;
        });

        _showMessage('Unable to update profile.', isError: true);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        saving = false;
      });

      _showMessage(
        'An error occurred while updating your profile.',
        isError: true,
      );
    }
  }

  // ============================================================
  // CHANGE PASSWORD
  // ============================================================

  Future<void> _changePassword() async {
    final currentController = TextEditingController();

    final newController = TextEditingController();

    final confirmController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text(
                'Change Password',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureCurrent
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureCurrent = !obscureCurrent;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: newController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: const Icon(Icons.lock_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureNew = !obscureNew;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: confirmController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon: const Icon(Icons.lock_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureConfirm = !obscureConfirm;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Password must be at least 6 characters.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final current = currentController.text.trim();

                    final newPassword = newController.text.trim();

                    final confirm = confirmController.text.trim();

                    if (current.isEmpty ||
                        newPassword.isEmpty ||
                        confirm.isEmpty) {
                      _showMessage(
                        'Please fill in all password fields.',
                        isError: true,
                      );
                      return;
                    }

                    if (newPassword.length < 6) {
                      _showMessage(
                        'Password must be at least 6 characters.',
                        isError: true,
                      );
                      return;
                    }

                    if (newPassword != confirm) {
                      _showMessage(
                        'New passwords do not match.',
                        isError: true,
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, true);

                    final success = await inventoryService.changeUserPassword(
                      userId: userId,
                      currentPassword: current,
                      newPassword: newPassword,
                    );

                    if (!mounted) return;

                    if (success) {
                      _showMessage('Password changed successfully.');
                    } else {
                      _showMessage(
                        'Current password is incorrect.',
                        isError: true,
                      );
                    }
                  },
                  child: const Text('Change Password'),
                ),
              ],
            );
          },
        );
      },
    );

    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          icon: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: Colors.red,
              size: 28,
            ),
          ),
          title: const Text(
            'Logout',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await AuthSession.clearSession();

                // Return to the first
                // route, normally Login.
                if (!mounted) return;
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (saving)
            const Padding(
              padding: EdgeInsets.only(right: 18),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryGreen,
                  ),
                ),
              ),
            ),
        ],
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : RefreshIndicator(
              color: primaryGreen,
              onRefresh: _loadUser,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                children: [
                  // PROFILE HEADER
                  _buildProfileHeader(),

                  const SizedBox(height: 24),

                  // ACCOUNT
                  _sectionTitle('Account'),

                  const SizedBox(height: 10),

                  _profileMenuItem(
                    icon: Icons.edit_rounded,
                    iconColor: primaryGreen,
                    title: 'Edit Profile',
                    subtitle: 'Update your full name',
                    onTap: _editProfile,
                  ),

                  _profileMenuItem(
                    icon: Icons.lock_outline_rounded,
                    iconColor: Colors.blue,
                    title: 'Change Password',
                    subtitle: 'Update your account password',
                    onTap: _changePassword,
                  ),

                  const SizedBox(height: 22),

                  // ACCOUNT INFORMATION
                  _sectionTitle('Account Information'),

                  const SizedBox(height: 10),

                  _informationCard(),

                  const SizedBox(height: 22),

                  // APPLICATION
                  _sectionTitle('Application'),

                  const SizedBox(height: 10),

                  _profileMenuItem(
                    icon: Icons.inventory_2_rounded,
                    iconColor: primaryGreen,
                    title: 'Steel Inventory',
                    subtitle: 'Inventory Management System',
                    onTap: () {
                      _showMessage('Steel Inventory Management System');
                    },
                  ),

                  _profileMenuItem(
                    icon: Icons.storage_rounded,
                    iconColor: Colors.deepPurple,
                    title: 'Local Storage',
                    subtitle: 'Inventory data is stored on this device',
                    onTap: () {
                      _showMessage('Your inventory data is stored locally.');
                    },
                  ),

                  _profileMenuItem(
                    icon: Icons.info_outline_rounded,
                    iconColor: Colors.blueGrey,
                    title: 'About',
                    subtitle: 'Application information',
                    onTap: _showAboutDialog,
                  ),

                  const SizedBox(height: 22),

                  // LOGOUT
                  _logoutButton(),

                  const SizedBox(height: 20),

                  Center(
                    child: Text(
                      'Steel Inventory Management System',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  Center(
                    child: Text(
                      'Version 1.0.0 • Offline',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // PROFILE HEADER
  // ============================================================

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF379805), Color(0xFF59B52B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // AVATAR
          Container(
            width: 86,
            height: 86,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: primaryGreen,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          Text(
            fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            username.isEmpty ? 'Username unavailable' : '@$username',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.badge_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  role,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: Color(0xFF111827),
      ),
    );
  }

  // ============================================================
  // INFORMATION CARD
  // ============================================================

  Widget _informationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _informationRow(
            icon: Icons.person_outline_rounded,
            title: 'Full Name',
            value: fullName,
          ),

          const Divider(height: 22),

          _informationRow(
            icon: Icons.alternate_email_rounded,
            title: 'Username',
            value: username.isEmpty ? 'Not available' : username,
          ),

          const Divider(height: 22),

          _informationRow(
            icon: Icons.badge_outlined,
            title: 'Role',
            value: role,
          ),

          const Divider(height: 22),

          _informationRow(
            icon: Icons.calendar_today_outlined,
            title: 'Account Created',
            value: createdAt,
          ),

          const Divider(height: 22),

          _informationRow(
            icon: Icons.cloud_off_rounded,
            title: 'Connection',
            value: 'Offline',
            valueColor: primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _informationRow({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: primaryGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: primaryGreen, size: 20),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PROFILE MENU ITEM
  // ============================================================

  Widget _profileMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOGOUT BUTTON
  // ============================================================

  Widget _logoutButton() {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _confirmLogout,
        icon: const Icon(Icons.logout_rounded, color: Colors.red),
        label: const Text(
          'Logout',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.red.withValues(alpha: 0.25)),
          backgroundColor: Colors.red.withValues(alpha: 0.04),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ABOUT
  // ============================================================

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          icon: Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: primaryGreen.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: primaryGreen,
              size: 32,
            ),
          ),
          title: const Text(
            'Steel Inventory',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'A smart offline inventory '
            'management application for '
            'steel manufacturing. It manages '
            'products, raw materials, suppliers, '
            'stock movements and inventory levels.',
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Close'),
              ),
            ),
          ],
        );
      },
    );
  }
}
