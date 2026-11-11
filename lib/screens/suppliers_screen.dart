import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/supplier.dart';
import '../services/inventory_service.dart';
import '../services/user_permissions.dart';
import 'supplier_form_screen.dart';

class SuppliersScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const SuppliersScreen({super.key, required this.user});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final InventoryService _inventoryService = InventoryService();

  final TextEditingController _searchController = TextEditingController();

  List<Supplier> _suppliers = [];
  List<Supplier> _filteredSuppliers = [];

  bool _isLoading = true;

  bool get _canManageSuppliers =>
      UserPermissions.canManageSuppliers(widget.user['role']);

  // ============================================================
  // INIT / DISPOSE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_filterSuppliers);
    _loadSuppliers();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterSuppliers);
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD SUPPLIERS
  // ============================================================

  Future<void> _loadSuppliers() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final suppliers = await _inventoryService.getSuppliers();

      if (!mounted) return;

      setState(() {
        _suppliers = suppliers;
        _filteredSuppliers = suppliers;
        _isLoading = false;
      });

      // Re-apply the current search query.
      _filterSuppliers();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Failed to load suppliers: $e', isError: true);
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _filterSuppliers() {
    if (!mounted) return;

    final query = _searchController.text.trim().toLowerCase();

    final filtered = query.isEmpty
        ? List<Supplier>.from(_suppliers)
        : _suppliers.where((supplier) {
            return supplier.name.toLowerCase().contains(query) ||
                supplier.contactPerson.toLowerCase().contains(query) ||
                supplier.phone.toLowerCase().contains(query) ||
                supplier.email.toLowerCase().contains(query) ||
                supplier.address.toLowerCase().contains(query);
          }).toList();

    setState(() {
      _filteredSuppliers = filtered;
    });
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : const Color(0xFF379805),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ============================================================
  // ADD / EDIT SUPPLIER
  // ============================================================

  Future<void> _openSupplierForm({Supplier? supplier}) async {
    if (!_canManageSuppliers) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SupplierFormScreen(supplier: supplier)),
    );

    if (!mounted) return;

    if (result == true) {
      await _loadSuppliers();
    }
  }

  // ============================================================
  // DELETE SUPPLIER
  // ============================================================

  Future<void> _deleteSupplier(Supplier supplier) async {
    if (!_canManageSuppliers) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red),
              SizedBox(width: 10),
              Text('Delete Supplier'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete '
            '"${supplier.name}"?\n\n'
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _inventoryService.deleteSupplier(supplier.id);

      await _loadSuppliers();

      if (!mounted) return;

      _showMessage('Supplier deleted successfully.');
    } catch (e) {
      if (!mounted) return;

      _showMessage('Failed to delete supplier: $e', isError: true);
    }
  }

  // ============================================================
  // CALL SUPPLIER
  // ============================================================

  Future<void> _callSupplier(Supplier supplier) async {
    final rawPhone = supplier.phone.trim();

    if (rawPhone.isEmpty) {
      _showMessage(
        'This supplier does not have a phone number.',
        isError: true,
      );
      return;
    }

    final phone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');

    final uri = Uri.parse('tel:$phone');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showMessage('Unable to open the phone app.', isError: true);
      }
    } catch (e) {
      _showMessage('Unable to make the call.', isError: true);
    }
  }

  // ============================================================
  // WHATSAPP
  // ============================================================

  Future<void> _openWhatsApp(Supplier supplier) async {
    final rawPhone = supplier.phone.trim();

    if (rawPhone.isEmpty) {
      _showMessage(
        'This supplier does not have a phone number.',
        isError: true,
      );
      return;
    }

    String phone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');

    // Convert Ugandan local format:
    // 0700000000 -> 256700000000
    if (phone.startsWith('0')) {
      phone = '256${phone.substring(1)}';
    }

    // Remove + if present.
    phone = phone.replaceAll('+', '');

    final recipient = supplier.contactPerson.trim().isNotEmpty
        ? supplier.contactPerson.trim()
        : supplier.name.trim();

    final message = Uri.encodeComponent(
      'Hello $recipient,\n\n'
      'I am contacting you from our '
      'Steel Inventory Management System.\n\n'
      'We would like to make an inquiry regarding '
      'our steel inventory requirements.\n\n'
      'Thank you.',
    );

    final uri = Uri.parse('https://wa.me/$phone?text=$message');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showMessage('WhatsApp could not be opened.', isError: true);
      }
    } catch (e) {
      _showMessage('Unable to open WhatsApp.', isError: true);
    }
  }

  // ============================================================
  // SUPPLIER OPTIONS
  // ============================================================

  void _showSupplierOptions(Supplier supplier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),

                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 18),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF379805,
                          ).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.business,
                          color: Color(0xFF379805),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          supplier.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                const Divider(),

                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.phone, color: Color(0xFF379805)),
                  ),
                  title: const Text('Call Supplier'),
                  subtitle: const Text('Make a phone call'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _callSupplier(supplier);
                  },
                ),

                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.chat, color: Color(0xFF379805)),
                  ),
                  title: const Text('WhatsApp Supplier'),
                  subtitle: const Text('Send a WhatsApp message'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _openWhatsApp(supplier);
                  },
                ),

                if (_canManageSuppliers)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.edit, color: Color(0xFF379805)),
                    ),
                    title: const Text('Edit Supplier'),
                    subtitle: const Text('Update supplier information'),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _openSupplierForm(supplier: supplier);
                    },
                  ),

                if (_canManageSuppliers)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFEBEE),
                      child: Icon(Icons.delete_outline, color: Colors.red),
                    ),
                    title: const Text(
                      'Delete Supplier',
                      style: TextStyle(color: Colors.red),
                    ),
                    subtitle: const Text('Remove this supplier'),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _deleteSupplier(supplier);
                    },
                  ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // SUPPLIER CARD
  // ============================================================

  Widget _buildSupplierCard(Supplier supplier) {
    final hasPhone = supplier.phone.trim().isNotEmpty;

    final hasEmail = supplier.email.trim().isNotEmpty;

    final hasAddress = supplier.address.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ----------------------------------------------------
            // HEADER
            // ----------------------------------------------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF379805).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: Color(0xFF379805),
                    size: 28,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      if (supplier.contactPerson.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                supplier.contactPerson,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                IconButton(
                  tooltip: 'More options',
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    _showSupplierOptions(supplier);
                  },
                ),
              ],
            ),

            const SizedBox(height: 14),

            const Divider(height: 1),

            const SizedBox(height: 14),

            // ----------------------------------------------------
            // CONTACT INFORMATION
            // ----------------------------------------------------
            if (hasPhone) _buildInfoRow(Icons.phone_outlined, supplier.phone),

            if (hasEmail) _buildInfoRow(Icons.email_outlined, supplier.email),

            if (hasAddress)
              _buildInfoRow(Icons.location_on_outlined, supplier.address),

            if (!hasPhone && !hasEmail && !hasAddress)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No contact information available',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            const SizedBox(height: 14),

            // ----------------------------------------------------
            // ACTION BUTTONS
            // ----------------------------------------------------
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasPhone ? () => _callSupplier(supplier) : null,
                    icon: const Icon(Icons.phone_outlined, size: 19),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF379805),
                      side: BorderSide(
                        color: hasPhone
                            ? const Color(0xFF379805)
                            : Colors.grey.shade300,
                      ),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: hasPhone ? () => _openWhatsApp(supplier) : null,
                    icon: const Icon(Icons.chat_outlined, size: 19),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF379805),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade200,
                      disabledForegroundColor: Colors.grey.shade500,
                      minimumSize: const Size.fromHeight(46),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF379805)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH BAR
  // ============================================================

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search suppliers...',
          hintStyle: TextStyle(color: Colors.grey.shade500),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF379805)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFF379805), width: 1.5),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SUPPLIER SUMMARY
  // ============================================================

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _summaryCard(
              icon: Icons.business,
              title: 'Suppliers',
              value: _suppliers.length,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryCard(
              icon: Icons.search,
              title: 'Showing',
              value: _filteredSuppliers.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required int value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF379805).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF379805)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    final hasSearch = _searchController.text.trim().isNotEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF379805).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasSearch ? Icons.search_off : Icons.business_outlined,
                      size: 50,
                      color: const Color(0xFF379805),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    hasSearch ? 'No suppliers found' : 'No suppliers yet',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    hasSearch
                        ? 'Try searching with a different name, phone number or email.'
                        : 'Add your first supplier to start managing your suppliers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                  ),

                  if (!hasSearch && _canManageSuppliers) ...[
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => _openSupplierForm(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Supplier'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF379805),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      appBar: AppBar(
        title: const Text(
          'Suppliers',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadSuppliers,
          ),
        ],
      ),

      floatingActionButton: _canManageSuppliers
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF379805),
              foregroundColor: Colors.white,
              onPressed: () => _openSupplierForm(),
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Supplier',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,

      body: RefreshIndicator(
        color: const Color(0xFF379805),
        onRefresh: _loadSuppliers,
        child: Column(
          children: [
            _buildSearchBar(),

            if (!_isLoading && _suppliers.isNotEmpty) _buildSummary(),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF379805),
                      ),
                    )
                  : _filteredSuppliers.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                      itemCount: _filteredSuppliers.length,
                      itemBuilder: (context, index) {
                        return _buildSupplierCard(_filteredSuppliers[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
