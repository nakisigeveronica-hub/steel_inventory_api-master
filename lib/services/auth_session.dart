import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  static const String _keyUserId = 'auth_user_id';
  static const String _keyFullName = 'auth_full_name';
  static const String _keyUsername = 'auth_username';
  static const String _keyRole = 'auth_role';

  static Future<void> saveCurrentUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = user['id']?.toString() ?? '';
    final fullName = user['full_name']?.toString() ?? '';
    final username = user['username']?.toString() ?? '';
    final role = user['role']?.toString() ?? '';

    if (userId.isEmpty) {
      await clearSession();
      return;
    }

    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyFullName, fullName);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyRole, role);
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_keyUserId) ?? '';

    if (userId.isEmpty) {
      return null;
    }

    return {
      'id': int.tryParse(userId) ?? 0,
      'full_name': prefs.getString(_keyFullName) ?? '',
      'username': prefs.getString(_keyUsername) ?? '',
      'role': prefs.getString(_keyRole) ?? 'Staff',
    };
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyFullName);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyRole);
  }
}
