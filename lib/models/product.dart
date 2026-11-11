class Product {
  final int id;
  final int? categoryId;
  final String name;
  final String description;
  final String unit;
  final double quantity;
  final double minimumStock;
  final String itemType;
  final String? barcode;
  final String? categoryName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Product({
    required this.id,
    this.categoryId,
    required this.name,
    this.description = '',
    required this.unit,
    this.quantity = 0,
    required this.minimumStock,
    required this.itemType,
    this.barcode,
    this.categoryName,
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      categoryId: json['category_id'] == null
          ? null
          : int.tryParse(json['category_id'].toString()),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      quantity:
          double.tryParse(
            (json['quantity'] ?? json['current_quantity'] ?? '0').toString(),
          ) ??
          0,
      minimumStock:
          double.tryParse((json['minimum_stock'] ?? '0').toString()) ?? 0,
      itemType: (json['item_type']?.toString() ?? '').trim(),
      barcode: json['barcode']?.toString(),
      categoryName:
          json['category_name']?.toString() ?? json['category']?.toString(),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'description': description,
      'unit': unit,
      'quantity': quantity,
      'minimum_stock': minimumStock,
      'item_type': itemType,
      'barcode': barcode,
      'category_name': categoryName,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  String get normalizedItemType => itemType
      .trim()
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\\s+'), ' ')
      .toLowerCase();

  bool get isLowStock => minimumStock > 0 && quantity <= minimumStock;

  bool get isCriticalStock =>
      minimumStock > 0 && quantity <= minimumStock * 0.5;

  bool get isRawMaterial => normalizedItemType == 'raw material';

  bool get isFinishedProduct => normalizedItemType == 'finished product';

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}
