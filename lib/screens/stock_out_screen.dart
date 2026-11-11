import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/inventory_service.dart';
import 'barcode_scanner_screen.dart';

class StockOutScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const StockOutScreen({super.key, required this.user});

  @override
  State<StockOutScreen> createState() => _StockOutScreenState();
}

class _StockOutScreenState extends State<StockOutScreen> {
  // ============================================================
  // SERVICE
  // ============================================================

  final InventoryService inventoryService = InventoryService();

  final formKey = GlobalKey<FormState>();

  final quantityController = TextEditingController();
  final purposeController = TextEditingController();
  final notesController = TextEditingController();

  // ============================================================
  // DATA
  // ============================================================

  List<Product> products = [];

  int? selectedProduct;

  bool loading = true;
  bool saving = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    quantityController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    loadProducts();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    quantityController.dispose();
    purposeController.dispose();
    notesController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD PRODUCTS
  // ============================================================

  Future<void> loadProducts() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final result = await inventoryService.getProducts();

      if (!mounted) return;

      setState(() {
        products = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage('Unable to load products.');
    }
  }

  // ============================================================
  // SELECTED PRODUCT
  // ============================================================

  Product? get selectedProductData {
    if (selectedProduct == null) {
      return null;
    }

    try {
      return products.firstWhere((product) => product.id == selectedProduct);
    } catch (_) {
      return null;
    }
  }

  Future<void> scanAndSelectProduct() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (!mounted || barcode == null) return;

    final matches = products.where((product) => product.barcode == barcode);
    if (matches.isEmpty) {
      showMessage(
        'No product has barcode "$barcode". Add it to a product first.',
      );
      return;
    }

    selectProduct(matches.first.id);
  }

  // ============================================================
  // SELECT PRODUCT
  // ============================================================

  void selectProduct(int? id) {
    setState(() {
      selectedProduct = id;
      quantityController.clear();
    });
  }

  // ============================================================
  // PROJECTED STOCK
  // ============================================================

  double get projectedStock {
    final product = selectedProductData;

    if (product == null) {
      return 0;
    }

    final quantity = double.tryParse(quantityController.text.trim()) ?? 0;

    final result = product.quantity - quantity;

    return result < 0 ? 0 : result;
  }

  // ============================================================
  // PROJECTED STATUS
  // ============================================================

  String getProjectedStatus(Product product) {
    final remaining = projectedStock;

    if (remaining <= product.minimumStock * 0.5) {
      return 'Critical Stock';
    }

    if (remaining <= product.minimumStock) {
      return 'Low Stock';
    }

    return 'Healthy Stock';
  }

  // ============================================================
  // SUBMIT STOCK OUT
  // ============================================================

  Future<void> submitStockOut() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    if (selectedProduct == null) {
      showMessage('Please select a product.');
      return;
    }

    final product = selectedProductData;

    if (product == null) {
      showMessage('Selected product could not be found.');
      return;
    }

    final quantity = double.tryParse(quantityController.text.trim());

    if (quantity == null || quantity <= 0) {
      showMessage('Enter a valid quantity.');
      return;
    }

    // Prevent negative stock
    if (quantity > product.quantity) {
      showMessage(
        'Insufficient stock. Available: '
        '${formatNumber(product.quantity)} '
        '${product.unit}.',
      );
      return;
    }

    if (purposeController.text.trim().isEmpty) {
      showMessage('Please enter the purpose.');
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      // ========================================================
      // RECORD STOCK OUT USING INVENTORY SERVICE
      // ========================================================

      final success = await inventoryService.stockOut(
        productId: selectedProduct!,
        userId: int.tryParse(widget.user['id']?.toString() ?? ''),
        quantity: quantity,
        purpose: purposeController.text.trim(),
        notes: notesController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        final remainingStock = product.quantity - quantity;

        String message = 'Stock issued successfully.';

        // ======================================================
        // SMART STOCK WARNING
        // ======================================================

        if (remainingStock <= product.minimumStock * 0.5) {
          message =
              'Stock issued. Warning: '
              '${product.name} is now at CRITICAL stock level.';
        } else if (remainingStock <= product.minimumStock) {
          message =
              'Stock issued. Warning: '
              '${product.name} is now LOW in stock.';
        }

        showMessage(message);

        // Clear form
        quantityController.clear();
        purposeController.clear();
        notesController.clear();

        setState(() {
          selectedProduct = null;
        });

        // Reload updated stock
        await loadProducts();
      } else {
        showMessage('Unable to issue stock.');
      }
    } catch (e) {
      if (!mounted) return;

      showMessage('An error occurred while issuing stock.');
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ============================================================
  // PRODUCT DROPDOWN
  // ============================================================

  Widget buildProductDropdown() {
    final dropdown = DropdownButtonFormField<int>(
      initialValue: selectedProduct,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Product',
        hintText: 'Select product',
        prefixIcon: const Icon(Icons.inventory_2_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: products.map((product) {
        return DropdownMenuItem<int>(
          value: product.id,
          child: Text(product.name, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: saving ? null : selectProduct,
      validator: (value) {
        if (value == null) {
          return 'Please select a product';
        }

        return null;
      },
    );
    if (!isBarcodeScannerSupported) return dropdown;

    return Row(
      children: [
        Expanded(child: dropdown),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Scan product barcode',
          onPressed: saving ? null : scanAndSelectProduct,
          icon: const Icon(Icons.qr_code_scanner),
        ),
      ],
    );
  }

  // ============================================================
  // AVAILABLE STOCK CARD
  // ============================================================

  Widget buildAvailableStockCard() {
    final product = selectedProductData;

    if (product == null) {
      return const SizedBox.shrink();
    }

    final isLowStock = product.isLowStock;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLowStock
            ? Colors.orange.withValues(alpha: 0.08)
            : Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLowStock
              ? Colors.orange.withValues(alpha: 0.25)
              : Colors.blue.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isLowStock
                    ? Icons.warning_amber_rounded
                    : Icons.inventory_2_outlined,
                color: isLowStock ? Colors.orange : Colors.blue,
              ),
              const SizedBox(width: 10),
              const Text(
                'Stock Information',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: stockInfo(
                  'Available',
                  '${formatNumber(product.quantity)} '
                      '${product.unit}',
                ),
              ),
              Expanded(
                child: stockInfo(
                  'Minimum',
                  '${formatNumber(product.minimumStock)} '
                      '${product.unit}',
                ),
              ),
            ],
          ),

          if (quantityController.text.isNotEmpty)
            Column(
              children: [
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: getProjectedStatus(product) == 'Critical Stock'
                        ? Colors.red.withValues(alpha: 0.08)
                        : getProjectedStatus(product) == 'Low Stock'
                        ? Colors.orange.withValues(alpha: 0.08)
                        : Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        getProjectedStatus(product) == 'Critical Stock'
                            ? Icons.crisis_alert
                            : getProjectedStatus(product) == 'Low Stock'
                            ? Icons.warning_amber
                            : Icons.check_circle,
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'After issuing stock',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              '${formatNumber(projectedStock)} '
                              '${product.unit}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),

                            Text(
                              getProjectedStatus(product),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ============================================================
  // STOCK INFO
  // ============================================================

  Widget stockInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),

        const SizedBox(height: 4),

        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ============================================================
  // QUANTITY FIELD
  // ============================================================

  Widget buildQuantityField() {
    final product = selectedProductData;

    return TextFormField(
      controller: quantityController,
      enabled: !saving,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Quantity Issued',
        hintText: 'Enter quantity',
        prefixIcon: const Icon(Icons.remove_circle_outline),
        suffixText: product?.unit ?? '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        final quantity = double.tryParse(value?.trim() ?? '');

        if (quantity == null || quantity <= 0) {
          return 'Enter a valid quantity';
        }

        if (product != null && quantity > product.quantity) {
          return 'Quantity exceeds available stock';
        }

        return null;
      },
    );
  }

  // ============================================================
  // NUMBER FORMAT
  // ============================================================

  String formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Stock Out',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: loading ? null : loadProducts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadProducts,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Issue Stock',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Record inventory issued '
                        'for production or other use.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),

                      const SizedBox(height: 24),

                      buildProductDropdown(),

                      const SizedBox(height: 12),

                      buildAvailableStockCard(),

                      const SizedBox(height: 16),

                      buildQuantityField(),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: purposeController,
                        enabled: !saving,
                        decoration: InputDecoration(
                          labelText: 'Purpose',
                          hintText: 'e.g. Production',
                          prefixIcon: const Icon(Icons.description_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter the purpose';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: notesController,
                        enabled: !saving,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Notes (Optional)',
                          hintText: 'Enter additional notes',
                          prefixIcon: const Icon(Icons.notes_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: saving ? null : submitStockOut,
                          icon: saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.remove_circle_outline),
                          label: Text(
                            saving ? 'ISSUING STOCK...' : 'ISSUE STOCK',
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
