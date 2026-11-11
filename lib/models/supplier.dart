class Supplier {
  final int id;
  final String name;
  final String contactPerson;
  final String phone;
  final String email;
  final String address;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Supplier({
    required this.id,
    required this.name,
    this.contactPerson = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.createdAt,
    this.updatedAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      contactPerson: json['contact_person']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contact_person': contactPerson,
      'phone': phone,
      'email': email,
      'address': address,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}


