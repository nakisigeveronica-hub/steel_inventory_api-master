import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../services/user_permissions.dart';

class UsernameAlreadyExistsException implements Exception {}

class SetupAlreadyCompletedException implements Exception {}

class UserManagementException implements Exception {
  final String message;

  const UserManagementException(this.message);

  @override
  String toString() => message;
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  static String hashRecoveryCode(String code) {
    final normalizedCode = code.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    return hashPassword(normalizedCode);
  }

  static bool passwordMatches(String password, String storedPassword) {
    final normalizedStoredPassword = storedPassword.trim();
    return normalizedStoredPassword == hashPassword(password) ||
        normalizedStoredPassword == password;
  }

  static Database? _database;
  static Future<Database>? _databaseOpening;

  DatabaseHelper._init();

  // ============================================================
  // DATABASE INITIALIZATION
  // ============================================================

  Future<Database> get database async {
    if (_database != null) return _database!;

    final opening = _databaseOpening;
    if (opening != null) return opening;

    final newOpening = _initDB('steel_inventory.db');
    _databaseOpening = newOpening;
    try {
      final database = await newOpening;
      _database = database;
      return database;
    } catch (_) {
      _databaseOpening = null;
      rethrow;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();

    final path = join(dbPath, filePath);

    return openDatabase(
      path,
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE products ADD COLUMN barcode TEXT');
          await db.execute(
            'CREATE UNIQUE INDEX index_products_barcode '
            'ON products(barcode)',
          );
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE admin_recovery (
              id INTEGER PRIMARY KEY CHECK(id = 1),
              recovery_code_hash TEXT NOT NULL,
              updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
          ''');
        }
      },
    );
  }

  // ============================================================
  // CREATE DATABASE TABLES
  // ============================================================

  Future<void> _createDB(Database db, int version) async {
    // ==========================================================
    // USERS TABLE
    // ==========================================================

    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'Staff',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE admin_recovery (
        id INTEGER PRIMARY KEY CHECK(id = 1),
        recovery_code_hash TEXT NOT NULL,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // ==========================================================
    // CATEGORIES TABLE
    // ==========================================================

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // ==========================================================
    // SUPPLIERS TABLE
    // ==========================================================

    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contact_person TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // ==========================================================
    // PRODUCTS TABLE
    // ==========================================================

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        unit TEXT NOT NULL,
        quantity REAL DEFAULT 0,
        minimum_stock REAL DEFAULT 0,
        item_type TEXT NOT NULL,
        barcode TEXT UNIQUE,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        
        FOREIGN KEY (category_id)
        REFERENCES categories(id)
        ON DELETE CASCADE
      )
    ''');

    // ==========================================================
    // PRODUCT SUPPLIERS TABLE
    // ==========================================================

    await db.execute('''
      CREATE TABLE product_suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        supplier_id INTEGER NOT NULL,
        is_primary INTEGER DEFAULT 0,

        FOREIGN KEY (product_id)
        REFERENCES products(id)
        ON DELETE CASCADE,

        FOREIGN KEY (supplier_id)
        REFERENCES suppliers(id)
        ON DELETE CASCADE
      )
    ''');

    // ==========================================================
    // TRANSACTIONS TABLE
    // ==========================================================

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        supplier_id INTEGER,
        user_id INTEGER,
        transaction_type TEXT NOT NULL,
        quantity REAL NOT NULL,
        purpose TEXT,
        notes TEXT,
        transaction_date TEXT DEFAULT CURRENT_TIMESTAMP,

        FOREIGN KEY (product_id)
        REFERENCES products(id)
        ON DELETE CASCADE,

        FOREIGN KEY (supplier_id)
        REFERENCES suppliers(id)
        ON DELETE SET NULL,

        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE SET NULL
      )
    ''');

    // ==========================================================
    // NOTIFICATIONS TABLE
    // ==========================================================

    await db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        notification_type TEXT NOT NULL,
        product_id INTEGER,
        is_read INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,

        FOREIGN KEY (product_id)
        REFERENCES products(id)
        ON DELETE CASCADE
      )
    ''');

    // ==========================================================
    // CREATE DEFAULT DATA
    // ==========================================================

    await _insertDefaultData(db);
  }

  // ============================================================
  // INSERT DEFAULT DATA
  // ============================================================

  Future<void> _insertDefaultData(Database db) async {
    // The default admin account is created during onboarding so this app can
    // be initialized with a custom first-run identity.

    // Categories

    await db.insert('categories', {
      'name': 'Steel Raw Materials',
      'description': 'Raw materials used in steel manufacturing',
    });

    await db.insert('categories', {
      'name': 'Finished Steel Products',
      'description': 'Completed steel products ready for sale',
    });

    await db.insert('categories', {
      'name': 'Manufacturing Supplies',
      'description': 'Other materials used during manufacturing',
    });

    // Suppliers

    await db.insert('suppliers', {
      'name': 'Uganda Steel Suppliers Ltd',
      'contact_person': 'John Doe',
      'phone': '+256700000001',
      'email': 'info@ugandasteel.com',
      'address': 'Kampala, Uganda',
    });

    await db.insert('suppliers', {
      'name': 'Metal Works Uganda',
      'contact_person': 'Sarah Namusoke',
      'phone': '+256700000002',
      'email': 'sales@metalworks.com',
      'address': 'Namanve, Uganda',
    });

    // Sample Products

    await db.insert('products', {
      'category_id': 1,
      'name': 'Steel Sheets',
      'description': 'Raw steel sheets used in manufacturing',
      'unit': 'Pieces',
      'quantity': 100,
      'minimum_stock': 30,
      'item_type': 'Raw Material',
    });

    await db.insert('products', {
      'category_id': 1,
      'name': 'Iron Rods',
      'description': 'Iron rods used for steel production',
      'unit': 'Pieces',
      'quantity': 200,
      'minimum_stock': 50,
      'item_type': 'Raw Material',
    });

    await db.insert('products', {
      'category_id': 2,
      'name': 'Steel Bars',
      'description': 'Finished steel bars',
      'unit': 'Pieces',
      'quantity': 80,
      'minimum_stock': 25,
      'item_type': 'Finished Product',
    });

    // Product Supplier Relationships

    await db.insert('product_suppliers', {
      'product_id': 1,
      'supplier_id': 1,
      'is_primary': 1,
    });

    await db.insert('product_suppliers', {
      'product_id': 2,
      'supplier_id': 1,
      'is_primary': 1,
    });
  }

  // ============================================================
  // RESET DATABASE (FOR DEVELOPMENT ONLY)
  // ============================================================

  Future<void> deleteDatabaseFile() async {
    final database = _database;
    if (database != null) {
      await database.close();
    }

    final dbPath = await getDatabasesPath();

    final path = join(dbPath, 'steel_inventory.db');

    await deleteDatabase(path);

    _database = null;
    _databaseOpening = null;
  }

  // ============================================================
  // USER SETUP
  // ============================================================

  Future<bool> hasUsers() async {
    try {
      final db = await database;
      final result = await db.query('users', columns: ['id'], limit: 1);
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createAdminUser({
    required String companyName,
    required String fullName,
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    final normalizedFullName = fullName.trim();

    if (normalizedFullName.isEmpty ||
        normalizedUsername.isEmpty ||
        password.isEmpty) {
      return false;
    }

    final db = await database;

    return db.transaction((txn) async {
      final users = await txn.query('users', columns: ['id'], limit: 1);
      if (users.isNotEmpty) {
        throw SetupAlreadyCompletedException();
      }

      final existing = await txn.query(
        'users',
        where: 'username = ? COLLATE NOCASE',
        whereArgs: [normalizedUsername],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        throw UsernameAlreadyExistsException();
      }

      final insertId = await txn.insert('users', {
        'full_name': normalizedFullName,
        'username': normalizedUsername,
        'password': hashPassword(password),
        'role': 'Admin',
      });

      if (insertId <= 0) {
        throw StateError('Unable to insert admin user');
      }

      await txn.insert('categories', {
        'name': companyName.trim().isEmpty
            ? 'Steel Inventory'
            : companyName.trim(),
        'description': 'Default category created during onboarding',
      });

      return true;
    });
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await database;
    return db.query(
      'users',
      columns: ['id', 'full_name', 'username', 'role', 'created_at'],
      orderBy: 'full_name COLLATE NOCASE',
    );
  }

  Future<int> createManagedUser({
    required String fullName,
    required String username,
    required String password,
    required String role,
  }) async {
    final normalizedFullName = fullName.trim();
    final normalizedUsername = username.trim();
    if (normalizedFullName.isEmpty || normalizedUsername.isEmpty) {
      throw const UserManagementException('Name and username are required.');
    }
    if (password.length < 6) {
      throw const UserManagementException(
        'Password must be at least 6 characters.',
      );
    }
    if (!UserPermissions.roles.contains(role)) {
      throw const UserManagementException('Select a valid user role.');
    }

    final db = await database;
    final existing = await db.query(
      'users',
      columns: ['id'],
      where: 'username = ? COLLATE NOCASE',
      whereArgs: [normalizedUsername],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw UsernameAlreadyExistsException();
    }
    try {
      return await db.insert('users', {
        'full_name': normalizedFullName,
        'username': normalizedUsername,
        'password': hashPassword(password),
        'role': role == UserPermissions.administrator ? 'Admin' : role,
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw UsernameAlreadyExistsException();
      }
      rethrow;
    }
  }

  Future<void> updateManagedUser({
    required int userId,
    required int currentUserId,
    required String fullName,
    required String username,
    required String role,
    String? password,
  }) async {
    if (userId <= 0 || userId == currentUserId) {
      throw const UserManagementException(
        'You cannot change your own account here.',
      );
    }
    final normalizedFullName = fullName.trim();
    final normalizedUsername = username.trim();
    if (normalizedFullName.isEmpty || normalizedUsername.isEmpty) {
      throw const UserManagementException('Name and username are required.');
    }
    if (!UserPermissions.roles.contains(role)) {
      throw const UserManagementException('Select a valid user role.');
    }
    if (password != null && password.isNotEmpty && password.length < 6) {
      throw const UserManagementException(
        'Password must be at least 6 characters.',
      );
    }

    final db = await database;
    await db.transaction((txn) async {
      final users = await txn.query(
        'users',
        columns: ['role'],
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (users.isEmpty) {
        throw const UserManagementException('This account no longer exists.');
      }
      final duplicateUsername = await txn.query(
        'users',
        columns: ['id'],
        where: 'username = ? COLLATE NOCASE AND id != ?',
        whereArgs: [normalizedUsername, userId],
        limit: 1,
      );
      if (duplicateUsername.isNotEmpty) {
        throw UsernameAlreadyExistsException();
      }
      final oldRole = UserPermissions.normalizeRole(users.first['role']);
      if (oldRole == UserPermissions.administrator &&
          role != UserPermissions.administrator) {
        final allUsers = await txn.query('users', columns: ['id', 'role']);
        final adminCount = allUsers
            .where(
              (user) =>
                  UserPermissions.normalizeRole(user['role']) ==
                  UserPermissions.administrator,
            )
            .length;
        if (adminCount <= 1) {
          throw const UserManagementException(
            'The last Administrator account cannot be demoted.',
          );
        }
      }

      final values = <String, Object?>{
        'full_name': normalizedFullName,
        'username': normalizedUsername,
        'role': role == UserPermissions.administrator ? 'Admin' : role,
      };
      if (password != null && password.isNotEmpty) {
        values['password'] = hashPassword(password);
      }
      try {
        await txn.update('users', values, where: 'id = ?', whereArgs: [userId]);
      } on DatabaseException catch (error) {
        if (error.isUniqueConstraintError()) {
          throw UsernameAlreadyExistsException();
        }
        rethrow;
      }
    });
  }

  Future<void> deleteManagedUser({
    required int userId,
    required int currentUserId,
  }) async {
    if (userId <= 0 || userId == currentUserId) {
      throw const UserManagementException(
        'You cannot delete your own account.',
      );
    }

    final db = await database;
    await db.transaction((txn) async {
      final users = await txn.query(
        'users',
        columns: ['role'],
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (users.isEmpty) {
        throw const UserManagementException('This account no longer exists.');
      }
      if (UserPermissions.normalizeRole(users.first['role']) ==
          UserPermissions.administrator) {
        final allUsers = await txn.query('users', columns: ['id', 'role']);
        final adminCount = allUsers
            .where(
              (user) =>
                  UserPermissions.normalizeRole(user['role']) ==
                  UserPermissions.administrator,
            )
            .length;
        if (adminCount <= 1) {
          throw const UserManagementException(
            'The last Administrator account cannot be deleted.',
          );
        }
      }
      await txn.delete('users', where: 'id = ?', whereArgs: [userId]);
    });
  }

  Future<Map<String, dynamic>?> getUserById(int userId) async {
    if (userId <= 0) return null;
    final db = await database;
    final users = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return users.isEmpty ? null : Map<String, dynamic>.from(users.first);
  }

  Future<List<Map<String, dynamic>>> getAdministratorAccounts() async {
    final db = await database;
    final users = await db.query(
      'users',
      columns: ['id', 'full_name', 'username', 'role'],
      orderBy: 'full_name COLLATE NOCASE',
    );
    return users
        .where(
          (user) =>
              UserPermissions.normalizeRole(user['role']) ==
              UserPermissions.administrator,
        )
        .toList();
  }

  Future<bool> hasAdminRecoveryCode() async {
    final db = await database;
    final rows = await db.query(
      'admin_recovery',
      columns: ['id'],
      where: 'id = 1',
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> resetAdministratorPasswordWithDeviceAuth({
    required int userId,
    required String newPassword,
    required String newRecoveryCode,
  }) async {
    if (newPassword.length < 8) {
      throw const UserManagementException(
        'Use a password with at least 8 characters.',
      );
    }
    if (newRecoveryCode.trim().isEmpty) {
      throw const UserManagementException(
        'Unable to generate a recovery code.',
      );
    }

    final db = await database;
    await db.transaction((txn) async {
      final users = await txn.query(
        'users',
        columns: ['role'],
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (users.isEmpty ||
          UserPermissions.normalizeRole(users.first['role']) !=
              UserPermissions.administrator) {
        throw const UserManagementException(
          'Select an existing Administrator account.',
        );
      }

      final updated = await txn.update(
        'users',
        {'password': hashPassword(newPassword)},
        where: 'id = ?',
        whereArgs: [userId],
      );
      if (updated != 1) {
        throw StateError('Unable to reset Administrator password.');
      }
      await txn.insert('admin_recovery', {
        'id': 1,
        'recovery_code_hash': hashRecoveryCode(newRecoveryCode),
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> resetAdministratorPasswordWithRecoveryCode({
    required int userId,
    required String recoveryCode,
    required String newPassword,
  }) async {
    if (newPassword.length < 8) {
      throw const UserManagementException(
        'Use a password with at least 8 characters.',
      );
    }

    final db = await database;
    await db.transaction((txn) async {
      final recoveryRows = await txn.query(
        'admin_recovery',
        columns: ['recovery_code_hash'],
        where: 'id = 1',
        limit: 1,
      );
      if (recoveryRows.isEmpty) {
        throw const UserManagementException(
          'Administrator recovery has not been set up on this device.',
        );
      }

      final storedCodeHash =
          recoveryRows.first['recovery_code_hash']?.toString() ?? '';
      if (storedCodeHash != hashRecoveryCode(recoveryCode)) {
        throw const UserManagementException('The recovery code is incorrect.');
      }

      final users = await txn.query(
        'users',
        columns: ['role'],
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (users.isEmpty ||
          UserPermissions.normalizeRole(users.first['role']) !=
              UserPermissions.administrator) {
        throw const UserManagementException(
          'Select an existing Administrator account.',
        );
      }
      await txn.update(
        'users',
        {'password': hashPassword(newPassword)},
        where: 'id = ?',
        whereArgs: [userId],
      );
    });
  }

  // ============================================================
  // CLOSE DATABASE
  // ============================================================

  Future<void> close() async {
    final db = await instance.database;

    await db.close();

    _database = null;
    _databaseOpening = null;
  }
}
