import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:steel_inventory_api/database/database_helper.dart';
import 'package:steel_inventory_api/models/product.dart';
import 'package:steel_inventory_api/screens/onboarding_screen.dart';
import 'package:steel_inventory_api/screens/dashboard_screen.dart';
import 'package:steel_inventory_api/screens/login_screen.dart';
import 'package:steel_inventory_api/services/auth_session.dart';
import 'package:steel_inventory_api/services/user_permissions.dart';
import 'package:steel_inventory_api/widgets/dashboard_assistant_card.dart';
import 'package:steel_inventory_api/widgets/dashboard_critical_stock_card.dart';
import 'package:steel_inventory_api/widgets/dashboard_performance_chart.dart';
import 'package:steel_inventory_api/widgets/dashboard_welcome_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('onboarding screen renders setup form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('onboarding username starts blank', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    final usernameField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(2),
    );

    expect(usernameField.controller?.text, isEmpty);
  });

  testWidgets('login screen offers the assigned role choices', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Choose your role'), findsOneWidget);
    expect(
      find.widgetWithText(ChoiceChip, 'Inventory/Store Personnel'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ChoiceChip, 'Supervisor'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Administrator'), findsOneWidget);
    expect(find.text('Forgot Administrator password?'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Supervisor'));
    await tester.pump();
    expect(find.text('Sign in as Supervisor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('passwords are hashed before storage', () {
    const rawPassword = 'admin123';

    final hash = DatabaseHelper.hashPassword(rawPassword);
    final secondHash = DatabaseHelper.hashPassword(rawPassword);

    expect(hash, isNotEmpty);
    expect(hash, isNot(equals(rawPassword)));
    expect(hash, equals(secondHash));
    expect(DatabaseHelper.passwordMatches(rawPassword, hash), isTrue);
    expect(DatabaseHelper.passwordMatches('wrong-password', hash), isFalse);
  });

  test('recovery codes ignore letter case and separators', () {
    expect(
      DatabaseHelper.hashRecoveryCode('abcd-2345-efgh-6789'),
      DatabaseHelper.hashRecoveryCode('ABCD 2345 EFGH 6789'),
    );
    expect(
      DatabaseHelper.hashRecoveryCode('ABCD-2345'),
      isNot(DatabaseHelper.hashRecoveryCode('ABCD-2346')),
    );
  });

  test('roles map to the requested inventory permissions', () {
    expect(
      UserPermissions.normalizeRole('Admin'),
      UserPermissions.administrator,
    );
    expect(
      UserPermissions.normalizeRole('Staff'),
      UserPermissions.inventoryPersonnel,
    );
    expect(
      UserPermissions.canManageProducts(UserPermissions.inventoryPersonnel),
      isTrue,
    );
    expect(
      UserPermissions.canManageSuppliers(UserPermissions.inventoryPersonnel),
      isFalse,
    );
    expect(
      UserPermissions.canManageUsers(UserPermissions.inventoryPersonnel),
      isFalse,
    );
    expect(
      UserPermissions.canManageProducts(UserPermissions.supervisor),
      isFalse,
    );
    expect(UserPermissions.canRecordStock(UserPermissions.supervisor), isFalse);
    expect(
      UserPermissions.canGenerateReports(UserPermissions.supervisor),
      isTrue,
    );
    expect(UserPermissions.canManageUsers(UserPermissions.supervisor), isFalse);
    expect(
      UserPermissions.canManageUsers(UserPermissions.administrator),
      isTrue,
    );
    expect(
      UserPermissions.canManageSuppliers(UserPermissions.administrator),
      isTrue,
    );
    expect(
      UserPermissions.canRecordStock(UserPermissions.administrator),
      isTrue,
    );
  });

  test('each role resolves to its own dashboard widget', () {
    final usersByRole = {
      UserPermissions.inventoryPersonnel: InventoryPersonnelDashboard,
      UserPermissions.supervisor: SupervisorDashboard,
      UserPermissions.administrator: AdministratorDashboard,
    };

    for (final entry in usersByRole.entries) {
      final dashboard = RoleDashboard.forUser(
        user: {'id': 1, 'full_name': 'Test User', 'role': entry.key},
      );
      expect(dashboard.runtimeType, entry.value);
    }
  });

  test('auth session saves and clears user state', () async {
    final user = {
      'id': 7,
      'full_name': 'John Admin',
      'username': 'admin',
      'role': 'Admin',
    };

    await AuthSession.clearSession();
    await AuthSession.saveCurrentUser(user);

    final savedUser = await AuthSession.getCurrentUser();
    expect(savedUser, isNotNull);
    expect(savedUser!['id'], equals(7));
    expect(savedUser['username'], equals('admin'));

    await AuthSession.clearSession();
    expect(await AuthSession.getCurrentUser(), isNull);
  });

  test('products with zero minimum stock are not treated as low stock', () {
    final normalProduct = Product(
      id: 1,
      name: 'Steel Rod',
      unit: 'kg',
      quantity: 10,
      minimumStock: 0,
      itemType: 'Raw Material',
    );

    final lowStockProduct = Product(
      id: 2,
      name: 'Steel Plate',
      unit: 'kg',
      quantity: 5,
      minimumStock: 10,
      itemType: 'Raw Material',
    );

    expect(normalProduct.isLowStock, isFalse);
    expect(normalProduct.isCriticalStock, isFalse);
    expect(lowStockProduct.isLowStock, isTrue);
    expect(lowStockProduct.isCriticalStock, isTrue);
  });

  testWidgets('dashboard widgets render with valid values', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              DashboardWelcomeCard(fullName: 'Alex Morgan', role: 'Admin'),
              DashboardAssistantCard(
                lowStockItems: 2,
                criticalStockItems: 1,
                onTap: () {},
              ),
              DashboardPerformanceChart(
                totalProducts: 12,
                totalRawMaterials: 8,
                totalSuppliers: 3,
                lowStockItems: 2,
              ),
              DashboardCriticalStockCard(criticalStockItems: 1, onTap: () {}),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Welcome back,'), findsOneWidget);
    expect(find.text('Inventory Assistant'), findsOneWidget);
    expect(find.text('Performance Overview'), findsOneWidget);
    expect(find.text('Critical Stock Alert'), findsOneWidget);
  });
}
