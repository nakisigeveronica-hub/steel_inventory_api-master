import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'inventory_assistant_screen.dart';
import 'low_stock_screen.dart';
import 'products_screen.dart';
import 'stock_in_screen.dart';
import 'stock_out_screen.dart';
import 'suppliers_screen.dart';
import 'transactions_screen.dart';
import '../services/user_permissions.dart';
import 'user_management_screen.dart';
import 'category_management_screen.dart';

class MainNavigation extends StatefulWidget {
  final Map<String, dynamic> user;

  const MainNavigation({super.key, required this.user});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = _buildScreens();
  }

  bool get _isSupervisor =>
      UserPermissions.normalizeRole(widget.user['role']) ==
      UserPermissions.supervisor;

  List<Widget> _buildScreens() {
    final dashboard = RoleDashboard.forUser(user: widget.user);
    final more = MoreScreen(user: widget.user, onNavigate: _openScreen);
    if (_isSupervisor) {
      return [
        dashboard,
        const TransactionsScreen(),
        InventoryAssistantScreen(user: widget.user, initialTab: 1),
        more,
      ];
    }
    return [
      dashboard,
      ProductsScreen(user: widget.user),
      const TransactionsScreen(),
      more,
    ];
  }

  void _openScreen(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navigationItems = _isSupervisor
        ? const [
            ('Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded),
            (
              'Transactions',
              Icons.receipt_long_outlined,
              Icons.receipt_long_rounded,
            ),
            ('Reports', Icons.summarize_outlined, Icons.summarize_rounded),
            ('More', Icons.more_horiz_outlined, Icons.more_horiz_rounded),
          ]
        : const [
            ('Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded),
            ('Products', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
            (
              'Transactions',
              Icons.receipt_long_outlined,
              Icons.receipt_long_rounded,
            ),
            ('More', Icons.more_horiz_outlined, Icons.more_horiz_rounded),
          ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Container(
          height: 68,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var index = 0; index < navigationItems.length; index++)
                _NavigationItem(
                  label: navigationItems[index].$1,
                  icon: navigationItems[index].$2,
                  selectedIcon: navigationItems[index].$3,
                  selected: _selectedIndex == index,
                  onTap: () => _selectTab(index),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }
}

class _NavigationItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(13),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: 54,
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? selectedIcon : icon,
                      color: foregroundColor,
                      size: 21,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: foregroundColor,
                        fontSize: 10,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MoreScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  final ValueChanged<Widget> onNavigate;

  const MoreScreen({super.key, required this.user, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final canRecordStock = UserPermissions.canRecordStock(user['role']);
    final isAdministrator = UserPermissions.canManageUsers(user['role']);
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (canRecordStock) ...[
            _sectionTitle(context, 'Stock'),
            _destination(
              context,
              icon: Icons.add_box_outlined,
              title: 'Stock In',
              subtitle: 'Receive inventory',
              onTap: () => onNavigate(StockInScreen(user: user)),
            ),
            _destination(
              context,
              icon: Icons.remove_circle_outline,
              title: 'Stock Out',
              subtitle: 'Record issued inventory',
              onTap: () => onNavigate(StockOutScreen(user: user)),
            ),
          ],
          _sectionTitle(context, 'Management'),
          _destination(
            context,
            icon: Icons.local_shipping_outlined,
            title: 'Suppliers',
            subtitle: isAdministrator
                ? 'View and manage supplier details'
                : 'View supplier information',
            onTap: () => onNavigate(SuppliersScreen(user: user)),
          ),
          _destination(
            context,
            icon: Icons.warning_amber_outlined,
            title: 'Low Stock',
            subtitle: 'Review items needing attention',
            onTap: () => onNavigate(const LowStockScreen()),
          ),
          _destination(
            context,
            icon: Icons.auto_awesome_outlined,
            title: 'Inventory Assistant',
            subtitle: UserPermissions.canGenerateReports(user['role'])
                ? 'Ask questions and generate inventory reports'
                : 'Get inventory insights',
            onTap: () => onNavigate(InventoryAssistantScreen(user: user)),
          ),
          if (isAdministrator) ...[
            _sectionTitle(context, 'Administration'),
            _destination(
              context,
              icon: Icons.category_outlined,
              title: 'Category management',
              subtitle: 'Create and manage product categories',
              onTap: () => onNavigate(CategoryManagementScreen(user: user)),
            ),
            _destination(
              context,
              icon: Icons.manage_accounts_outlined,
              title: 'User management',
              subtitle: 'Create accounts and assign roles',
              onTap: () => onNavigate(UserManagementScreen(currentUser: user)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _destination(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
