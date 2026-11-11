import '../models/product.dart';
import '../models/transaction.dart';

enum ReportPeriod { daily, weekly, monthly }

extension ReportPeriodLabel on ReportPeriod {
  String get label => switch (this) {
    ReportPeriod.daily => 'Daily',
    ReportPeriod.weekly => 'Weekly',
    ReportPeriod.monthly => 'Monthly',
  };
}

class InventoryReportService {
  Map<String, dynamic> buildReport({
    required ReportPeriod period,
    required DateTime now,
    required List<Product> products,
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> suppliers,
    required List<InventoryTransaction> transactions,
    required List<Map<String, dynamic>> notifications,
  }) {
    final window = _periodWindow(period, now);
    final currentTransactions = transactions
        .where(
          (transaction) =>
              _isInRange(transaction.transactionDate, window.start, window.end),
        )
        .toList();
    final previousTransactions = transactions
        .where(
          (transaction) => _isInRange(
            transaction.transactionDate,
            window.previousStart,
            window.previousEnd,
          ),
        )
        .toList();

    final productsById = {for (final product in products) product.id: product};
    final categoryNames = {
      for (final category in categories)
        _intValue(category['id']): category['name']?.toString() ?? 'Unassigned',
    };

    final lowStock = products.where((product) => product.isLowStock).toList();
    final criticalStock = products
        .where((product) => product.isCriticalStock)
        .toList();
    final stockIn = currentTransactions
        .where((transaction) => transaction.isStockIn)
        .toList();
    final stockOut = currentTransactions
        .where((transaction) => transaction.isStockOut)
        .toList();
    final previousStockOut = previousTransactions
        .where((transaction) => transaction.isStockOut)
        .toList();

    return {
      'period': period.label,
      'period_start': _date(window.start),
      'period_end': _date(window.end),
      'total_products': products.length,
      'raw_materials': products
          .where((product) => product.isRawMaterial)
          .length,
      'finished_products': products
          .where((product) => product.isFinishedProduct)
          .length,
      'total_suppliers': suppliers.length,
      'out_of_stock_count': products.where((product) => product.quantity <= 0).length,
      'low_stock_count': lowStock.length,
      'critical_stock_count': criticalStock.length,
      'stock_levels': products
          .map(
            (product) => _productFacts(
              product,
              categoryNames[product.categoryId] ?? 'Unassigned',
            ),
          )
          .toList(),
      'low_stock_products': lowStock
          .map(
            (product) => _productFacts(
              product,
              categoryNames[product.categoryId] ?? 'Unassigned',
            ),
          )
          .toList(),
      'critical_stock_products': criticalStock
          .map(
            (product) => _productFacts(
              product,
              categoryNames[product.categoryId] ?? 'Unassigned',
            ),
          )
          .toList(),
      'stock_in': {
        'transaction_count': stockIn.length,
        'quantity_total': _quantityTotal(stockIn),
      },
      'stock_out': {
        'transaction_count': stockOut.length,
        'quantity_total': _quantityTotal(stockOut),
      },
      'most_frequently_issued': _frequentlyIssued(
        stockOut,
        productsById,
        categoryNames,
      ),
      'increased_stock_outs': _increasedStockOuts(
        stockOut,
        previousStockOut,
        productsById,
        categoryNames,
      ),
      'transactions': _transactionFacts(
        currentTransactions,
        productsById,
        limit: 30,
      ),
      'transaction_count': currentTransactions.length,
      'previous_period_stock_out_count': previousStockOut.length,
      'notifications': notifications
          .take(10)
          .map(
            (notification) => {
              'title': notification['title'],
              'message': notification['message'],
              'type': notification['notification_type'],
              'created_at': notification['created_at'],
              'is_read': notification['is_read'],
            },
          )
          .toList(),
      'categories': categories
          .map(
            (category) => {
              'name': category['name'],
              'product_count': products
                  .where(
                    (product) =>
                        product.categoryId == _intValue(category['id']),
                  )
                  .length,
            },
          )
          .toList(),
      'suppliers': suppliers
          .map((supplier) => supplier['name'])
          .whereType<String>()
          .toList(),
    };
  }

  Map<String, dynamic> buildSnapshot({
    required DateTime now,
    required List<Product> products,
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> suppliers,
    required List<InventoryTransaction> transactions,
    required List<Map<String, dynamic>> notifications,
  }) {
    final snapshot = buildReport(
      period: ReportPeriod.weekly,
      now: now,
      products: products,
      categories: categories,
      suppliers: suppliers,
      transactions: transactions,
      notifications: notifications,
    );
    final productsById = {for (final product in products) product.id: product};
    final categoryNames = {
      for (final category in categories)
        _intValue(category['id']): category['name']?.toString() ?? 'Unassigned',
    };
    final allStockOuts = transactions
        .where((transaction) => transaction.isStockOut)
        .toList();

    snapshot['all_time_transaction_count'] = transactions.length;
    snapshot['all_time_stock_in_count'] = transactions
        .where((transaction) => transaction.isStockIn)
        .length;
    snapshot['all_time_stock_out_count'] = allStockOuts.length;
    snapshot['all_time_most_frequently_issued'] = _frequentlyIssued(
      allStockOuts,
      productsById,
      categoryNames,
    );
    snapshot['recent_transactions'] = _transactionFacts(
      transactions,
      productsById,
      limit: 20,
    );
    return snapshot;
  }

  Map<String, dynamic> _productFacts(Product product, String category) {
    final critical = product.isCriticalStock;
    final low = product.isLowStock;
    final recommendedQuantity = product.minimumStock > 0
        ? (product.minimumStock * 2 - product.quantity).clamp(
            0.0,
            double.infinity,
          )
        : 0.0;

    return {
      'id': product.id,
      'name': product.name,
      'item_type': product.itemType,
      'category': category,
      'quantity': product.quantity,
      'unit': product.unit,
      'minimum_stock': product.minimumStock,
      'status': product.quantity <= 0
          ? 'Out of Stock'
          : critical
          ? 'Critical'
          : low
          ? 'Low Stock'
          : 'Healthy',
      'recommended_restock_quantity': recommendedQuantity,
    };
  }

  List<Map<String, dynamic>> _frequentlyIssued(
    List<InventoryTransaction> transactions,
    Map<int, Product> productsById,
    Map<int, String> categoryNames,
  ) {
    final counts = <int, int>{};
    final quantities = <int, double>{};
    for (final transaction in transactions) {
      counts.update(
        transaction.productId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      quantities.update(
        transaction.productId,
        (quantity) => quantity + transaction.quantity,
        ifAbsent: () => transaction.quantity,
      );
    }

    final productIds = counts.keys.toList()
      ..sort((left, right) {
        final countOrder = counts[right]!.compareTo(counts[left]!);
        return countOrder != 0 ? countOrder : left.compareTo(right);
      });

    return productIds.take(10).map((id) {
      final product = productsById[id];
      return {
        'product': product?.name ?? 'Unknown product',
        'category': product == null
            ? 'Unassigned'
            : categoryNames[product.categoryId] ?? 'Unassigned',
        'issue_count': counts[id],
        'quantity_issued': quantities[id],
        'unit': product?.unit ?? '',
      };
    }).toList();
  }

  List<Map<String, dynamic>> _increasedStockOuts(
    List<InventoryTransaction> current,
    List<InventoryTransaction> previous,
    Map<int, Product> productsById,
    Map<int, String> categoryNames,
  ) {
    final currentCounts = _countsByProduct(current);
    final previousCounts = _countsByProduct(previous);
    final increasedIds = currentCounts.keys
        .where((id) => currentCounts[id]! > (previousCounts[id] ?? 0))
        .toList()
      ..sort((left, right) {
        final differenceLeft =
            currentCounts[left]! - (previousCounts[left] ?? 0);
        final differenceRight =
            currentCounts[right]! - (previousCounts[right] ?? 0);
        return differenceRight.compareTo(differenceLeft);
      });

    return increasedIds.take(10).map((id) {
      final product = productsById[id];
      return {
        'product': product?.name ?? 'Unknown product',
        'category': product == null
            ? 'Unassigned'
            : categoryNames[product.categoryId] ?? 'Unassigned',
        'current_period_stock_outs': currentCounts[id],
        'previous_period_stock_outs': previousCounts[id] ?? 0,
      };
    }).toList();
  }

  Map<int, int> _countsByProduct(List<InventoryTransaction> transactions) {
    final counts = <int, int>{};
    for (final transaction in transactions) {
      counts.update(
        transaction.productId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return counts;
  }

  List<Map<String, dynamic>> _transactionFacts(
    List<InventoryTransaction> transactions,
    Map<int, Product> productsById, {
    required int limit,
  }) {
    final recent = [...transactions]
      ..sort(
        (left, right) => (right.transactionDate ?? DateTime(0)).compareTo(
          left.transactionDate ?? DateTime(0),
        ),
      );

    return recent.take(limit).map((transaction) {
      final product = productsById[transaction.productId];
      return {
        'type': transaction.transactionType,
        'product': product?.name ?? transaction.productName ?? 'Unknown product',
        'quantity': transaction.quantity,
        'unit': transaction.unit ?? product?.unit ?? '',
        'date': transaction.transactionDate?.toIso8601String(),
        'purpose': transaction.purpose,
        'supplier': transaction.supplierName,
      };
    }).toList();
  }

  double _quantityTotal(List<InventoryTransaction> transactions) => transactions
      .fold(0.0, (total, transaction) => total + transaction.quantity);

  bool _isInRange(DateTime? date, DateTime start, DateTime end) {
    if (date == null) return false;
    final localDate = date.toLocal();
    return !localDate.isBefore(start) && localDate.isBefore(end);
  }

  _ReportWindow _periodWindow(ReportPeriod period, DateTime now) {
    final end = now.toLocal();
    final today = DateTime(end.year, end.month, end.day);
    final start = switch (period) {
      ReportPeriod.daily => today,
      ReportPeriod.weekly => today.subtract(const Duration(days: 6)),
      ReportPeriod.monthly => DateTime(end.year, end.month),
    };

    final periodLength = today.difference(start).inDays + 1;
    final previousMonth = DateTime(end.year, end.month - 1);
    final previousMonthLastDay = DateTime(
      previousMonth.year,
      previousMonth.month + 1,
      0,
    ).day;
    final previousEnd = period == ReportPeriod.monthly
        ? DateTime(
            previousMonth.year,
            previousMonth.month,
            (today.day < previousMonthLastDay
                    ? today.day
                    : previousMonthLastDay) +
                1,
          )
        : start;
    return _ReportWindow(
      start: start,
      end: end.add(const Duration(microseconds: 1)),
      previousStart: period == ReportPeriod.monthly
          ? previousMonth
          : start.subtract(Duration(days: periodLength)),
      previousEnd: previousEnd,
    );
  }

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  int _intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _ReportWindow {
  final DateTime start;
  final DateTime end;
  final DateTime previousStart;
  final DateTime previousEnd;

  const _ReportWindow({
    required this.start,
    required this.end,
    required this.previousStart,
    required this.previousEnd,
  });
}
