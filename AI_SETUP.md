# DeepSeek setup

The inventory remains in the app's local SQLite database. No PHP service or
database server is used. To enable AI chat and report summaries:

1. Each manager creates a personal API key through their DeepSeek account.
2. Open **Inventory Assistant** and tap the key icon.
3. Enter and save the key. It is stored in the device's secure storage; use the
   same dialog to replace or remove it.

The app sends requests directly to `https://api.deepseek.com` over HTTPS using
the saved key. The key is not included in the source code or app build config.
Because this is a direct client integration, use each manager's own key, not a
shared company key embedded in the app. API usage is billed and controlled by
the account that owns that key. The key is stored for the app on that device,
not separately for each local SQLite user.

For chat and AI report summaries, relevant inventory details from SQLite (such
as product names and quantities, transaction summaries, supplier names, and
notifications) are sent to DeepSeek. Do not enable this feature for data that
your organization is not permitted to share with that provider. Reports'
inventory totals and trends are calculated locally; the AI provides the
executive summary.

An internet connection is required. If no key is configured or DeepSeek is
unavailable, the inventory overview and locally calculated report data remain
available; the app displays an error for the AI response.
