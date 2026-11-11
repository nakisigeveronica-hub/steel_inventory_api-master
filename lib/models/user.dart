class User {
  final int id;
  final String username;
  final String fullName;
  final String email;
  final String? role;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const User({
    required this.id,
    required this.username,
    this.fullName = '',
    this.email = '',
    this.role,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: int.tryParse(
            json['id']?.toString() ?? '0',
          ) ??
          0,
      username: json['username']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString(),
      isActive: _parseBool(
        json['is_active'] ?? json['active'] ?? true,
      ),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'email': email,
      'role': role,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    final stringValue = value.toString().toLowerCase();

    return stringValue == '1' ||
        stringValue == 'true' ||
        stringValue == 'active';
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}


