import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/supplier.dart';
import '../services/inventory_service.dart';

class WhatsAppSupplierOrderScreen extends StatefulWidget {
  const WhatsAppSupplierOrderScreen({super.key});

  @override
  State<WhatsAppSupplierOrderScreen> createState() =>
      _WhatsAppSupplierOrderScreenState();
}

class _WhatsAppSupplierOrderScreenState
    extends State<WhatsAppSupplierOrderScreen> {
  final InventoryService inventoryService = InventoryService();

  final TextEditingController searchController =
      TextEditingController();

  final TextEditingController quantityController =
      TextEditingController();

  final TextEditingController notesController =
      TextEditingController();

  List<Product> products = [];
  List<Product> filteredProducts = [];

  Product? selectedProduct;
  Supplier? selectedSupplier;

  double recommendedQuantity = 0;
  double orderQuantity = 0;

  bool isLoading = true;
  bool isLoadingSupplier = false;
  bool isOpeningWhatsApp = false;

  @override
  void initState() {
    super.initState();

    _loadProducts();

    searchController.addListener(_filterProducts);
    quantityController.addListener(_quantityChanged);
    notesController.addListener(_notesChanged);
  }

  @override
  void dispose() {
    searchController.dispose();
    quantityController.dispose();
    notesController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD PRODUCTS
  // ============================================================

  Future<void> _loadProducts() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final result =
          await inventoryService.getProducts();

      if (!mounted) return;

      setState(() {
        products = result;
        filteredProducts = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showMessage(
        'Failed to load products.',
        isError: true,
      );
    }
  }

  // ============================================================
  // SEARCH PRODUCTS
  // ============================================================

  void _filterProducts() {
    final query =
        searchController.text.trim().toLowerCase();

    if (!mounted) return;

    setState(() {
      if (query.isEmpty) {
        filteredProducts = products;
      } else {
        filteredProducts = products.where((product) {
          return product.name
                  .toLowerCase()
                  .contains(query) ||
              product.itemType
                  .toLowerCase()
                  .contains(query);
        }).toList();
      }
    });
  }

  // ============================================================
  // SELECT PRODUCT
  // ============================================================

  Future<void> _selectProduct(Product product) async {
    FocusScope.of(context).unfocus();

    setState(() {
      selectedProduct = product;
      selectedSupplier = null;
      recommendedQuantity = 0;
      orderQuantity = 0;
      isLoadingSupplier = true;

      quantityController.clear();
      notesController.clear();
    });

    try {
      final recommendation =
          inventoryService.getRecommendedRestockQuantity(
        product,
      );

      final supplier =
          await inventoryService.getPrimarySupplier(
        product.id,
      );

      if (!mounted) return;

      setState(() {
        recommendedQuantity = recommendation;

        // Automatically place the recommended quantity
        // in the input field initially.
        orderQuantity = recommendation;

        if (recommendation > 0) {
          quantityController.text =
              _formatNumber(recommendation);
        }

        selectedSupplier = supplier;
        isLoadingSupplier = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingSupplier = false;
      });

      _showMessage(
        'Could not load supplier information.',
        isError: true,
      );
    }
  }

  // ============================================================
  // QUANTITY LISTENER
  // ============================================================

  void _quantityChanged() {
    final parsed =
        double.tryParse(
      quantityController.text.trim(),
    );

    if (!mounted) return;

    final newQuantity = parsed ?? 0;

    if (newQuantity == orderQuantity) {
      return;
    }

    setState(() {
      orderQuantity = newQuantity;
    });
  }

  // ============================================================
  // NOTES LISTENER
  // ============================================================

  void _notesChanged() {
    // Rebuild message preview whenever notes change.
    if (!mounted) return;

    setState(() {});
  }

  // ============================================================
  // UPDATE QUANTITY
  // ============================================================

  void _updateQuantity(String value) {
    final parsed = double.tryParse(value);

    setState(() {
      orderQuantity = parsed ?? 0;
    });
  }

  // ============================================================
  // USE RECOMMENDED QUANTITY
  // ============================================================

  void _useRecommendedQuantity() {
    if (recommendedQuantity <= 0) {
      _showMessage(
        'There is currently no recommended restock quantity.',
        isError: true,
      );
      return;
    }

    setState(() {
      orderQuantity = recommendedQuantity;

      quantityController.text =
          _formatNumber(recommendedQuantity);

      quantityController.selection =
          TextSelection.fromPosition(
        TextPosition(
          offset: quantityController.text.length,
        ),
      );
    });
  }

  // ============================================================
  // WHATSAPP ORDER
  // ============================================================

  Future<void> _orderViaWhatsApp() async {
    if (selectedProduct == null) {
      _showMessage(
        'Please select a product first.',
        isError: true,
      );
      return;
    }

    if (selectedSupplier == null) {
      _showMessage(
        'No primary supplier is assigned to this product.',
        isError: true,
      );
      return;
    }

    if (selectedSupplier!.phone.trim().isEmpty) {
      _showMessage(
        'The selected supplier does not have a phone number.',
        isError: true,
      );
      return;
    }

    final quantity =
        double.tryParse(
      quantityController.text.trim(),
    );

    if (quantity == null || quantity <= 0) {
      _showMessage(
        'Please enter a valid order quantity.',
        isError: true,
      );
      return;
    }

    setState(() {
      isOpeningWhatsApp = true;
    });

    try {
      // IMPORTANT:
      // Use the CUSTOM supplier order method.
      //
      // This sends:
      // 1. The exact quantity entered by the user.
      // 2. The notes entered by the user.
      //
      // It does NOT replace the quantity with the
      // automatic recommended quantity.

      final success =
          await inventoryService.sendCustomSupplierOrder(
        productId: selectedProduct!.id,
        quantity: quantity,
        notes: notesController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        _showMessage(
          'WhatsApp opened with your supplier order.',
        );
      } else {
        _showMessage(
          'Could not open WhatsApp. Please check the supplier phone number.',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not open WhatsApp.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isOpeningWhatsApp = false;
        });
      }
    }
  }

  // ============================================================
  // PREVIEW MESSAGE
  // ============================================================

  String _buildMessage() {
    if (selectedProduct == null ||
        selectedSupplier == null) {
      return '';
    }

    final quantity =
        double.tryParse(
      quantityController.text.trim(),
    ) ??
            0;

    final product = selectedProduct!;
    final supplier = selectedSupplier!;

    String message =
        'Hello ${supplier.name},\n\n'
        'We would like to place a restock order for the following item:\n\n'
        'Product: ${product.name}\n'
        'Item Type: ${product.itemType}\n'
        'Current Stock: '
        '${_formatNumber(product.quantity)} '
        '${product.unit}\n'
        'Minimum Stock: '
        '${_formatNumber(product.minimumStock)} '
        '${product.unit}\n'
        'Order Quantity: '
        '${_formatNumber(quantity)} '
        '${product.unit}\n';

    final notes =
        notesController.text.trim();

    if (notes.isNotEmpty) {
      message +=
          'Notes: $notes\n';
    }

    message +=
        '\nPlease confirm availability and expected delivery time.\n\n'
        'Thank you.';

    return message;
  }

  // ============================================================
  // CONFIRM ORDER
  // ============================================================

  Future<void> _confirmOrder() async {
    if (selectedProduct == null ||
        selectedSupplier == null) {
      _showMessage(
        'Please select a product with an assigned supplier.',
        isError: true,
      );
      return;
    }

    final quantity =
        double.tryParse(
      quantityController.text.trim(),
    );

    if (quantity == null || quantity <= 0) {
      _showMessage(
        'Enter a valid order quantity.',
        isError: true,
      );
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Confirm Supplier Order',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),

          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _dialogRow(
                  'Product',
                  selectedProduct!.name,
                ),

                _dialogRow(
                  'Supplier',
                  selectedSupplier!.name,
                ),

                _dialogRow(
                  'Quantity',
                  '${_formatNumber(quantity)} '
                      '${selectedProduct!.unit}',
                ),

                if (notesController.text
                    .trim()
                    .isNotEmpty)
                  _dialogRow(
                    'Notes',
                    notesController.text.trim(),
                  ),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                false,
              ),
              child: const Text('Cancel'),
            ),

            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),

              icon: const Icon(
                Icons.chat,
                size: 18,
              ),

              label: const Text(
                'Open WhatsApp',
              ),

              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF25D366),
                foregroundColor:
                    Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _orderViaWhatsApp();
    }
  }

  Widget _dialogRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 10,
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,

            child: Text(
              label,

              style: TextStyle(
                fontSize: 13,
                color:
                    Colors.grey.shade600,
              ),
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              value,

              style: const TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  bool _isLowStock(Product product) {
    return product.quantity <=
        product.minimumStock;
  }

  bool _isCritical(Product product) {
    return product.quantity <=
        product.minimumStock * 0.5;
  }

  Color _stockColor(Product product) {
    if (_isCritical(product)) {
      return Colors.red;
    }

    if (_isLowStock(product)) {
      return Colors.orange;
    }

    return const Color(0xFF379805);
  }

  String _stockStatus(Product product) {
    if (_isCritical(product)) {
      return 'CRITICAL';
    }

    if (_isLowStock(product)) {
      return 'LOW STOCK';
    }

    return 'NORMAL';
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
          backgroundColor: isError
              ? Colors.red.shade700
              : const Color(0xFF379805),
        ),
      );
  }

  void _clearSelection() {
    setState(() {
      selectedProduct = null;
      selectedSupplier = null;
      recommendedQuantity = 0;
      orderQuantity = 0;

      quantityController.clear();
      notesController.clear();
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F7FA),

      appBar: AppBar(
        backgroundColor:
            Colors.white,
        foregroundColor:
            Colors.black87,
        elevation: 0,

        title: const Text(
          'WhatsApp Supplier Order',
          style: TextStyle(
            fontSize: 19,
            fontWeight:
                FontWeight.w700,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: isLoading
                ? null
                : _loadProducts,
            icon:
                const Icon(Icons.refresh),
          ),

          const SizedBox(width: 4),
        ],
      ),

      body: isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color:
                    Color(0xFF379805),
              ),
            )
          : RefreshIndicator(
              color:
                  const Color(0xFF379805),
              onRefresh:
                  _loadProducts,
              child:
                  _buildBody(),
            ),
    );
  }

  Widget _buildBody() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),

      padding:
          const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        30,
      ),

      children: [
        _buildHeader(),

        const SizedBox(height: 18),

        _buildProductSearch(),

        const SizedBox(height: 12),

        if (selectedProduct == null)
          _buildProductList()
        else
          _buildOrderForm(),
      ],
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      padding:
          const EdgeInsets.all(20),

      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xFF379805),
            Color(0xFF5ABF27),
          ],

          begin:
              Alignment.topLeft,

          end:
              Alignment.bottomRight,
        ),

        borderRadius:
            BorderRadius.circular(22),

        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF379805,
            ).withValues(alpha: 0.18),

            blurRadius: 15,

            offset:
                const Offset(0, 7),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,

            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(alpha: 0.18),

              shape:
                  BoxShape.circle,
            ),

            child: const Icon(
              Icons.chat_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  'Order Stock via WhatsApp',

                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Select a product and contact its supplier directly.',

                  style: TextStyle(
                    color: Colors.white
                        .withValues(alpha: 0.88),
                    fontSize: 12.5,
                    height: 1.35,
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
  // PRODUCT SEARCH
  // ============================================================

  Widget _buildProductSearch() {
    return TextField(
      controller:
          searchController,

      decoration:
          InputDecoration(
        hintText:
            'Search product to order...',

        prefixIcon:
            const Icon(
          Icons.search,
          color:
              Color(0xFF379805),
        ),

        suffixIcon:
            searchController.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      searchController
                          .clear();
                    },
                    icon:
                        const Icon(
                      Icons.clear,
                    ),
                  )
                : null,

        filled: true,

        fillColor:
            Colors.white,

        contentPadding:
            const EdgeInsets
                .symmetric(
          vertical: 15,
        ),

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            15,
          ),
          borderSide:
              BorderSide.none,
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            15,
          ),
          borderSide:
              BorderSide(
            color:
                Colors.grey.shade200,
          ),
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            15,
          ),
          borderSide:
              const BorderSide(
            color:
                Color(0xFF379805),
            width: 1.4,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PRODUCT LIST
  // ============================================================

  Widget _buildProductList() {
    if (filteredProducts.isEmpty) {
      return _buildNoProducts();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        const Text(
          'Select Product',

          style: TextStyle(
            fontSize: 16,
            fontWeight:
                FontWeight.w700,
          ),
        ),

        const SizedBox(height: 10),

        ...filteredProducts.map(
          (product) =>
              _buildProductCard(
            product,
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(
    Product product,
  ) {
    final statusColor =
        _stockColor(product);

    final status =
        _stockStatus(product);

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 11,
      ),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              Colors.grey.shade200,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: 0.03),

            blurRadius: 10,

            offset:
                const Offset(0, 3),
          ),
        ],
      ),

      child: Material(
        color:
            Colors.transparent,

        child: InkWell(
          borderRadius:
              BorderRadius.circular(
            18,
          ),

          onTap: () =>
              _selectProduct(
            product,
          ),

          child: Padding(
            padding:
                const EdgeInsets.all(
              15,
            ),

            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,

                  decoration:
                      BoxDecoration(
                    color: statusColor
                        .withValues(alpha: 
                      0.10,
                    ),

                    borderRadius:
                        BorderRadius
                            .circular(
                      14,
                    ),
                  ),

                  child: Icon(
                    Icons
                        .inventory_2_outlined,

                    color:
                        statusColor,

                    size: 24,
                  ),
                ),

                const SizedBox(
                  width: 13,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [
                      Text(
                        product.name,

                        maxLines: 1,

                        overflow:
                            TextOverflow
                                .ellipsis,

                        style:
                            const TextStyle(
                          fontSize: 15,
                          fontWeight:
                              FontWeight
                                  .w700,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        product.itemType,

                        style: TextStyle(
                          fontSize: 12,
                          color: Colors
                              .grey
                              .shade600,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      Row(
                        children: [
                          Text(
                            'Stock: '
                            '${_formatNumber(product.quantity)} '
                            '${product.unit}',

                            style:
                                TextStyle(
                              fontSize:
                                  11.5,
                              color:
                                  statusColor,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),

                          const SizedBox(
                            width: 8,
                          ),

                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),

                            decoration:
                                BoxDecoration(
                              color:
                                  statusColor
                                      .withValues(alpha: 
                                0.10,
                              ),

                              borderRadius:
                                  BorderRadius
                                      .circular(
                                6,
                              ),
                            ),

                            child: Text(
                              status,

                              style:
                                  TextStyle(
                                color:
                                    statusColor,
                                fontSize:
                                    8.5,
                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons
                      .arrow_forward_ios_rounded,

                  size: 16,

                  color:
                      Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ORDER FORM
  // ============================================================

  Widget _buildOrderForm() {
    final product =
        selectedProduct!;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        _buildSelectedProduct(
          product,
        ),

        const SizedBox(
          height: 14,
        ),

        _buildSupplierCard(),

        const SizedBox(
          height: 14,
        ),

        _buildStockInformation(
          product,
        ),

        const SizedBox(
          height: 14,
        ),

        _buildQuantitySection(
          product,
        ),

        const SizedBox(
          height: 14,
        ),

        _buildNotesSection(),

        const SizedBox(
          height: 14,
        ),

        _buildMessagePreview(),

        const SizedBox(
          height: 18,
        ),

        _buildOrderButton(),

        const SizedBox(
          height: 10,
        ),

        SizedBox(
          width:
              double.infinity,

          child:
              TextButton.icon(
            onPressed:
                _clearSelection,

            icon: const Icon(
              Icons.arrow_back,
            ),

            label: const Text(
              'Choose Another Product',
            ),

            style:
                TextButton.styleFrom(
              foregroundColor:
                  const Color(
                0xFF379805,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SELECTED PRODUCT
  // ============================================================

  Widget _buildSelectedProduct(
    Product product,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        17,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              const Color(
            0xFF379805,
          ).withValues(alpha: 0.18),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,

            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFF379805,
              ).withValues(alpha: 0.10),

              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),

            child: const Icon(
              Icons
                  .inventory_2_rounded,

              color:
                  Color(0xFF379805),

              size: 26,
            ),
          ),

          const SizedBox(
            width: 13,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [
                Text(
                  product.name,

                  style:
                      const TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight
                            .w800,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  product.itemType,

                  style:
                      TextStyle(
                    fontSize: 12,
                    color: Colors
                        .grey
                        .shade600,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed:
                _clearSelection,

            icon:
                const Icon(
              Icons.close,
              color:
                  Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUPPLIER CARD
  // ============================================================

  Widget _buildSupplierCard() {
    if (isLoadingSupplier) {
      return Container(
        padding:
            const EdgeInsets.all(
          20,
        ),

        decoration:
            BoxDecoration(
          color:
              Colors.white,

          borderRadius:
              BorderRadius.circular(
            18,
          ),
        ),

        child: const Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,

              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
                color:
                    Color(0xFF379805),
              ),
            ),

            SizedBox(
              width: 12,
            ),

            Text(
              'Loading supplier information...',
              style: TextStyle(
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (selectedSupplier == null) {
      return Container(
        padding:
            const EdgeInsets.all(
          18,
        ),

        decoration:
            BoxDecoration(
          color:
              Colors.orange.shade50,

          borderRadius:
              BorderRadius.circular(
            18,
          ),

          border:
              Border.all(
            color:
                Colors.orange.shade200,
          ),
        ),

        child: Row(
          children: [
            Icon(
              Icons
                  .warning_amber_rounded,

              color:
                  Colors.orange.shade700,
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child: Text(
                'No primary supplier is assigned to this product.',

                style:
                    TextStyle(
                  fontSize: 13,
                  color: Colors
                      .orange
                      .shade800,
                  fontWeight:
                      FontWeight
                          .w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding:
          const EdgeInsets.all(
        17,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: 0.03),

            blurRadius: 10,

            offset:
                const Offset(0, 3),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              const Icon(
                Icons
                    .business_rounded,

                color:
                    Color(0xFF379805),

                size: 21,
              ),

              const SizedBox(
                width: 8,
              ),

              const Text(
                'Primary Supplier',

                style:
                    TextStyle(
                  fontSize: 15,
                  fontWeight:
                      FontWeight
                          .w700,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          Row(
            children: [
              Container(
                width: 45,
                height: 45,

                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFF25D366,
                  ).withValues(alpha: 
                    0.10,
                  ),

                  shape:
                      BoxShape.circle,
                ),

                child:
                    const Icon(
                  Icons
                      .storefront_outlined,

                  color:
                      Color(0xFF25D366),
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [
                    Text(
                      selectedSupplier!
                          .name,

                      style:
                          const TextStyle(
                        fontSize: 14.5,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      selectedSupplier!
                              .phone
                              .isEmpty
                          ? 'No phone number'
                          : selectedSupplier!
                              .phone,

                      style:
                          TextStyle(
                        fontSize: 12,
                        color: Colors
                            .grey
                            .shade600,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFF25D366,
                  ).withValues(alpha: 
                    0.10,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),
                ),

                child:
                    const Text(
                  'SUPPLIER',

                  style:
                      TextStyle(
                    color:
                        Color(0xFF25D366),
                    fontSize: 8.5,
                    fontWeight:
                        FontWeight
                            .w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STOCK INFORMATION
  // ============================================================

  Widget _buildStockInformation(
    Product product,
  ) {
    final statusColor =
        _stockColor(product);

    return Container(
      padding:
          const EdgeInsets.all(
        17,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,

        children: [
          const Text(
            'Stock Information',

            style:
                TextStyle(
              fontSize: 15,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          Row(
            children: [
              Expanded(
                child:
                    _stockInfoItem(
                  title:
                      'Current Stock',

                  value:
                      '${_formatNumber(product.quantity)} '
                      '${product.unit}',

                  icon:
                      Icons.inventory_2_outlined,

                  color:
                      statusColor,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child:
                    _stockInfoItem(
                  title:
                      'Minimum Stock',

                  value:
                      '${_formatNumber(product.minimumStock)} '
                      '${product.unit}',

                  icon:
                      Icons.low_priority_rounded,

                  color:
                      Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stockInfoItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(
        13,
      ),

      decoration:
          BoxDecoration(
        color:
            color.withValues(alpha: 
          0.06,
        ),

        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,

        children: [
          Icon(
            icon,

            color:
                color,

            size: 20,
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            title,

            style:
                TextStyle(
              fontSize: 10.5,
              color: Colors
                  .grey
                  .shade600,
            ),
          ),

          const SizedBox(
            height: 3,
          ),

          Text(
            value,

            style:
                TextStyle(
              fontSize: 13,
              color:
                  color,
              fontWeight:
                  FontWeight
                      .w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUANTITY SECTION
  // ============================================================

  Widget _buildQuantitySection(
    Product product,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        17,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,

        children: [
          const Text(
            'Order Quantity',

            style:
                TextStyle(
              fontSize: 15,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            'Enter the exact quantity you want to order.',

            style:
                TextStyle(
              fontSize: 12,
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(
            height: 13,
          ),

          TextField(
            controller:
                quantityController,

            keyboardType:
                const TextInputType
                    .numberWithOptions(
              decimal: true,
            ),

            onChanged:
                _updateQuantity,

            decoration:
                InputDecoration(
              labelText:
                  'Quantity',

              suffixText:
                  product.unit,

              prefixIcon:
                  const Icon(
                Icons
                    .shopping_cart_outlined,

                color:
                    Color(0xFF379805),
              ),

              filled: true,

              fillColor:
                  const Color(
                0xFFF8F9FA,
              ),

              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),

                borderSide:
                    BorderSide.none,
              ),

              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),

                borderSide:
                    BorderSide(
                  color:
                      Colors.grey.shade200,
                ),
              ),

              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),

                borderSide:
                    const BorderSide(
                  color:
                      Color(0xFF379805),
                  width: 1.3,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 11,
          ),

          InkWell(
            onTap:
                _useRecommendedQuantity,

            borderRadius:
                BorderRadius.circular(
              12,
            ),

            child: Container(
              width:
                  double.infinity,

              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 13,
                vertical: 11,
              ),

              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFF379805,
                ).withValues(alpha: 
                  0.06,
                ),

                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),

              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,

                    color:
                        Color(0xFF379805),

                    size: 18,
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    child: Text(
                      'Recommended: '
                      '${_formatNumber(recommendedQuantity)} '
                      '${product.unit}',

                      style:
                          const TextStyle(
                        color:
                            Color(0xFF379805),
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),

                  const Text(
                    'Use',

                    style:
                        TextStyle(
                      color:
                          Color(0xFF379805),
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NOTES
  // ============================================================

  Widget _buildNotesSection() {
    return Container(
      padding:
          const EdgeInsets.all(
        17,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,

        children: [
          const Text(
            'Order Notes',

            style:
                TextStyle(
              fontSize: 15,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            'Optional information to include in the order.',

            style:
                TextStyle(
              fontSize: 12,
              color:
                  Colors.grey.shade600,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          TextField(
            controller:
                notesController,

            maxLines: 3,

            decoration:
                InputDecoration(
              hintText:
                  'e.g. Please deliver as soon as possible...',

              prefixIcon:
                  const Padding(
                padding:
                    EdgeInsets.only(
                  bottom: 40,
                ),

                child:
                    Icon(
                  Icons.notes_outlined,

                  color:
                      Color(0xFF379805),
                ),
              ),

              filled: true,

              fillColor:
                  const Color(
                0xFFF8F9FA,
              ),

              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),

                borderSide:
                    BorderSide.none,
              ),

              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),

                borderSide:
                    BorderSide(
                  color:
                      Colors.grey.shade200,
                ),
              ),

              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),

                borderSide:
                    const BorderSide(
                  color:
                      Color(0xFF379805),
                  width: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGE PREVIEW
  // ============================================================

  Widget _buildMessagePreview() {
    final message =
        _buildMessage();

    return Container(
      padding:
          const EdgeInsets.all(
        17,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,

        children: [
          Row(
            children: [
              const Icon(
                Icons.preview_outlined,

                color:
                    Color(0xFF379805),

                size: 20,
              ),

              const SizedBox(
                width: 8,
              ),

              const Text(
                'WhatsApp Message Preview',

                style:
                    TextStyle(
                  fontSize: 15,
                  fontWeight:
                      FontWeight
                          .w700,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 13,
          ),

          Container(
            width:
                double.infinity,

            padding:
                const EdgeInsets.all(
              14,
            ),

            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFF1F8EE,
              ),

              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),

            child: message.isEmpty
                ? Text(
                    'Select a product and supplier to preview the message.',

                    style:
                        TextStyle(
                      fontSize: 12,
                      color: Colors
                          .grey
                          .shade600,
                    ),
                  )
                : Text(
                    message,

                    style:
                        const TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color:
                          Colors.black87,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ORDER BUTTON
  // ============================================================

  Widget _buildOrderButton() {
    final canOrder =
        selectedProduct != null &&
        selectedSupplier != null &&
        selectedSupplier!
            .phone
            .trim()
            .isNotEmpty &&
        orderQuantity > 0;

    return SizedBox(
      width:
          double.infinity,

      height: 54,

      child:
          ElevatedButton.icon(
        onPressed:
            canOrder &&
                    !isOpeningWhatsApp
                ? _confirmOrder
                : null,

        icon:
            isOpeningWhatsApp
                ? const SizedBox(
                    width: 20,
                    height: 20,

                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,

                      valueColor:
                          AlwaysStoppedAnimation<
                              Color>(
                        Colors.white,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.chat_rounded,
                    size: 22,
                  ),

        label:
            Text(
          isOpeningWhatsApp
              ? 'Opening WhatsApp...'
              : 'Order via WhatsApp',

          style:
              const TextStyle(
            fontSize: 15,
            fontWeight:
                FontWeight.w800,
          ),
        ),

        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              const Color(
            0xFF25D366,
          ),

          foregroundColor:
              Colors.white,

          disabledBackgroundColor:
              Colors.grey.shade300,

          disabledForegroundColor:
              Colors.grey.shade600,

          elevation: 0,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              15,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NO PRODUCTS
  // ============================================================

  Widget _buildNoProducts() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 50,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),

      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,

            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFF379805,
              ).withValues(alpha: 
                0.08,
              ),

              shape:
                  BoxShape.circle,
            ),

            child: const Icon(
              Icons
                  .inventory_2_outlined,

              size: 40,

              color:
                  Color(0xFF379805),
            ),
          ),

          const SizedBox(
            height: 17,
          ),

          const Text(
            'No Products Found',

            style:
                TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          Text(
            searchController
                    .text
                    .isEmpty
                ? 'Add products to your inventory before placing supplier orders.'
                : 'No products match your search.',

            textAlign:
                TextAlign.center,

            style:
                TextStyle(
              fontSize: 13,
              height: 1.5,
              color:
                  Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

