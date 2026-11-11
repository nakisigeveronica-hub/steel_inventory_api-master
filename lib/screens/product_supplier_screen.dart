import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/product.dart';
import '../models/supplier.dart';
import '../services/inventory_service.dart';

class ProductSupplierScreen extends StatefulWidget {
  final Product product;

  const ProductSupplierScreen({super.key, required this.product});

  @override
  State<ProductSupplierScreen> createState() => _ProductSupplierScreenState();
}

class _ProductSupplierScreenState extends State<ProductSupplierScreen> {
  final InventoryService inventoryService = InventoryService();

  List<Supplier> allSuppliers = [];
  List<Supplier> linkedSuppliers = [];

  Supplier? primarySupplier;

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<void> loadData() async {
    setState(() {
      loading = true;
    });

    try {
      final suppliers = await inventoryService.getSuppliers();

      final linked = await inventoryService.getSuppliersForProduct(
        widget.product.id,
      );

      final primary = await inventoryService.getPrimarySupplier(
        widget.product.id,
      );

      if (!mounted) return;

      setState(() {
        allSuppliers = suppliers;
        linkedSuppliers = linked;
        primarySupplier = primary;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage('Unable to load suppliers', isError: true);
    }
  }

  // ============================================================
  // CHECK PRIMARY SUPPLIER
  // ============================================================

  bool isPrimarySupplier(Supplier supplier) {
    return primarySupplier?.id == supplier.id;
  }

  // ============================================================
  // ADD / LINK SUPPLIER
  // ============================================================

  Future<void> showAddSupplierDialog() async {
    final linkedIds = linkedSuppliers.map((supplier) => supplier.id).toSet();

    final availableSuppliers = allSuppliers
        .where((supplier) => !linkedIds.contains(supplier.id))
        .toList();

    if (availableSuppliers.isEmpty) {
      showMessage(
        allSuppliers.isEmpty
            ? 'No suppliers found. Add a supplier in the Suppliers section first.'
            : 'All suppliers are already linked to this product',
      );
      return;
    }

    Supplier? selectedSupplier;
    bool setAsPrimary = primarySupplier == null;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Supplier'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Supplier>(
                      decoration: const InputDecoration(
                        labelText: 'Select Supplier',
                        prefixIcon: Icon(Icons.business_outlined),
                        border: OutlineInputBorder(),
                      ),
                      initialValue: selectedSupplier,
                      isExpanded: true,
                      items: availableSuppliers.map((supplier) {
                        return DropdownMenuItem<Supplier>(
                          value: supplier,
                          child: Text(
                            supplier.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedSupplier = value;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: setAsPrimary,
                      title: const Text('Set as Primary Supplier'),
                      subtitle: const Text('Used for automatic restock orders'),
                      secondary: const Icon(Icons.star_outline),
                      onChanged: (value) {
                        setDialogState(() {
                          setAsPrimary = value ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedSupplier == null
                      ? null
                      : () async {
                          Navigator.pop(dialogContext);

                          await linkSupplier(selectedSupplier!, setAsPrimary);
                        },
                  child: const Text('Add Supplier'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> linkSupplier(Supplier supplier, bool setAsPrimary) async {
    try {
      setState(() {
        saving = true;
      });

      await inventoryService.linkSupplierToProduct(
        productId: widget.product.id,
        supplierId: supplier.id,
        isPrimary: setAsPrimary,
      );

      await loadData();

      if (!mounted) return;

      showMessage(
        setAsPrimary
            ? '${supplier.name} added as primary supplier'
            : '${supplier.name} added successfully',
      );
    } catch (e) {
      if (!mounted) return;

      showMessage('Unable to add supplier', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  // ============================================================
  // SET PRIMARY SUPPLIER
  // ============================================================

  Future<void> setPrimarySupplier(Supplier supplier) async {
    if (isPrimarySupplier(supplier)) {
      return;
    }

    try {
      setState(() {
        saving = true;
      });

      await inventoryService.setPrimarySupplier(
        productId: widget.product.id,
        supplierId: supplier.id,
      );

      await loadData();

      if (!mounted) return;

      showMessage('${supplier.name} is now the primary supplier');
    } catch (e) {
      if (!mounted) return;

      showMessage('Unable to set primary supplier', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  // ============================================================
  // REMOVE SUPPLIER
  // ============================================================

  Future<void> removeSupplier(Supplier supplier) async {
    final isPrimary = isPrimarySupplier(supplier);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Supplier'),
          content: Text(
            isPrimary
                ? '${supplier.name} is the primary supplier. '
                      'Are you sure you want to remove it?'
                : 'Are you sure you want to remove '
                      '${supplier.name} from this product?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      setState(() {
        saving = true;
      });

      await inventoryService.unlinkSupplierFromProduct(
        productId: widget.product.id,
        supplierId: supplier.id,
      );

      await loadData();

      if (!mounted) return;

      showMessage('${supplier.name} removed successfully');
    } catch (e) {
      if (!mounted) return;

      showMessage('Unable to remove supplier', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  // ============================================================
  // CALL SUPPLIER
  // ============================================================

  Future<void> callSupplier(Supplier supplier) async {
    final phone = supplier.phone.trim();

    if (phone.isEmpty) {
      showMessage('No phone number available for this supplier', isError: true);
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);

    try {
      final launched = await launchUrl(uri);

      if (!launched && mounted) {
        showMessage('Unable to open phone dialer', isError: true);
      }
    } catch (e) {
      if (!mounted) return;

      showMessage('Unable to call supplier', isError: true);
    }
  }

  // ============================================================
  // WHATSAPP SUPPLIER
  // ============================================================

  Future<void> contactSupplierOnWhatsApp(Supplier supplier) async {
    final phone = cleanPhoneNumber(supplier.phone);

    if (phone.isEmpty) {
      showMessage('No valid phone number available', isError: true);
      return;
    }

    final message =
        'Hello ${supplier.contactPerson.isNotEmpty ? supplier.contactPerson : supplier.name},\n\n'
        'I am contacting you regarding our inventory supply.\n\n'
        'Product: ${widget.product.name}\n'
        'Current Stock: ${formatQuantity(widget.product.quantity)} ${widget.product.unit}\n'
        'Minimum Stock: ${formatQuantity(widget.product.minimumStock)} ${widget.product.unit}\n\n'
        'Please let us know about product availability and pricing.\n\n'
        'Thank you.';

    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        showMessage('Unable to open WhatsApp', isError: true);
      }
    } catch (e) {
      if (!mounted) return;

      showMessage('Unable to open WhatsApp', isError: true);
    }
  }

  // ============================================================
  // PHONE NUMBER CLEANING
  // ============================================================

  String cleanPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');

    // Uganda number:
    // 077xxxxxxx -> 25677xxxxxxx
    // 078xxxxxxx -> 25678xxxxxxx
    if (cleaned.startsWith('0')) {
      cleaned = '256${cleaned.substring(1)}';
    }

    // +25677xxxxxxx -> 25677xxxxxxx
    if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    }

    return cleaned;
  }

  // ============================================================
  // RESTOCK ORDER
  // ============================================================

  Future<void> sendRestockOrder() async {
    try {
      setState(() {
        saving = true;
      });

      final success = await inventoryService.sendRestockOrder(
        widget.product.id,
      );

      if (!mounted) return;

      if (success) {
        showMessage('Restock order opened in WhatsApp');
      } else {
        showMessage(
          'No primary supplier is available for this product',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      showMessage('Unable to create restock order', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  // ============================================================
  // STOCK HELPERS
  // ============================================================

  String getStockStatus() {
    final quantity = widget.product.quantity;
    final minimum = widget.product.minimumStock;

    if (quantity <= minimum * 0.5) {
      return 'Critical';
    }

    if (quantity <= minimum) {
      return 'Low Stock';
    }

    return 'Healthy';
  }

  IconData getStockIcon() {
    final quantity = widget.product.quantity;
    final minimum = widget.product.minimumStock;

    if (quantity <= minimum * 0.5) {
      return Icons.crisis_alert;
    }

    if (quantity <= minimum) {
      return Icons.warning_amber_rounded;
    }

    return Icons.check_circle_outline;
  }

  Color getStockColor() {
    final quantity = widget.product.quantity;
    final minimum = widget.product.minimumStock;

    if (quantity <= minimum * 0.5) {
      return Colors.red;
    }

    if (quantity <= minimum) {
      return Colors.orange;
    }

    return Colors.green;
  }

  double getRecommendedRestock() {
    return inventoryService.getRecommendedRestockQuantity(widget.product);
  }

  String formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  // ============================================================
  // SUPPLIER OPTIONS
  // ============================================================

  void showSupplierOptions(Supplier supplier) {
    final primary = isPrimarySupplier(supplier);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: CircleAvatar(
                  child: Text(
                    supplier.name.isNotEmpty
                        ? supplier.name[0].toUpperCase()
                        : '?',
                  ),
                ),
                title: Text(
                  supplier.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: primary
                    ? const Text('Primary Supplier')
                    : const Text('Supplier'),
              ),

              const Divider(),

              ListTile(
                leading: const Icon(Icons.star_outline),
                title: Text(
                  primary ? 'Primary Supplier' : 'Set as Primary Supplier',
                ),
                enabled: !primary,
                onTap: primary
                    ? null
                    : () {
                        Navigator.pop(context);
                        setPrimarySupplier(supplier);
                      },
              ),

              ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: const Text('Call Supplier'),
                onTap: () {
                  Navigator.pop(context);
                  callSupplier(supplier);
                },
              ),

              ListTile(
                leading: const Icon(Icons.chat_outlined),
                title: const Text('WhatsApp Supplier'),
                onTap: () {
                  Navigator.pop(context);
                  contactSupplierOnWhatsApp(supplier);
                },
              ),

              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove Supplier'),
                onTap: () {
                  Navigator.pop(context);
                  removeSupplier(supplier);
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final stockStatus = getStockStatus();
    final stockColor = getStockColor();
    final recommendedRestock = getRecommendedRestock();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Suppliers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loading ? null : loadData,
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: saving ? null : showAddSupplierDialog,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Supplier'),
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  buildProductSummary(
                    stockStatus,
                    stockColor,
                    recommendedRestock,
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Suppliers',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      Text(
                        '${linkedSuppliers.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  if (linkedSuppliers.isEmpty)
                    buildEmptySupplierState()
                  else
                    ...linkedSuppliers.map(buildSupplierCard),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // PRODUCT SUMMARY
  // ============================================================

  Widget buildProductSummary(
    String stockStatus,
    Color stockColor,
    double recommendedRestock,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  child: Icon(
                    widget.product.itemType == 'Raw Material'
                        ? Icons.precision_manufacturing
                        : Icons.inventory_2,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        widget.product.itemType,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: stockColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(getStockIcon(), size: 16, color: stockColor),
                      const SizedBox(width: 5),
                      Text(
                        stockStatus,
                        style: TextStyle(
                          color: stockColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: buildStockInfo(
                    'Current Stock',
                    '${formatQuantity(widget.product.quantity)} ${widget.product.unit}',
                    Icons.inventory_2_outlined,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: buildStockInfo(
                    'Minimum Stock',
                    '${formatQuantity(widget.product.minimumStock)} ${widget.product.unit}',
                    Icons.warning_amber_outlined,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            buildStockInfo(
              'Recommended Restock',
              '${formatQuantity(recommendedRestock)} ${widget.product.unit}',
              Icons.add_box_outlined,
            ),

            if (primarySupplier != null) ...[
              const SizedBox(height: 16),

              const Divider(),

              const SizedBox(height: 8),

              Row(
                children: [
                  const Icon(Icons.star, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Primary Supplier',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 5),

              Text(
                primarySupplier!.name,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],

            if (recommendedRestock > 0 && primarySupplier != null) ...[
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: saving ? null : sendRestockOrder,
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: Text(
                    'Order ${formatQuantity(recommendedRestock)} '
                    '${widget.product.unit} via WhatsApp',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildStockInfo(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY SUPPLIER STATE
  // ============================================================

  Widget buildEmptySupplierState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 60, color: Colors.grey.shade400),

            const SizedBox(height: 12),

            const Text(
              'No suppliers linked',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            Text(
              'Add a supplier to this product so you can '
              'easily contact them and place restock orders.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),

            const SizedBox(height: 18),

            OutlinedButton.icon(
              onPressed: showAddSupplierDialog,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add Supplier'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SUPPLIER CARD
  // ============================================================

  Widget buildSupplierCard(Supplier supplier) {
    final primary = isPrimarySupplier(supplier);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 25,
                  child: Text(
                    supplier.name.isNotEmpty
                        ? supplier.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              supplier.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          if (primary)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.amber.withValues(alpha: 0.15),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, size: 14),
                                  SizedBox(width: 3),
                                  Text(
                                    'Primary',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      if (supplier.contactPerson.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          supplier.contactPerson,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],

                      if (supplier.phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 15),
                            const SizedBox(width: 5),
                            Text(supplier.phone),
                          ],
                        ),
                      ],

                      if (supplier.email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 15),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                supplier.email,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    showSupplierOptions(supplier);
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      callSupplier(supplier);
                    },
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Call'),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      contactSupplierOnWhatsApp(supplier);
                    },
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('WhatsApp'),
                  ),
                ),
              ],
            ),

            if (!primary) ...[
              const SizedBox(height: 6),

              TextButton.icon(
                onPressed: saving
                    ? null
                    : () {
                        setPrimarySupplier(supplier);
                      },
                icon: const Icon(Icons.star_outline, size: 18),
                label: const Text('Set as Primary Supplier'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
