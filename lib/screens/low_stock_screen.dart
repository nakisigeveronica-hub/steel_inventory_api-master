import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/supplier.dart';
import '../services/inventory_service.dart';

class LowStockScreen extends StatefulWidget {
  const LowStockScreen({super.key});

  @override
  State<LowStockScreen> createState() =>
      _LowStockScreenState();
}

class _LowStockScreenState extends State<LowStockScreen> {
  final InventoryService inventoryService =
      InventoryService();

  final TextEditingController searchController =
      TextEditingController();

  List<Product> lowStockProducts = [];
  List<Product> filteredProducts = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadLowStockProducts();

    searchController.addListener(
      filterProducts,
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD LOW STOCK PRODUCTS
  // ============================================================

  Future<void> loadLowStockProducts() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final products =
          await inventoryService
              .getLowStockProducts();

      if (!mounted) return;

      setState(() {
        lowStockProducts = products;
        filteredProducts = products;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(
        'Unable to load low stock products.',
        isError: true,
      );
    }
  }

  // ============================================================
  // SEARCH / FILTER
  // ============================================================

  void filterProducts() {
    final keyword =
        searchController.text.trim().toLowerCase();

    if (!mounted) return;

    setState(() {
      if (keyword.isEmpty) {
        filteredProducts = lowStockProducts;
      } else {
        filteredProducts =
            lowStockProducts.where((product) {
          final name =
              product.name.toLowerCase();

          final type =
              product.itemType.toLowerCase();

          return name.contains(keyword) ||
              type.contains(keyword);
        }).toList();
      }
    });
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // CHECK CRITICAL STOCK
  // ============================================================

  bool isCritical(Product product) {
    return product.quantity <=
        product.minimumStock * 0.5;
  }

  // ============================================================
  // RESTOCK PRODUCT
  // ============================================================

  Future<void> orderRestock(Product product) async {
    final supplier =
        await inventoryService.getPrimarySupplier(
      product.id,
    );

    if (!mounted) return;

    if (supplier == null) {
      showMessage(
        'No primary supplier is linked to this product.',
        isError: true,
      );
      return;
    }

    if (supplier.phone.trim().isEmpty) {
      showMessage(
        'The supplier does not have a phone number.',
        isError: true,
      );
      return;
    }

    final recommended =
        inventoryService
            .getRecommendedRestockQuantity(
      product,
    );

    if (recommended <= 0) {
      showMessage(
        'No restock is currently required.',
      );
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Order Restock',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              _dialogRow(
                'Supplier',
                supplier.name,
              ),

              _dialogRow(
                'Current Stock',
                '${formatNumber(product.quantity)} '
                    '${product.unit}',
              ),

              _dialogRow(
                'Minimum Stock',
                '${formatNumber(product.minimumStock)} '
                    '${product.unit}',
              ),

              _dialogRow(
                'Recommended Order',
                '${formatNumber(recommended)} '
                    '${product.unit}',
              ),

              const SizedBox(height: 12),

              Text(
                'WhatsApp will open with a prepared '
                'restock message.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              icon: const Icon(
                Icons.chat,
                size: 18,
              ),
              label: const Text('Open WhatsApp'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final success =
        await inventoryService
            .sendRestockOrder(product.id);

    if (!mounted) return;

    if (success) {
      showMessage(
        'WhatsApp opened for ${supplier.name}.',
      );
    } else {
      showMessage(
        'Unable to open WhatsApp.',
        isError: true,
      );
    }
  }

  // ============================================================
  // FORMAT NUMBER
  // ============================================================

  String formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value
          .toInt()
          .toString();
    }

    return value.toStringAsFixed(1);
  }

  // ============================================================
  // DIALOG ROW
  // ============================================================

  Widget _dialogRow(
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final criticalCount =
        lowStockProducts
            .where(isCritical)
            .length;

    final lowCount =
        lowStockProducts.length -
        criticalCount;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F7FA),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,

        title: const Text(
          'Low Stock',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                loading
                    ? null
                    : loadLowStockProducts,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh:
            loadLowStockProducts,

        child: loading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : ListView(
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
                  // ==================================================
                  // HEADER
                  // ==================================================

                  buildHeader(
                    criticalCount,
                    lowCount,
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // SEARCH
                  // ==================================================

                  buildSearch(),

                  const SizedBox(height: 18),

                  // ==================================================
                  // PRODUCTS
                  // ==================================================

                  if (filteredProducts.isEmpty)
                    buildEmptyState()
                  else
                    ...filteredProducts.map(
                      (product) =>
                          buildProductCard(
                        product,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget buildHeader(
    int criticalCount,
    int lowCount,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(20),

      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Color(0xFF379805),
            Color(0xFF257003),
          ],
        ),

        borderRadius:
            BorderRadius.circular(22),

        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            offset:
                Offset(0, 6),
            color:
                Colors.black12,
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,

                decoration:
                    BoxDecoration(
                  color:
                      Colors.white.withValues(alpha: 
                    0.18,
                  ),
                  shape:
                      BoxShape.circle,
                ),

                child:
                    const Icon(
                  Icons.inventory_2_outlined,
                  color:
                      Colors.white,
                  size: 27,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock Monitoring',
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize:
                            19,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    SizedBox(
                      height: 4,
                    ),
                    Text(
                      'Products requiring attention',
                      style:
                          TextStyle(
                        color:
                            Colors.white70,
                        fontSize:
                            13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 20,
          ),

          Row(
            children: [
              Expanded(
                child:
                    stockSummary(
                  title:
                      'Critical',
                  value:
                      criticalCount,
                  icon:
                      Icons.crisis_alert,
                  isCritical:
                      true,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child:
                    stockSummary(
                  title:
                      'Low Stock',
                  value:
                      lowCount,
                  icon:
                      Icons.warning_amber_rounded,
                  isCritical:
                      false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STOCK SUMMARY
  // ============================================================

  Widget stockSummary({
    required String title,
    required int value,
    required IconData icon,
    required bool isCritical,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 12,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white.withValues(alpha: 
          0.14,
        ),
        borderRadius:
            BorderRadius.circular(15),
      ),

      child: Row(
        children: [
          Icon(
            icon,
            color:
                Colors.white,
            size: 21,
          ),

          const SizedBox(
            width: 9,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize:
                        20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Colors.white70,
                    fontSize:
                        11,
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
  // SEARCH
  // ============================================================

  Widget buildSearch() {
    return TextField(
      controller:
          searchController,

      decoration:
          InputDecoration(
        hintText:
            'Search low stock products...',

        prefixIcon:
            const Icon(
          Icons.search,
        ),

        suffixIcon:
            searchController
                    .text
                    .isNotEmpty
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
            const EdgeInsets.symmetric(
          vertical: 15,
        ),

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          borderSide:
              BorderSide.none,
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          borderSide:
              BorderSide.none,
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          borderSide:
              const BorderSide(
            color:
                Color(0xFF379805),
            width:
                1.2,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PRODUCT CARD
  // ============================================================

  Widget buildProductCard(
    Product product,
  ) {
    final critical =
        isCritical(product);

    final recommended =
        inventoryService
            .getRecommendedRestockQuantity(
      product,
    );

    return FutureBuilder<Supplier?>(
      future:
          inventoryService
              .getPrimarySupplier(
        product.id,
      ),

      builder:
          (context, snapshot) {
        final supplier =
            snapshot.data;

        return Card(
          elevation: 1.5,

          margin:
              const EdgeInsets.only(
            bottom: 14,
          ),

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
          ),

          child: Padding(
            padding:
                const EdgeInsets.all(
              16,
            ),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                // ================================================
                // PRODUCT HEADER
                // ================================================

                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Container(
                      width: 48,
                      height: 48,

                      decoration:
                          BoxDecoration(
                        color: critical
                            ? Colors.red
                                .withValues(alpha: 
                                0.1,
                              )
                            : Colors.orange
                                .withValues(alpha: 
                                0.1,
                              ),
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),

                      child: Icon(
                        critical
                            ? Icons
                                .crisis_alert
                            : Icons
                                .warning_amber_rounded,

                        color: critical
                            ? Colors.red
                            : Colors.orange,

                        size: 25,
                      ),
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          Text(
                            product.name,
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                const TextStyle(
                              fontSize:
                                  16,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          Text(
                            product.itemType,
                            style:
                                TextStyle(
                              color:
                                  Colors.grey.shade600,
                              fontSize:
                                  12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),

                      decoration:
                          BoxDecoration(
                        color: critical
                            ? Colors.red
                                .withValues(alpha: 
                                0.1,
                              )
                            : Colors.orange
                                .withValues(alpha: 
                                0.1,
                              ),
                        borderRadius:
                            BorderRadius.circular(
                          20,
                        ),
                      ),

                      child: Text(
                        critical
                            ? 'CRITICAL'
                            : 'LOW',

                        style:
                            TextStyle(
                          color: critical
                              ? Colors.red
                              : Colors.orange,
                          fontSize:
                              10,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 18,
                ),

                // ================================================
                // STOCK INFORMATION
                // ================================================

                Row(
                  children: [
                    Expanded(
                      child:
                          stockInfo(
                        title:
                            'Current Stock',
                        value:
                            '${formatNumber(product.quantity)} '
                            '${product.unit}',
                        icon:
                            Icons.inventory_2_outlined,
                        critical:
                            critical,
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child:
                          stockInfo(
                        title:
                            'Minimum Stock',
                        value:
                            '${formatNumber(product.minimumStock)} '
                            '${product.unit}',
                        icon:
                            Icons.flag_outlined,
                        critical:
                            false,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 10,
                ),

                // ================================================
                // RESTOCK RECOMMENDATION
                // ================================================

                Container(
                  padding:
                      const EdgeInsets.all(
                    13,
                  ),

                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFF5F7FA,
                    ),

                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),

                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,

                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFF379805,
                          ).withValues(alpha: 
                            0.1,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                        ),

                        child:
                            const Icon(
                          Icons
                              .auto_awesome,
                          color:
                              Color(
                            0xFF379805,
                          ),
                          size: 21,
                        ),
                      ),

                      const SizedBox(
                        width: 11,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [
                            const Text(
                              'Smart Restock Recommendation',
                              style:
                                  TextStyle(
                                fontSize:
                                    12,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),

                            const SizedBox(
                              height: 3,
                            ),

                            Text(
                              recommended > 0
                                  ? 'Order ${formatNumber(recommended)} '
                                      '${product.unit} to reach the target stock level.'
                                  : 'No restock required.',
                              style:
                                  TextStyle(
                                color:
                                    Colors.grey.shade600,
                                fontSize:
                                    11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 13,
                ),

                // ================================================
                // SUPPLIER
                // ================================================

                if (supplier != null)
                  Container(
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),

                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white,

                      borderRadius:
                          BorderRadius.circular(
                        13,
                      ),

                      border:
                          Border.all(
                        color:
                            Colors.grey.shade200,
                      ),
                    ),

                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,

                          decoration:
                              BoxDecoration(
                            color:
                                Colors.blue.withValues(alpha: 
                              0.1,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              10,
                            ),
                          ),

                          child:
                              const Icon(
                            Icons
                                .local_shipping_outlined,
                            color:
                                Colors.blue,
                            size: 20,
                          ),
                        ),

                        const SizedBox(
                          width: 10,
                        ),

                        Expanded(
                          child:
                              Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Primary Supplier',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.grey.shade600,
                                  fontSize:
                                      11,
                                ),
                              ),

                              const SizedBox(
                                height: 2,
                              ),

                              Text(
                                supplier.name,
                                maxLines:
                                    1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.w600,
                                  fontSize:
                                      13,
                                ),
                              ),

                              if (supplier
                                  .phone
                                  .isNotEmpty)
                                Text(
                                  supplier.phone,
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.grey.shade600,
                                    fontSize:
                                        11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),

                    decoration:
                        BoxDecoration(
                      color:
                          Colors.orange.withValues(alpha: 
                        0.08,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        13,
                      ),
                    ),

                    child: Row(
                      children: [
                        const Icon(
                          Icons
                              .info_outline,
                          color:
                              Colors.orange,
                          size: 20,
                        ),

                        const SizedBox(
                          width: 9,
                        ),

                        Expanded(
                          child: Text(
                            'No primary supplier linked to this product.',
                            style:
                                TextStyle(
                              color:
                                  Colors.grey.shade700,
                              fontSize:
                                  12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(
                  height: 14,
                ),

                // ================================================
                // ORDER BUTTON
                // ================================================

                SizedBox(
                  width:
                      double.infinity,

                  height: 46,

                  child:
                      ElevatedButton.icon(
                    onPressed:
                        supplier == null ||
                                supplier
                                    .phone
                                    .trim()
                                    .isEmpty ||
                                recommended <= 0
                            ? null
                            : () {
                                orderRestock(
                                  product,
                                );
                              },

                    icon:
                        const Icon(
                      Icons.chat,
                      size: 19,
                    ),

                    label:
                        Text(
                      supplier == null
                          ? 'No Supplier Available'
                          : 'Order Restock via WhatsApp',
                    ),

                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(
                        0xFF379805,
                      ),
                      foregroundColor:
                          Colors.white,

                      disabledBackgroundColor:
                          Colors.grey.shade200,

                      disabledForegroundColor:
                          Colors.grey.shade500,

                      elevation:
                          0,

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // STOCK INFO
  // ============================================================

  Widget stockInfo({
    required String title,
    required String value,
    required IconData icon,
    required bool critical,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(
        12,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.grey.shade50,

        borderRadius:
            BorderRadius.circular(
          13,
        ),

        border:
            Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),

      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: critical
                ? Colors.red
                : Colors.grey.shade700,
          ),

          const SizedBox(
            width: 8,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      TextStyle(
                    color:
                        Colors.grey.shade600,
                    fontSize:
                        10,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      TextStyle(
                    color: critical
                        ? Colors.red
                        : Colors.black87,
                    fontSize:
                        13,
                    fontWeight:
                        FontWeight.bold,
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
  // EMPTY STATE
  // ============================================================

  Widget buildEmptyState() {
    final searching =
        searchController.text
            .trim()
            .isNotEmpty;

    return Padding(
      padding:
          const EdgeInsets.only(
        top: 70,
      ),

      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,

            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFF379805,
              ).withValues(alpha: 
                0.1,
              ),
              shape:
                  BoxShape.circle,
            ),

            child:
                const Icon(
              Icons
                  .inventory_2_outlined,
              size: 40,
              color:
                  Color(
                0xFF379805,
              ),
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          Text(
            searching
                ? 'No products found'
                : 'No low stock products',
            style:
                const TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          Text(
            searching
                ? 'Try another search term.'
                : 'Great! Your inventory is currently above the minimum stock levels.',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  Colors.grey.shade600,
              fontSize:
                  13,
            ),
          ),
        ],
      ),
    );
  }
}

