class InventoryTransaction {
  final int id;
  final int productId;
  final int? supplierId;
  final int? userId;
  final String transactionType;
  final double quantity;
  final String purpose;
  final String notes;

  final String? productName;
  final String? supplierName;
  final String? userName;
  final String? username;
  final String? unit;

  final DateTime? transactionDate;
  final DateTime? createdAt;

  const InventoryTransaction({
    required this.id,
    required this.productId,
    this.supplierId,
    this.userId,
    required this.transactionType,
    required this.quantity,
    this.purpose = '',
    this.notes = '',
    this.productName,
    this.supplierName,
    this.userName,
    this.username,
    this.unit,
    this.transactionDate,
    this.createdAt,
  });

  factory InventoryTransaction.fromJson(
    Map<String, dynamic> json,
  ) {
    return InventoryTransaction(
      id: int.tryParse(
            json['id']?.toString() ?? '0',
          ) ??
          0,
      productId: int.tryParse(
            json['product_id']?.toString() ?? '0',
          ) ??
          0,
      supplierId: json['supplier_id'] == null
          ? null
          : int.tryParse(
              json['supplier_id'].toString(),
            ),
      userId: json['user_id'] == null
          ? null
          : int.tryParse(
              json['user_id'].toString(),
            ),
      transactionType: json['transaction_type']?.toString() ??
          json['type']?.toString() ??
          '',
      quantity: double.tryParse(
            json['quantity']?.toString() ?? '0',
          ) ??
          0,
      purpose: json['purpose']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      productName:
          json['product_name']?.toString() ?? json['product']?.toString(),
      supplierName: json['supplier_name']?.toString(),
      userName: json['user_name']?.toString(),
      username: json['username']?.toString(),
      unit: json['unit']?.toString(),
      transactionDate: _parseDate(
        json['transaction_date'],
      ),
      createdAt: _parseDate(
        json['created_at'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'supplier_id': supplierId,
      'user_id': userId,
      'transaction_type': transactionType,
      'quantity': quantity,
      'purpose': purpose,
      'notes': notes,
      'product_name': productName,
      'supplier_name': supplierName,
      'user_name': userName,
      'username': username,
      'unit': unit,
      'transaction_date': transactionDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  bool get isStockIn {
    final type = transactionType.toLowerCase().replaceAll('_', ' ');

    return type == 'stock in' || type == 'in';
  }

  bool get isStockOut {
    final type = transactionType.toLowerCase().replaceAll('_', ' ');

    return type == 'stock out' || type == 'out';
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}


