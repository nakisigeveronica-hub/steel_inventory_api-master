import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../services/inventory_service.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final InventoryService inventoryService = InventoryService();

  List<InventoryTransaction> transactions = [];
  List<InventoryTransaction> filteredTransactions = [];

  bool isLoading = true;

  String selectedFilter = 'All';
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await inventoryService.getTransactions();

      if (!mounted) return;

      setState(() {
        transactions = data;
        isLoading = false;
      });

      applyFilters();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load transactions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void applyFilters() {
    List<InventoryTransaction> result = List.from(transactions);

    // Transaction type filter
    if (selectedFilter == 'Stock In') {
      result = result.where((transaction) {
        return transaction.isStockIn;
      }).toList();
    } else if (selectedFilter == 'Stock Out') {
      result = result.where((transaction) {
        return transaction.isStockOut;
      }).toList();
    }

    // Search filter
    if (searchQuery.trim().isNotEmpty) {
      final query = searchQuery.toLowerCase().trim();

      result = result.where((transaction) {
        final productName =
            transaction.productName?.toLowerCase() ?? '';

        final supplierName =
            transaction.supplierName?.toLowerCase() ?? '';

        final purpose =
            transaction.purpose.toLowerCase();

        final type =
            transaction.transactionType.toLowerCase();

        return productName.contains(query) ||
            supplierName.contains(query) ||
            purpose.contains(query) ||
            type.contains(query);
      }).toList();
    }

    setState(() {
      filteredTransactions = result;
    });
  }

  String formatDate(DateTime? date) {
    if (date == null) {
      return 'Unknown date';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year • $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Transaction History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: loadTransactions,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadTransactions,
        child: Column(
          children: [
            // SEARCH
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                10,
              ),
              child: TextField(
                onChanged: (value) {
                  searchQuery = value;
                  applyFilters();
                },
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            setState(() {
                              searchQuery = '';
                            });

                            applyFilters();
                          },
                          icon: const Icon(Icons.clear),
                        )
                      : null,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // FILTERS
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                children: [
                  _buildFilterChip('All'),
                  _buildFilterChip('Stock In'),
                  _buildFilterChip('Stock Out'),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // LIST
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : filteredTransactions.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            24,
                          ),
                          itemCount:
                              filteredTransactions.length,
                          itemBuilder: (context, index) {
                            return _buildTransactionCard(
                              filteredTransactions[index],
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filter) {
    final isSelected = selectedFilter == filter;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(filter),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            selectedFilter = filter;
          });

          applyFilters();
        },
      ),
    );
  }

  Widget _buildTransactionCard(
    InventoryTransaction transaction,
  ) {
    final stockIn = transaction.isStockIn;

    final productName =
        transaction.productName ?? 'Unknown Product';

    final unit = transaction.unit ?? 'units';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _showTransactionDetails(transaction);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // TRANSACTION ICON
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: stockIn
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.red.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Icon(
                  stockIn
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  color:
                      stockIn ? Colors.green : Colors.red,
                  size: 26,
                ),
              ),

              const SizedBox(width: 14),

              // TRANSACTION INFORMATION
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: stockIn
                                ? Colors.green
                                    .withValues(alpha: 0.12)
                                : Colors.red
                                    .withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Text(
                            transaction
                                .transactionType,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.w600,
                              color: stockIn
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        Text(
                          '${transaction.quantity} $unit',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 7),

                    if (transaction.purpose
                        .isNotEmpty)
                      Text(
                        transaction.purpose,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Icon(
                          Icons
                              .calendar_today_outlined,
                          size: 13,
                          color:
                              Colors.grey.shade600,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            formatDate(
                              transaction
                                  .transactionDate,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors
                                  .grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;

    if (searchQuery.isNotEmpty) {
      message =
          'No transactions match your search.';
    } else if (selectedFilter == 'Stock In') {
      message = 'No Stock In transactions yet.';
    } else if (selectedFilter == 'Stock Out') {
      message = 'No Stock Out transactions yet.';
    } else {
      message = 'No transactions recorded yet.';
    }

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),

        Icon(
          Icons.receipt_long_outlined,
          size: 70,
          color: Colors.grey.shade400,
        ),

        const SizedBox(height: 16),

        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ),

        const SizedBox(height: 8),

        Center(
          child: Text(
            'Stock movements will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
        ),
      ],
    );
  }

  void _showTransactionDetails(
    InventoryTransaction transaction,
  ) {
    final stockIn = transaction.isStockIn;

    final productName =
        transaction.productName ?? 'Unknown Product';

    final supplierName =
        transaction.supplierName ?? '';

    final userName =
        transaction.userName ??
        transaction.username ??
        '';

    final unit = transaction.unit ?? 'units';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: stockIn
                              ? Colors.green
                                  .withValues(alpha: 0.12)
                              : Colors.red
                                  .withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                        child: Icon(
                          stockIn
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: stockIn
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          productName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  _detailRow(
                    'Status',
                    transaction.transactionType,
                  ),

                  _detailRow(
                    'Quantity',
                    '${transaction.quantity} $unit',
                  ),

                  if (transaction.purpose
                      .isNotEmpty)
                    _detailRow(
                      'Purpose',
                      transaction.purpose,
                    ),

                  if (supplierName.isNotEmpty)
                    _detailRow(
                      'Supplier',
                      supplierName,
                    ),

                  if (userName.isNotEmpty)
                    _detailRow(
                      'Recorded By',
                      userName,
                    ),

                  if (transaction.notes
                      .isNotEmpty)
                    _detailRow(
                      'Notes',
                      transaction.notes,
                    ),

                  _detailRow(
                    'Date',
                    formatDate(
                      transaction.transactionDate,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: stockIn
                          ? Colors.green
                              .withValues(alpha: 0.08)
                          : Colors.red
                              .withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: stockIn
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Transaction recorded successfully',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.w600,
                              color: stockIn
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
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
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

