class UserPermissions {
  static const String inventoryPersonnel = 'Inventory/Store Personnel';
  static const String supervisor = 'Supervisor';
  static const String administrator = 'Administrator';

  static const List<String> roles = [
    inventoryPersonnel,
    supervisor,
    administrator,
  ];

  static String normalizeRole(dynamic value) {
    final role = value?.toString().trim().toLowerCase() ?? '';
    if (role == 'admin' || role == 'administrator') {
      return administrator;
    }
    if (role == 'supervisor') {
      return supervisor;
    }
    if (role == 'staff' ||
        role == 'inventory/store personnel' ||
        role == 'inventory personnel') {
      return inventoryPersonnel;
    }
    return '';
  }

  static bool canManageProducts(dynamic role) =>
      normalizeRole(role) != supervisor && normalizeRole(role).isNotEmpty;

  static bool canManageSuppliers(dynamic role) =>
      normalizeRole(role) == administrator;

  static bool canRecordStock(dynamic role) =>
      normalizeRole(role) != supervisor && normalizeRole(role).isNotEmpty;

  static bool canManageUsers(dynamic role) =>
      normalizeRole(role) == administrator;

  static bool canGenerateReports(dynamic role) =>
      normalizeRole(role) == supervisor || normalizeRole(role) == administrator;
}
