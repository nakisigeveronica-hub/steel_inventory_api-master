import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../services/inventory_service.dart';
import '../services/user_permissions.dart';
import '../theme.dart';

import '../widgets/dashboard_assistant_card.dart';
import '../widgets/dashboard_critical_stock_card.dart';
import '../widgets/dashboard_performance_chart.dart';
import '../widgets/dashboard_welcome_card.dart';
import '../widgets/quick_action_card.dart';

import 'inventory_assistant_screen.dart';
import 'products_screen.dart';
import 'suppliers_screen.dart';
import 'stock_in_screen.dart';
import 'stock_out_screen.dart';
import 'transactions_screen.dart';
import 'login_screen.dart';
import 'low_stock_screen.dart';
import 'category_management_screen.dart';
import 'user_management_screen.dart';

enum _DashboardKind { storePersonnel, supervisor, administrator }

abstract class RoleDashboard extends StatelessWidget {
  final Map<String, dynamic> user;

  const RoleDashboard({super.key, required this.user});

  factory RoleDashboard.forUser({
    Key? key,
    required Map<String, dynamic> user,
  }) {
    switch (UserPermissions.normalizeRole(user['role'])) {
      case UserPermissions.supervisor:
        return SupervisorDashboard(key: key, user: user);
      case UserPermissions.administrator:
        return AdministratorDashboard(key: key, user: user);
      default:
        return InventoryPersonnelDashboard(key: key, user: user);
    }
  }
}

class InventoryPersonnelDashboard extends RoleDashboard {
  const InventoryPersonnelDashboard({super.key, required super.user});

  @override
  Widget build(BuildContext context) =>
      _DashboardOverview(user: user, kind: _DashboardKind.storePersonnel);
}

class SupervisorDashboard extends RoleDashboard {
  const SupervisorDashboard({super.key, required super.user});

  @override
  Widget build(BuildContext context) =>
      _DashboardOverview(user: user, kind: _DashboardKind.supervisor);
}

class AdministratorDashboard extends RoleDashboard {
  const AdministratorDashboard({super.key, required super.user});

  @override
  Widget build(BuildContext context) =>
      _DashboardOverview(user: user, kind: _DashboardKind.administrator);
}

class _DashboardOverview extends StatefulWidget {
  final Map<String, dynamic> user;
  final _DashboardKind kind;

  const _DashboardOverview({required this.user, required this.kind});

  @override
  State<_DashboardOverview> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<_DashboardOverview> {
  final InventoryService _inventoryService = InventoryService();

  static const Color primaryGreen = Color(0xFF379805);
  Map<String, dynamic> dashboard = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  // ============================================================
  // LOAD DASHBOARD
  // ============================================================

  Future<void> loadDashboard() async {
    if (!mounted) return;

    setState(() {
      loading = true;
    });

    try {
      final data = await _inventoryService.getDashboardStatistics();

      if (!mounted) return;

      setState(() {
        dashboard = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage('Failed to load dashboard: $e', isError: true);
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    final theme = Theme.of(context);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimary,
            ),
          ),
          backgroundColor: isError
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // OPEN SCREEN
  // ============================================================

  Future<void> openScreen(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

    await loadDashboard();
  }

  // ============================================================
  // GET INTEGER VALUE
  // ============================================================

  int _getInt(String key) {
    final value = dashboard[key];

    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  // ============================================================
  // THEME BUTTON
  // ============================================================

  Widget _buildThemeButton(ThemeData theme) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeMode,
      builder: (context, mode, child) {
        final bool isLight = mode == ThemeMode.light;

        return IconButton(
          tooltip: isLight ? 'Switch to dark mode' : 'Switch to light mode',
          onPressed: () {
            AppTheme.toggleTheme();
          },
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            reverseDuration: const Duration(milliseconds: 250),
            transitionBuilder: (Widget child, Animation<double> animation) {
              final curvedAnimation = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              );

              return RotationTransition(
                turns: Tween<double>(
                  begin: 0.75,
                  end: 1.0,
                ).animate(curvedAnimation),
                child: ScaleTransition(
                  scale: curvedAnimation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
              );
            },
            child: Icon(
              isLight ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              key: ValueKey<ThemeMode>(mode),
              size: 22,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // CREATIVE STAT CARD
  // ============================================================

  Widget _buildCreativeStatCard(
    BuildContext context, {
    required String title,
    required int value,
    required IconData icon,
    required Color color,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            height: 86,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),

            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  // ==================================================
                  // ICON
                  // ==================================================
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 21),
                  ),

                  const SizedBox(width: 9),

                  // ==================================================
                  // TEXT
                  // ==================================================
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),

                        const SizedBox(height: 1),

                        Text(
                          value.toString(),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),

                        const SizedBox(height: 1),

                        Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),

                            const SizedBox(width: 5),

                            Flexible(
                              child: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ==================================================
                  // ARROW
                  // ==================================================
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: color.withValues(alpha: 0.65),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);

    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Logout',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    await AuthSession.clearSession();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> userData = widget.user;

    final String fullName =
        userData['full_name']?.toString() ??
        userData['name']?.toString() ??
        'User';

    final String role = UserPermissions.normalizeRole(userData['role']);
    final bool canRecordStock = UserPermissions.canRecordStock(role);
    final bool isAdministrator = UserPermissions.canManageUsers(role);
    final bool canGenerateReports = UserPermissions.canGenerateReports(role);

    final int totalProducts = _getInt('total_products');

    final int totalSuppliers = _getInt('total_suppliers');

    final int totalRawMaterials = _getInt('total_raw_materials');

    final int lowStockItems = _getInt('low_stock_items');

    final int criticalStockItems = _getInt('critical_stock_items');

    final theme = Theme.of(context);
    final dashboardTitle = switch (widget.kind) {
      _DashboardKind.storePersonnel => 'Store Dashboard',
      _DashboardKind.supervisor => 'Supervisor Dashboard',
      _DashboardKind.administrator => 'Admin Dashboard',
    };
    final quickActions = <Widget>[
      if (canRecordStock)
        QuickActionCard(
          title: 'Stock In',
          subtitle: 'Receive stock',
          icon: Icons.add_box_rounded,
          color: primaryGreen,
          onTap: () => openScreen(StockInScreen(user: widget.user)),
        ),
      if (canRecordStock)
        QuickActionCard(
          title: 'Stock Out',
          subtitle: 'Issue stock',
          icon: Icons.remove_circle_rounded,
          color: Colors.orange,
          onTap: () => openScreen(StockOutScreen(user: widget.user)),
        ),
      QuickActionCard(
        title: 'Products',
        subtitle: isAdministrator ? 'Manage products' : 'View stock items',
        icon: Icons.inventory_2_rounded,
        color: theme.colorScheme.primary,
        onTap: () => openScreen(ProductsScreen(user: widget.user)),
      ),
      QuickActionCard(
        title: 'Suppliers',
        subtitle: isAdministrator
            ? 'Manage suppliers'
            : 'View supplier information',
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFF168A83),
        onTap: () => openScreen(SuppliersScreen(user: widget.user)),
      ),
      QuickActionCard(
        title: 'Transactions',
        subtitle: 'Stock history',
        icon: Icons.history_rounded,
        color: Colors.blueGrey,
        onTap: () => openScreen(const TransactionsScreen()),
      ),
      QuickActionCard(
        title: 'Low Stock',
        subtitle: 'Review alerts',
        icon: Icons.warning_amber_rounded,
        color: Colors.red,
        onTap: () => openScreen(const LowStockScreen()),
      ),
      if (canGenerateReports)
        QuickActionCard(
          title: 'Inventory Report',
          subtitle: 'Generate stock reports',
          icon: Icons.summarize_outlined,
          color: Colors.deepPurple,
          onTap: () => openScreen(
            InventoryAssistantScreen(user: widget.user, initialTab: 1),
          ),
        ),
      if (isAdministrator)
        QuickActionCard(
          title: 'User Management',
          subtitle: 'Accounts and roles',
          icon: Icons.manage_accounts_outlined,
          color: Colors.teal,
          onTap: () =>
              openScreen(UserManagementScreen(currentUser: widget.user)),
        ),
      if (isAdministrator)
        QuickActionCard(
          title: 'Categories',
          subtitle: 'Manage product categories',
          icon: Icons.category_outlined,
          color: Colors.brown,
          onTap: () => openScreen(CategoryManagementScreen(user: widget.user)),
        ),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // ==========================================================
      // APP BAR
      // ==========================================================
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,

        elevation: 0,

        scrolledUnderElevation: 0,

        titleSpacing: 10,

        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 34,
                height: 34,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              dashboardTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),

        actions: [
          // Refresh
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading ? null : loadDashboard,
            icon: Icon(
              Icons.refresh_rounded,
              color: loading
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                  : theme.colorScheme.primary,
            ),
          ),

          const SizedBox(width: 6),

          // Theme
          _buildThemeButton(theme),

          const SizedBox(width: 2),

          // Logout
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: Icon(
              Icons.logout_rounded,
              color: theme.colorScheme.error.withValues(alpha: 0.85),
              size: 22,
            ),
          ),

          const SizedBox(width: 4),
        ],
      ),

      // ==========================================================
      // BODY
      // ==========================================================
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: RefreshIndicator(
          color: theme.colorScheme.primary,

          onRefresh: loadDashboard,

          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: primaryGreen),
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),

                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 20),

                  children: [
                    // =================================================
                    // WELCOME
                    // =================================================
                    DashboardWelcomeCard(fullName: fullName, role: role),

                    const SizedBox(height: 16),

                    // =================================================
                    // ASSISTANT
                    // =================================================
                    DashboardAssistantCard(
                      lowStockItems: lowStockItems,
                      criticalStockItems: criticalStockItems,
                      onTap: () {
                        openScreen(InventoryAssistantScreen(user: widget.user));
                      },
                    ),

                    const SizedBox(height: 16),

                    // =================================================
                    // INVENTORY OVERVIEW
                    // =================================================
                    _buildSectionTitle(
                      context,
                      widget.kind == _DashboardKind.administrator
                          ? 'System Overview'
                          : 'Inventory Overview',
                    ),

                    const SizedBox(height: 10),

                    // -------------------------------------------------
                    // ROW 1
                    // -------------------------------------------------
                    Row(
                      children: [
                        Expanded(
                          child: _buildCreativeStatCard(
                            context,
                            title: 'Products',
                            value: totalProducts,
                            icon: Icons.inventory_2_rounded,
                            color: theme.colorScheme.primary,
                            subtitle: 'Items',
                            onTap: () {
                              openScreen(ProductsScreen(user: widget.user));
                            },
                          ),
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: _buildCreativeStatCard(
                            context,
                            title: 'Suppliers',
                            value: totalSuppliers,
                            icon: Icons.local_shipping_rounded,
                            color: const Color(0xFF168A83),
                            subtitle: 'Partners',
                            onTap: () {
                              openScreen(SuppliersScreen(user: widget.user));
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 2),

                    // -------------------------------------------------
                    // ROW 2
                    // -------------------------------------------------
                    Row(
                      children: [
                        Expanded(
                          child: _buildCreativeStatCard(
                            context,
                            title: 'Raw Materials',
                            value: totalRawMaterials,
                            icon: Icons.factory_rounded,
                            color: theme.colorScheme.tertiary,
                            subtitle: 'Materials',
                            onTap: () {
                              openScreen(ProductsScreen(user: widget.user));
                            },
                          ),
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: _buildCreativeStatCard(
                            context,
                            title: 'Low Stock',
                            value: lowStockItems,
                            icon: Icons.warning_amber_rounded,
                            color: const Color(0xFFB66A00),
                            subtitle: 'Attention',
                            onTap: () {
                              openScreen(const LowStockScreen());
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // =================================================
                    // CRITICAL STOCK
                    // =================================================
                    DashboardCriticalStockCard(
                      criticalStockItems: criticalStockItems,
                      onTap: () {
                        openScreen(const LowStockScreen());
                      },
                    ),

                    const SizedBox(height: 18),

                    // =================================================
                    // QUICK ACTIONS
                    // =================================================
                    _buildSectionTitle(context, 'Quick Actions'),

                    const SizedBox(height: 8),

                    GridView.count(
                      crossAxisCount: 2,

                      shrinkWrap: true,

                      physics: const NeverScrollableScrollPhysics(),

                      mainAxisSpacing: 8,

                      crossAxisSpacing: 8,

                      childAspectRatio: 1.95,

                      children: quickActions,
                    ),

                    const SizedBox(height: 18),
                    _buildSectionTitle(context, 'Performance'),
                    const SizedBox(height: 8),
                    DashboardPerformanceChart(
                      totalProducts: totalProducts,
                      totalRawMaterials: totalRawMaterials,
                      totalSuppliers: totalSuppliers,
                      lowStockItems: lowStockItems,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
        ),
      ),
    );
  }
}
