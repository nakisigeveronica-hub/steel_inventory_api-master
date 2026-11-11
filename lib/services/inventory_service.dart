import 'package:url_launcher/url_launcher.dart';

import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../models/transaction.dart';

class InventoryService {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<List<Product>> getProducts() async {
    final db = await _databaseHelper.database;
    final result = await db.query('products', orderBy: 'id DESC');
    return result.map((item) => Product.fromJson(item)).toList();
  }

  Future<Product?> getProductById(int productId) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return Product.fromJson(result.first);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty) return null;

    final db = await _databaseHelper.database;
    final result = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [normalizedBarcode],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return Product.fromJson(result.first);
  }

  Future<List<Product>> getProductsByType(String itemType) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'products',
      where: 'item_type = ?',
      whereArgs: [itemType],
      orderBy: 'name ASC',
    );
    return result.map((item) => Product.fromJson(item)).toList();
  }

  Future<List<Product>> searchProducts(String keyword) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'products',
      where: 'name LIKE ? OR barcode = ?',
      whereArgs: ['%$keyword%', keyword.trim()],
      orderBy: 'name ASC',
    );
    return result.map((item) => Product.fromJson(item)).toList();
  }

  Future<bool> addProduct(Product product) async {
    final db = await _databaseHelper.database;
    final rowId = await db.insert('products', {
      'category_id': product.categoryId,
      'name': product.name,
      'description': product.description,
      'unit': product.unit,
      'quantity': product.quantity,
      'minimum_stock': product.minimumStock,
      'item_type': product.itemType,
      'barcode': _normalizedBarcode(product.barcode),
    });
    return rowId > 0;
  }

  Future<bool> updateProduct(Product product) async {
    final db = await _databaseHelper.database;
    final rowsUpdated = await db.update(
      'products',
      {
        'category_id': product.categoryId,
        'name': product.name,
        'description': product.description,
        'unit': product.unit,
        'quantity': product.quantity,
        'minimum_stock': product.minimumStock,
        'item_type': product.itemType,
        'barcode': _normalizedBarcode(product.barcode),
      },
      where: 'id = ?',
      whereArgs: [product.id],
    );
    return rowsUpdated > 0;
  }

  String? _normalizedBarcode(String? barcode) {
    final normalizedBarcode = barcode?.trim();
    return normalizedBarcode == null || normalizedBarcode.isEmpty
        ? null
        : normalizedBarcode;
  }

  Future<int> deleteProduct(int id) async {
    final db = await _databaseHelper.database;
    return db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Supplier>> getSuppliers() async {
    final db = await _databaseHelper.database;
    final result = await db.query('suppliers', orderBy: 'name ASC');
    return result.map((item) => Supplier.fromJson(item)).toList();
  }

  Future<bool> addSupplier(Supplier supplier) async {
    final db = await _databaseHelper.database;
    final rowId = await db.insert('suppliers', {
      'name': supplier.name,
      'contact_person': supplier.contactPerson,
      'phone': supplier.phone,
      'email': supplier.email,
      'address': supplier.address,
    });
    return rowId > 0;
  }

  Future<bool> updateSupplier(Supplier supplier) async {
    final db = await _databaseHelper.database;
    final rowsUpdated = await db.update(
      'suppliers',
      {
        'name': supplier.name,
        'contact_person': supplier.contactPerson,
        'phone': supplier.phone,
        'email': supplier.email,
        'address': supplier.address,
      },
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
    return rowsUpdated > 0;
  }

  Future<int> deleteSupplier(int id) async {
    final db = await _databaseHelper.database;
    return db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Supplier>> getSuppliersForProduct(int productId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT suppliers.*
      FROM suppliers
      INNER JOIN product_suppliers
        ON suppliers.id = product_suppliers.supplier_id
      WHERE product_suppliers.product_id = ?
      ORDER BY product_suppliers.is_primary DESC, suppliers.name ASC
      ''',
      [productId],
    );
    return result.map((item) => Supplier.fromJson(item)).toList();
  }

  Future<Supplier?> getPrimarySupplier(int productId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT suppliers.*
      FROM suppliers
      INNER JOIN product_suppliers
        ON suppliers.id = product_suppliers.supplier_id
      WHERE product_suppliers.product_id = ?
        AND product_suppliers.is_primary = 1
      LIMIT 1
      ''',
      [productId],
    );

    if (result.isEmpty) return null;
    return Supplier.fromJson(result.first);
  }

  Future<int> linkSupplierToProduct({
    required int productId,
    required int supplierId,
    bool isPrimary = false,
  }) async {
    final db = await _databaseHelper.database;
    final existing = await db.query(
      'product_suppliers',
      where: 'product_id = ? AND supplier_id = ?',
      whereArgs: [productId, supplierId],
    );

    if (existing.isNotEmpty) {
      if (isPrimary) {
        await db.update(
          'product_suppliers',
          {'is_primary': 0},
          where: 'product_id = ?',
          whereArgs: [productId],
        );
      }

      return db.update(
        'product_suppliers',
        {'is_primary': isPrimary ? 1 : 0},
        where: 'product_id = ? AND supplier_id = ?',
        whereArgs: [productId, supplierId],
      );
    }

    if (isPrimary) {
      await db.update(
        'product_suppliers',
        {'is_primary': 0},
        where: 'product_id = ?',
        whereArgs: [productId],
      );
    }

    return db.insert('product_suppliers', {
      'product_id': productId,
      'supplier_id': supplierId,
      'is_primary': isPrimary ? 1 : 0,
    });
  }

  Future<int> unlinkSupplierFromProduct({
    required int productId,
    required int supplierId,
  }) async {
    final db = await _databaseHelper.database;
    return db.delete(
      'product_suppliers',
      where: 'product_id = ? AND supplier_id = ?',
      whereArgs: [productId, supplierId],
    );
  }

  Future<void> setPrimarySupplier({
    required int productId,
    required int supplierId,
  }) async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'product_suppliers',
        {'is_primary': 0},
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      await txn.update(
        'product_suppliers',
        {'is_primary': 1},
        where: 'product_id = ? AND supplier_id = ?',
        whereArgs: [productId, supplierId],
      );
    });
  }

  Future<Map<String, dynamic>?> getProductSupplier(int productId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      '''
      SELECT
        products.id AS product_id,
        products.name AS product_name,
        products.quantity,
        products.minimum_stock,
        products.unit,
        suppliers.id AS supplier_id,
        suppliers.name AS supplier_name,
        suppliers.contact_person,
        suppliers.phone,
        suppliers.email,
        suppliers.address
      FROM products
      LEFT JOIN product_suppliers
        ON products.id = product_suppliers.product_id
        AND product_suppliers.is_primary = 1
      LEFT JOIN suppliers
        ON product_suppliers.supplier_id = suppliers.id
      WHERE products.id = ?
      LIMIT 1
      ''',
      [productId],
    );

    if (result.isEmpty) return null;
    return result.first;
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await _databaseHelper.database;
    return db.query('categories', orderBy: 'name ASC');
  }

  Future<int> saveCategory({
    int? categoryId,
    required String name,
    String? description,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Category name is required.');
    }
    final db = await _databaseHelper.database;
    final values = {
      'name': normalizedName,
      'description': description?.trim() ?? '',
    };
    if (categoryId == null) {
      return db.insert('categories', values);
    }
    final changed = await db.update(
      'categories',
      values,
      where: 'id = ?',
      whereArgs: [categoryId],
    );
    if (changed == 0) {
      throw StateError('Category no longer exists.');
    }
    return categoryId;
  }

  Future<void> deleteCategory(int categoryId) async {
    final db = await _databaseHelper.database;
    await db.transaction((txn) async {
      final products = await txn.query(
        'products',
        columns: ['id'],
        where: 'category_id = ?',
        whereArgs: [categoryId],
        limit: 1,
      );
      if (products.isNotEmpty) {
        throw StateError(
          'This category is assigned to products and cannot be deleted.',
        );
      }
      final deleted = await txn.delete(
        'categories',
        where: 'id = ?',
        whereArgs: [categoryId],
      );
      if (deleted == 0) {
        throw StateError('Category no longer exists.');
      }
    });
  }

  Future<bool> stockIn({
    required int productId,
    int? supplierId,
    int? userId,
    required double quantity,
    required String purpose,
    String? notes,
  }) async {
    final db = await _databaseHelper.database;

    try {
      if (quantity <= 0) return false;

      await db.transaction((txn) async {
        final products = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [productId],
        );

        if (products.isEmpty) {
          throw Exception('Product not found');
        }

        final currentQuantity =
            (products.first['quantity'] as num?)?.toDouble() ?? 0;
        final newQuantity = currentQuantity + quantity;

        await txn.update(
          'products',
          {'quantity': newQuantity},
          where: 'id = ?',
          whereArgs: [productId],
        );

        await txn.insert('transactions', {
          'product_id': productId,
          'supplier_id': supplierId,
          'user_id': userId,
          'transaction_type': 'Stock In',
          'quantity': quantity,
          'purpose': purpose,
          'notes': notes ?? '',
          'transaction_date': DateTime.now().toIso8601String(),
        });

        if (supplierId != null) {
          final supplierLink = await txn.query(
            'product_suppliers',
            where: 'product_id = ? AND supplier_id = ?',
            whereArgs: [productId, supplierId],
          );

          if (supplierLink.isEmpty) {
            await txn.insert('product_suppliers', {
              'product_id': productId,
              'supplier_id': supplierId,
              'is_primary': 0,
            });
          }
        }
      });

      await checkStockLevel(productId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stockOut({
    required int productId,
    int? userId,
    required double quantity,
    required String purpose,
    String? notes,
  }) async {
    final db = await _databaseHelper.database;

    try {
      if (quantity <= 0) return false;

      await db.transaction((txn) async {
        final products = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [productId],
        );

        if (products.isEmpty) {
          throw Exception('Product not found');
        }

        final currentQuantity =
            (products.first['quantity'] as num?)?.toDouble() ?? 0;

        if (quantity > currentQuantity) {
          throw Exception('Insufficient stock available');
        }

        final newQuantity = currentQuantity - quantity;

        await txn.update(
          'products',
          {'quantity': newQuantity},
          where: 'id = ?',
          whereArgs: [productId],
        );

        await txn.insert('transactions', {
          'product_id': productId,
          'user_id': userId,
          'transaction_type': 'Stock Out',
          'quantity': quantity,
          'purpose': purpose,
          'notes': notes ?? '',
          'transaction_date': DateTime.now().toIso8601String(),
        });
      });

      await checkStockLevel(productId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<InventoryTransaction>> getTransactions() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT
        transactions.id,
        transactions.product_id,
        transactions.supplier_id,
        transactions.user_id,
        transactions.transaction_type,
        transactions.quantity,
        transactions.purpose,
        transactions.notes,
        transactions.transaction_date,
        products.name AS product_name,
        products.unit AS unit,
        suppliers.name AS supplier_name,
        users.full_name AS user_name,
        users.username AS username
      FROM transactions
      LEFT JOIN products ON transactions.product_id = products.id
      LEFT JOIN suppliers ON transactions.supplier_id = suppliers.id
      LEFT JOIN users ON transactions.user_id = users.id
      ORDER BY transactions.transaction_date DESC
      ''');

    return result.map((item) => InventoryTransaction.fromJson(item)).toList();
  }

  Future<List<Product>> getLowStockProducts() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT *
      FROM products
      WHERE minimum_stock > 0
        AND quantity <= minimum_stock
      ORDER BY quantity ASC
      ''');
    return result.map((item) => Product.fromJson(item)).toList();
  }

  Future<List<Product>> getCriticalStockProducts() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT *
      FROM products
      WHERE minimum_stock > 0
        AND quantity <= (minimum_stock * 0.5)
      ORDER BY quantity ASC
      ''');
    return result.map((item) => Product.fromJson(item)).toList();
  }

  Future<void> checkStockLevel(int productId) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
    );

    if (result.isEmpty) return;

    final product = result.first;
    final quantity = (product['quantity'] as num?)?.toDouble() ?? 0;
    final minimumStock = (product['minimum_stock'] as num?)?.toDouble() ?? 0;
    final productName = product['name']?.toString() ?? 'Product';

    String? status;
    String? title;
    String? message;

    if (minimumStock > 0 && quantity <= minimumStock * 0.5) {
      status = 'Critical';
      title = 'Critical Stock Alert';
      message =
          '$productName is critically low. Current quantity: ${_formatQuantity(quantity)}. Minimum required: ${_formatQuantity(minimumStock)}.';
    } else if (minimumStock > 0 && quantity <= minimumStock) {
      status = 'Low';
      title = 'Low Stock Alert';
      message =
          '$productName is running low. Current quantity: ${_formatQuantity(quantity)}. Minimum required: ${_formatQuantity(minimumStock)}.';
    }

    if (status != null) {
      await _createNotification(
        productId: productId,
        title: title!,
        message: message!,
        notificationType: status,
      );
    }
  }

  Future<void> _createNotification({
    required int productId,
    required String title,
    required String message,
    required String notificationType,
  }) async {
    final db = await _databaseHelper.database;
    final existing = await db.query(
      'notifications',
      where: 'product_id = ? AND notification_type = ? AND is_read = 0',
      whereArgs: [productId, notificationType],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert('notifications', {
        'title': title,
        'message': message,
        'notification_type': notificationType,
        'product_id': productId,
        'is_read': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final db = await _databaseHelper.database;
    return db.query('notifications', orderBy: 'created_at DESC');
  }

  Future<void> markNotificationAsRead(int id) async {
    final db = await _databaseHelper.database;
    await db.update(
      'notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteNotification(int id) async {
    final db = await _databaseHelper.database;
    await db.delete('notifications', where: 'id = ?', whereArgs: [id]);
  }

  double getRecommendedRestockQuantity(Product product) {
    if (product.minimumStock <= 0) {
      return 0;
    }

    final targetStock = product.minimumStock * 2;
    final recommended = targetStock - product.quantity;
    return recommended > 0 ? recommended : 0;
  }

  Future<Map<String, dynamic>?> getRestockInformation(int productId) async {
    final data = await getProductSupplier(productId);
    if (data == null) return null;

    final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
    final minimumStock = (data['minimum_stock'] as num?)?.toDouble() ?? 0;
    final targetStock = minimumStock > 0 ? minimumStock * 2 : quantity;
    final recommendedQuantity = targetStock - quantity;

    return {
      ...data,
      'target_stock': targetStock,
      'recommended_quantity': recommendedQuantity > 0 ? recommendedQuantity : 0,
      'is_low_stock': minimumStock > 0 && quantity <= minimumStock,
      'is_critical': minimumStock > 0 && quantity <= minimumStock * 0.5,
    };
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  String _normalizeUgandaPhone(String phone) {
    var cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleanPhone.startsWith('+256')) {
      cleanPhone = cleanPhone.substring(1);
    } else if (cleanPhone.startsWith('0')) {
      cleanPhone = '256${cleanPhone.substring(1)}';
    }

    return cleanPhone.replaceAll(RegExp(r'[^\d]'), '');
  }

  Future<bool> sendRestockOrder(int productId) async {
    try {
      final data = await getProductSupplier(productId);
      if (data == null) return false;

      final supplierPhone = data['phone']?.toString() ?? '';
      final supplierName = data['supplier_name']?.toString() ?? '';
      final productName = data['product_name']?.toString() ?? '';
      final unit = data['unit']?.toString() ?? '';
      final quantity = (data['quantity'] as num?)?.toDouble() ?? 0;
      final minimumStock = (data['minimum_stock'] as num?)?.toDouble() ?? 0;

      if (supplierPhone.trim().isEmpty ||
          supplierName.trim().isEmpty ||
          productName.trim().isEmpty) {
        return false;
      }

      final targetStock = minimumStock * 2;
      final recommendedQuantity = targetStock - quantity;
      if (recommendedQuantity <= 0) return false;

      final cleanPhone = _normalizeUgandaPhone(supplierPhone);
      if (cleanPhone.isEmpty) return false;

      final messageBuffer = StringBuffer();
      messageBuffer.writeln('Hello $supplierName,');
      messageBuffer.writeln();
      messageBuffer.writeln(
        'We would like to place a restock order for the following item:',
      );
      messageBuffer.writeln();
      messageBuffer.writeln('Product: $productName');
      messageBuffer.writeln(
        'Current Stock: ${_formatQuantity(quantity)} $unit',
      );
      messageBuffer.writeln(
        'Minimum Stock: ${_formatQuantity(minimumStock)} $unit',
      );
      messageBuffer.writeln(
        'Recommended Order: ${_formatQuantity(recommendedQuantity)} $unit',
      );
      messageBuffer.writeln();
      messageBuffer.writeln(
        'Please confirm availability and expected delivery time.',
      );
      messageBuffer.writeln();
      messageBuffer.writeln('Thank you.');

      final encodedMessage = Uri.encodeComponent(messageBuffer.toString());
      final whatsappUri = Uri.parse(
        'https://wa.me/$cleanPhone?text=$encodedMessage',
      );
      return await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendCustomSupplierOrder({
    required int productId,
    required double quantity,
    String notes = '',
  }) async {
    try {
      if (quantity <= 0) return false;

      final product = await getProductById(productId);
      if (product == null) return false;

      final supplier = await getPrimarySupplier(productId);
      if (supplier == null) return false;
      if (supplier.phone.trim().isEmpty) return false;

      final cleanPhone = _normalizeUgandaPhone(supplier.phone);
      if (cleanPhone.isEmpty) return false;

      final messageBuffer = StringBuffer();
      messageBuffer.writeln('Hello ${supplier.name},');
      messageBuffer.writeln();
      messageBuffer.writeln(
        'We would like to place a restock order for the following item:',
      );
      messageBuffer.writeln();
      messageBuffer.writeln('Product: ${product.name}');
      messageBuffer.writeln('Item Type: ${product.itemType}');
      messageBuffer.writeln(
        'Current Stock: ${_formatQuantity(product.quantity)} ${product.unit}',
      );
      messageBuffer.writeln(
        'Minimum Stock: ${_formatQuantity(product.minimumStock)} ${product.unit}',
      );
      messageBuffer.writeln(
        'Order Quantity: ${_formatQuantity(quantity)} ${product.unit}',
      );
      if (notes.trim().isNotEmpty) {
        messageBuffer.writeln('Notes: ${notes.trim()}');
      }
      messageBuffer.writeln();
      messageBuffer.writeln(
        'Please confirm availability and expected delivery time.',
      );
      messageBuffer.writeln();
      messageBuffer.writeln('Thank you.');

      final encodedMessage = Uri.encodeComponent(messageBuffer.toString());
      final whatsappUri = Uri.parse(
        'https://wa.me/$cleanPhone?text=$encodedMessage',
      );
      return await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getDashboardStatistics() async {
    final db = await _databaseHelper.database;
    final totalProducts = SqfliteCountHelper.getCount(
      await db.rawQuery('SELECT COUNT(*) AS count FROM products'),
    );
    final totalSuppliers = SqfliteCountHelper.getCount(
      await db.rawQuery('SELECT COUNT(*) AS count FROM suppliers'),
    );
    final totalRawMaterials = SqfliteCountHelper.getCount(
      await db.rawQuery(
        'SELECT COUNT(*) AS count FROM products WHERE LOWER(TRIM(REPLACE(item_type, "_", " "))) = ?',
        ['raw material'],
      ),
    );
    final lowStockItems = SqfliteCountHelper.getCount(
      await db.rawQuery(
        'SELECT COUNT(*) AS count FROM products WHERE minimum_stock > 0 AND quantity <= minimum_stock',
      ),
    );
    final criticalStockItems = SqfliteCountHelper.getCount(
      await db.rawQuery(
        'SELECT COUNT(*) AS count FROM products WHERE minimum_stock > 0 AND quantity <= (minimum_stock * 0.5)',
      ),
    );

    return {
      'total_products': totalProducts,
      'total_suppliers': totalSuppliers,
      'total_raw_materials': totalRawMaterials,
      'low_stock_items': lowStockItems,
      'critical_stock_items': criticalStockItems,
    };
  }

  Future<bool> updateUserProfile({
    required int userId,
    required String fullName,
  }) async {
    if (userId <= 0 || fullName.trim().isEmpty) return false;

    try {
      final db = await _databaseHelper.database;
      final result = await db.update(
        'users',
        {'full_name': fullName.trim()},
        where: 'id = ?',
        whereArgs: [userId],
      );
      return result > 0;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getUserById(int userId) async {
    if (userId <= 0) return null;

    try {
      final db = await _databaseHelper.database;
      final result = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (result.isEmpty) return null;
      return Map<String, dynamic>.from(result.first);
    } catch (_) {
      return null;
    }
  }

  Future<bool> verifyUserPassword({
    required int userId,
    required String password,
  }) async {
    if (userId <= 0 || password.isEmpty) return false;

    try {
      final db = await _databaseHelper.database;
      final result = await db.query(
        'users',
        columns: ['password'],
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (result.isEmpty) return false;
      final storedPassword = result.first['password']?.toString() ?? '';
      return DatabaseHelper.passwordMatches(password, storedPassword);
    } catch (_) {
      return false;
    }
  }

  Future<bool> changeUserPassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (userId <= 0 || currentPassword.isEmpty || newPassword.length < 6) {
      return false;
    }

    final currentPasswordCorrect = await verifyUserPassword(
      userId: userId,
      password: currentPassword,
    );
    if (!currentPasswordCorrect) return false;

    try {
      final db = await _databaseHelper.database;
      final result = await db.update(
        'users',
        {'password': DatabaseHelper.hashPassword(newPassword)},
        where: 'id = ?',
        whereArgs: [userId],
      );
      return result > 0;
    } catch (_) {
      return false;
    }
  }
}

class SqfliteCountHelper {
  static int getCount(List<Map<String, dynamic>> result) {
    if (result.isEmpty) return 0;
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }
}
