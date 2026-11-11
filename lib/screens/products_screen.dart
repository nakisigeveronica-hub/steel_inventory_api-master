import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/inventory_service.dart';
import '../services/user_permissions.dart';
import '../widgets/product_card.dart';
import 'product_form_screen.dart';
import 'product_supplier_screen.dart';

class ProductsScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ProductsScreen({super.key, required this.user});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  static const Color primaryGreen = Color(0xFF379805);

  final InventoryService _inventoryService = InventoryService();

  final TextEditingController _searchController = TextEditingController();

  List<Product> _products = [];
  List<Product> _filteredProducts = [];

  bool _isLoading = true;
  String _selectedFilter = 'All';

  bool get _canManageProducts =>
      UserPermissions.canManageProducts(widget.user['role']);
  bool get _canManageSuppliers =>
      UserPermissions.canManageSuppliers(widget.user['role']);

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_filterProducts);

    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterProducts);
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD PRODUCTS
  // ============================================================

  Future<void> _loadProducts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final products = await _inventoryService.getProducts();

      if (!mounted) return;

      setState(() {
        _products = products;
        _isLoading = false;
      });

      _filterProducts();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showSnackBar('Unable to load products.', isError: true);
    }
  }

  // ============================================================
  // FILTER PRODUCTS
  // ============================================================

  void _filterProducts() {
    final search = _searchController.text.trim().toLowerCase();

    List<Product> results = List<Product>.from(_products);

    // Filter by category/type
    if (_selectedFilter == 'Raw Materials') {
      results = results.where((product) {
        return product.isRawMaterial;
      }).toList();
    } else if (_selectedFilter == 'Finished Products') {
      results = results.where((product) {
        return product.isFinishedProduct;
      }).toList();
    } else if (_selectedFilter == 'Low Stock') {
      results = results.where((product) {
        return product.isLowStock;
      }).toList();
    }

    // Search
    if (search.isNotEmpty) {
      results = results.where((product) {
        final name = product.name.toLowerCase();
        final description = product.description.toLowerCase();
        final category = (product.categoryName ?? '').toLowerCase();
        final type = product.itemType.toLowerCase();
        final unit = product.unit.toLowerCase();
        final barcode = (product.barcode ?? '').toLowerCase();

        return name.contains(search) ||
            description.contains(search) ||
            category.contains(search) ||
            type.contains(search) ||
            unit.contains(search) ||
            barcode.contains(search);
      }).toList();
    }

    if (!mounted) return;

    setState(() {
      _filteredProducts = results;
    });
  }

  void _changeFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });

    _filterProducts();
  }

  // ============================================================
  // ADD PRODUCT
  // ============================================================

  Future<void> _addProduct() async {
    if (!_canManageProducts) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );

    if (result == true) {
      await _loadProducts();
    }
  }

  // ============================================================
  // EDIT PRODUCT
  // ============================================================

  Future<void> _editProduct(Product product) async {
    if (!_canManageProducts) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );

    if (result == true) {
      await _loadProducts();
    }
  }

  Future<void> _manageSuppliers(Product product) async {
    if (!_canManageSuppliers) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductSupplierScreen(product: product),
      ),
    );
    if (mounted) {
      await _loadProducts();
    }
  }

  // ============================================================
  // DELETE PRODUCT
  // ============================================================

  Future<void> _deleteProduct(Product product) async {
    if (!_canManageProducts) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Delete Product?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete '
            '"${product.name}"?\n\n'
            'This will also remove its related '
            'transaction records.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _inventoryService.deleteProduct(product.id);

      if (!mounted) return;

      _showSnackBar('${product.name} deleted successfully.');

      await _loadProducts();
    } catch (e) {
      if (!mounted) return;

      _showSnackBar('Unable to delete product.', isError: true);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // --------------------------------------------------------
      // APP BAR
      // --------------------------------------------------------
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Products',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadProducts,
            icon: Icon(
              Icons.refresh_rounded,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),

      // --------------------------------------------------------
      // BODY
      // --------------------------------------------------------
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : RefreshIndicator(
              color: primaryGreen,
              onRefresh: _loadProducts,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Header
                  SliverToBoxAdapter(child: _buildHeader()),

                  // Search
                  SliverToBoxAdapter(child: _buildSearchBar()),

                  // Filters
                  SliverToBoxAdapter(child: _buildFilters()),

                  // Result header
                  SliverToBoxAdapter(child: _buildResultHeader()),

                  // Products
                  _filteredProducts.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final product = _filteredProducts[index];

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),

                                // NEW REUSABLE PRODUCT CARD
                                child: ProductCard(
                                  product: product,

                                  onTap: () {
                                    _showProductDetails(product);
                                  },

                                  onEdit: () {
                                    _editProduct(product);
                                  },

                                  onDelete: () {
                                    _deleteProduct(product);
                                  },
                                  showActions: _canManageProducts,
                                ),
                              );
                            }, childCount: _filteredProducts.length),
                          ),
                        ),
                ],
              ),
            ),

      // --------------------------------------------------------
      // ADD PRODUCT BUTTON
      // --------------------------------------------------------
      floatingActionButton: _canManageProducts
          ? FloatingActionButton.extended(
              onPressed: _addProduct,
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Product',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final total = _products.length;

    final rawMaterials = _products
        .where((product) => product.isRawMaterial)
        .length;

    final finishedProducts = _products
        .where((product) => product.isFinishedProduct)
        .length;

    final lowStock = _products.where((product) => product.isLowStock).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inventory Products',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Manage raw materials and finished products.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  icon: Icons.inventory_2_outlined,
                  title: 'Products',
                  value: total.toString(),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _summaryCard(
                  icon: Icons.factory_outlined,
                  title: 'Raw',
                  value: rawMaterials.toString(),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _summaryCard(
                  icon: Icons.check_circle_outline,
                  title: 'Finished',
                  value: finishedProducts.toString(),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _summaryCard(
                  icon: Icons.warning_amber_rounded,
                  title: 'Low',
                  value: lowStock.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Container(
      height: 92,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 21, color: primaryGreen),

          const SizedBox(height: 5),

          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
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
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search products...',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
          prefixIcon: Icon(Icons.search_rounded, color: primaryGreen),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                  },
                  icon: Icon(
                    Icons.clear_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: primaryGreen, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters() {
    final theme = Theme.of(context);
    final filters = ['All', 'Raw Materials', 'Finished Products', 'Low Stock'];

    return SizedBox(
      height: 45,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = _selectedFilter == filter;

          return ChoiceChip(
            label: Text(filter),
            selected: selected,
            onSelected: (_) {
              _changeFilter(filter);
            },
            selectedColor: theme.colorScheme.primary,
            backgroundColor: theme.cardColor,
            side: BorderSide(
              color: selected ? theme.colorScheme.primary : theme.dividerColor,
            ),
            labelStyle: theme.textTheme.labelMedium?.copyWith(
              color: selected
                  ? Colors.white
                  : theme.colorScheme.onSurface.withValues(alpha: 0.76),
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 5),
          );
        },
      ),
    );
  }

  // ============================================================
  // RESULT HEADER
  // ============================================================

  Widget _buildResultHeader() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Row(
        children: [
          Text(
            'Products',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(width: 7),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: primaryGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _filteredProducts.length.toString(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: primaryGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const Spacer(),

          if (_selectedFilter != 'All')
            Text(
              _selectedFilter,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // PRODUCT ICON
  // ============================================================

  Widget _productIcon(Product product) {
    final bool rawMaterial = product.isRawMaterial;

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: primaryGreen.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        rawMaterial ? Icons.factory_outlined : Icons.inventory_2_outlined,
        color: primaryGreen,
        size: 25,
      ),
    );
  }

  // ============================================================
  // PRODUCT DETAILS
  // ============================================================

  void _showProductDetails(Product product) {
    final status = _getStockStatus(product);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 25),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Product header
                  Row(
                    children: [
                      _productIcon(product),

                      const SizedBox(width: 13),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              product.categoryName ?? 'No category',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Stock status
                  _detailStatus(status),

                  const SizedBox(height: 16),

                  // Details
                  _detailRow(
                    'Item Type',
                    product.itemType,
                    Icons.category_outlined,
                  ),

                  _detailRow('Unit', product.unit, Icons.straighten_outlined),

                  _detailRow(
                    'Current Quantity',
                    '${_formatNumber(product.quantity)} ${product.unit}',
                    Icons.inventory_2_outlined,
                  ),

                  _detailRow(
                    'Minimum Stock',
                    '${_formatNumber(product.minimumStock)} ${product.unit}',
                    Icons.flag_outlined,
                  ),

                  if (product.barcode?.isNotEmpty == true)
                    _detailRow('Barcode', product.barcode!, Icons.qr_code_2),

                  if (product.description.isNotEmpty)
                    _detailRow(
                      'Description',
                      product.description,
                      Icons.description_outlined,
                    ),

                  const SizedBox(height: 15),

                  if (_canManageSuppliers) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _manageSuppliers(product);
                        },
                        icon: const Icon(Icons.people_outline),
                        label: const Text('Manage suppliers'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryGreen,
                          side: const BorderSide(color: primaryGreen),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                  ],

                  // Actions
                  if (_canManageProducts)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);

                              _editProduct(product);
                            },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryGreen,
                              side: const BorderSide(color: primaryGreen),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);

                              _deleteProduct(product);
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
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
          ),
        );
      },
    );
  }

  // ============================================================
  // DETAIL STATUS
  // ============================================================

  Widget _detailStatus(_StockStatus status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(status.icon, color: status.color),

          const SizedBox(width: 10),

          Text(
            status.label,
            style: TextStyle(color: status.color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget _detailRow(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: primaryGreen),

          const SizedBox(width: 11),

          SizedBox(
            width: 105,
            child: Text(
              title,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STOCK STATUS
  // ============================================================

  _StockStatus _getStockStatus(Product product) {
    if (product.quantity <= 0) {
      return _StockStatus(
        'Out of Stock',
        Icons.error_outline,
        Colors.red.shade700,
      );
    }

    if (product.quantity <= product.minimumStock * 0.5) {
      return _StockStatus(
        'Critical Stock',
        Icons.warning_rounded,
        Colors.red.shade700,
      );
    }

    if (product.quantity <= product.minimumStock) {
      return _StockStatus(
        'Low Stock',
        Icons.warning_amber_rounded,
        Colors.orange.shade700,
      );
    }

    return const _StockStatus(
      'Stock Available',
      Icons.check_circle_outline,
      primaryGreen,
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    final bool hasSearch = _searchController.text.trim().isNotEmpty;

    final bool hasFilter = _selectedFilter != 'All';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: primaryGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasSearch || hasFilter
                    ? Icons.search_off
                    : Icons.inventory_2_outlined,
                size: 40,
                color: primaryGreen,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              hasSearch
                  ? 'No products found'
                  : hasFilter
                  ? 'No matching products'
                  : 'No products yet',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 7),

            Text(
              hasSearch
                  ? 'Try a different search term.'
                  : hasFilter
                  ? 'There are no products in this filter.'
                  : 'Add your first inventory product to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                height: 1.4,
              ),
            ),

            if (!hasSearch && !hasFilter) ...[
              const SizedBox(height: 20),

              if (_canManageProducts)
                ElevatedButton.icon(
                  onPressed: _addProduct,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Product'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
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
    );
  }

  // ============================================================
  // BOTTOM SHEET OPTION
  // ============================================================

  Widget _bottomSheetOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    final color = iconColor ?? primaryGreen;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
      ),
      onTap: onTap,
    );
  }

  // ============================================================
  // FORMAT NUMBER
  // ============================================================

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          backgroundColor: isError ? Colors.red.shade700 : primaryGreen,

          behavior: SnackBarBehavior.floating,

          margin: const EdgeInsets.all(16),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }
}

// ============================================================
// STOCK STATUS MODEL
// ============================================================

class _StockStatus {
  final String label;
  final IconData icon;
  final Color color;

  const _StockStatus(this.label, this.icon, this.color);
}
