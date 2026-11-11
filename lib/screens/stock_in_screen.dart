import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/supplier.dart';
import '../services/inventory_service.dart';
import 'barcode_scanner_screen.dart';

class StockInScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const StockInScreen({super.key, required this.user});

  @override
  State<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends State<StockInScreen> {
  final InventoryService inventoryService = InventoryService();

  final quantityController = TextEditingController();
  final purposeController = TextEditingController();
  final notesController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  List<Product> products = [];
  List<Supplier> suppliers = [];

  int? selectedProduct;
  int? selectedSupplier;

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    quantityController.dispose();
    purposeController.dispose();
    notesController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD PRODUCTS AND SUPPLIERS
  // ============================================================

  Future<void> loadData() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final productData = await inventoryService.getProducts();
      final supplierData = await inventoryService.getSuppliers();

      if (!mounted) return;

      setState(() {
        products = productData;
        suppliers = supplierData;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage('Unable to load products and suppliers.');
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

    setState(() {
      selectedProduct = matches.first.id;
    });
  }

  // ============================================================
  // PROJECTED QUANTITY
  // ============================================================

  double get projectedQuantity {
    final product = selectedProductData;

    if (product == null) {
      return 0;
    }

    final quantity = double.tryParse(quantityController.text.trim()) ?? 0;

    return product.quantity + quantity;
  }

  // ============================================================
  // SUBMIT STOCK IN
  // ============================================================

  Future<void> submitStockIn() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    if (selectedProduct == null) {
      showMessage('Please select a product.');
      return;
    }

    final quantity = double.tryParse(quantityController.text.trim());

    if (quantity == null || quantity <= 0) {
      showMessage('Enter a valid quantity.');
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
      final success = await inventoryService.stockIn(
        productId: selectedProduct!,
        supplierId: selectedSupplier,
        userId: int.tryParse(widget.user['id']?.toString() ?? ''),
        quantity: quantity,
        purpose: purposeController.text.trim(),
        notes: notesController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        showMessage('Stock received successfully.');

        quantityController.clear();
        purposeController.clear();
        notesController.clear();

        setState(() {
          selectedProduct = null;
          selectedSupplier = null;
        });

        await loadData();
      } else {
        showMessage('Unable to receive stock.');
      }
    } catch (e) {
      if (!mounted) return;

      showMessage('An error occurred while receiving stock.');
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
      onChanged: saving
          ? null
          : (value) {
              setState(() {
                selectedProduct = value;
              });
            },
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
  // SUPPLIER DROPDOWN
  // ============================================================

  Widget buildSupplierDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: selectedSupplier,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Supplier (Optional)',
        hintText: 'Select supplier',
        prefixIcon: const Icon(Icons.local_shipping_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('No Supplier')),
        ...suppliers.map((supplier) {
          return DropdownMenuItem<int>(
            value: supplier.id,
            child: Text(supplier.name, overflow: TextOverflow.ellipsis),
          );
        }),
      ],
      onChanged: saving
          ? null
          : (value) {
              setState(() {
                selectedSupplier = value;
              });
            },
    );
  }

  // ============================================================
  // CURRENT STOCK CARD
  // ============================================================

  Widget buildCurrentStockCard() {
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
            : Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLowStock
              ? Colors.orange.withValues(alpha: 0.25)
              : Colors.green.withValues(alpha: 0.25),
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
                color: isLowStock ? Colors.orange : Colors.green,
              ),
              const SizedBox(width: 10),
              const Text(
                'Stock Information',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: buildStockInfo(
                  'Current Stock',
                  '${formatNumber(product.quantity)} '
                      '${product.unit}',
                ),
              ),
              Expanded(
                child: buildStockInfo(
                  'Minimum Stock',
                  '${formatNumber(product.minimumStock)} '
                      '${product.unit}',
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.green.withValues(alpha: 0.08),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up, size: 20, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'After receiving: '
                    '${formatNumber(projectedQuantity)} '
                    '${product.unit}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STOCK INFORMATION
  // ============================================================

  Widget buildStockInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ============================================================
  // FORMAT NUMBER
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
          'Stock In',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: loading ? null : loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadData,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Receive Stock',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Record inventory received '
                        'into the store.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),

                      const SizedBox(height: 24),

                      buildProductDropdown(),

                      const SizedBox(height: 12),

                      buildCurrentStockCard(),

                      const SizedBox(height: 16),

                      buildSupplierDropdown(),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: quantityController,
                        enabled: !saving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) {
                          setState(() {});
                        },
                        decoration: InputDecoration(
                          labelText: 'Quantity Received',
                          hintText: 'Enter quantity',
                          prefixIcon: const Icon(Icons.add_box_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          final quantity = double.tryParse(value?.trim() ?? '');

                          if (quantity == null || quantity <= 0) {
                            return 'Enter a valid quantity';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: purposeController,
                        enabled: !saving,
                        decoration: InputDecoration(
                          labelText: 'Purpose',
                          hintText: 'e.g. Raw material delivery',
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
                          onPressed: saving ? null : submitStockIn,
                          icon: saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_box_outlined),
                          label: Text(
                            saving ? 'RECEIVING STOCK...' : 'RECEIVE STOCK',
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
