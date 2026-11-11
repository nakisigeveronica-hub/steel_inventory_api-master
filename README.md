# Steel Inventory

A Flutter inventory management app with local SQLite storage, stock tracking,
barcode scanning, supplier records, notifications, and an AI inventory
assistant.

## User roles

The first account is created during onboarding and is an Administrator.
Administrators can add, edit, and remove accounts from **More > User
management**, assign roles, and manage suppliers and product categories.
After sign-in, each role is routed to its own dashboard and navigation layout.

- **Inventory/Store Personnel** can manage products, scan barcodes, record
  stock-in and stock-out transactions, and view inventory, suppliers, alerts,
  and transaction history.
- **Supervisor** can monitor the dashboard, products, suppliers, alerts, and
  transaction history, and can generate inventory reports. Stock transactions
  and inventory changes are not available to this role.
- **Administrator** can manage user accounts and roles, products, suppliers,
  and categories, and can use all inventory and reporting features.

Stock approvals are not implemented.

If the Administrator password is forgotten, use **Forgot Administrator
password?** on the sign-in screen. On Android, the first recovery requires
verification with the phone's screen lock or biometrics, then resets the
password and displays a one-time recovery code. Save the code securely; it can
reset the password later. Device verification can also replace a lost recovery
code. Recovery changes the account credentials only and does not erase
inventory data. Updating the app preserves the existing local database; do not
uninstall or clear app data for password recovery.
