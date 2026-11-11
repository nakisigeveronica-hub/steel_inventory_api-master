import 'package:flutter_test/flutter_test.dart';
import 'package:steel_inventory_api/models/product.dart';
import 'package:steel_inventory_api/models/transaction.dart';
import 'package:steel_inventory_api/services/inventory_report_service.dart';

void main() {
  final reportService = InventoryReportService();
  final now = DateTime(2026, 11, 5, 13);
  final products = [
    const Product(
      id: 1,
      categoryId: 1,
      name: 'Steel Sheets',
      unit: 'pieces',
      quantity: 4,
      minimumStock: 10,
      itemType: 'Raw Material',
    ),
    const Product(
      id: 2,
      categoryId: 1,
      name: 'Iron Rods',
      unit: 'pieces',
      quantity: 8,
      minimumStock: 10,
      itemType: 'Raw Material',
    ),
    const Product(
      id: 3,
      categoryId: 2,
      name: 'Steel Bars',
      unit: 'pieces',
      quantity: 20,
      minimumStock: 10,
      itemType: 'Finished Product',
    ),
    const Product(
      id: 4,
      categoryId: 2,
      name: 'Bolts',
      unit: 'boxes',
      quantity: 0,
      minimumStock: 0,
      itemType: 'Finished Product',
    ),
  ];
  final transactions = [
    InventoryTransaction(
      id: 1,
      productId: 1,
      transactionType: 'Stock Out',
      quantity: 3,
      transactionDate: DateTime(2026, 11, 5, 10),
    ),
    InventoryTransaction(
      id: 2,
      productId: 1,
      transactionType: 'Stock Out',
      quantity: 2,
      transactionDate: DateTime(2026, 11, 5, 11),
    ),
    InventoryTransaction(
      id: 3,
      productId: 1,
      transactionType: 'Stock Out',
      quantity: 1,
      transactionDate: DateTime(2026, 11, 4, 10),
    ),
    InventoryTransaction(
      id: 4,
      productId: 2,
      transactionType: 'Stock In',
      quantity: 5,
      transactionDate: DateTime(2026, 11, 5, 12),
    ),
  ];

  test(
    'report uses inventory stock thresholds and period transaction data',
    () {
      final report = reportService.buildReport(
        period: ReportPeriod.daily,
        now: now,
        products: products,
        categories: const [
          {'id': 1, 'name': 'Steel'},
          {'id': 2, 'name': 'Finished Goods'},
        ],
        suppliers: const [
          {'name': 'Steel Supplier'},
        ],
        transactions: transactions,
        notifications: const [],
      );

      expect(report['total_products'], 4);
      expect(report['raw_materials'], 2);
      expect(report['finished_products'], 2);
      expect(report['low_stock_count'], 2);
      expect(report['critical_stock_count'], 1);
      expect(report['transaction_count'], 3);
      expect((report['stock_in'] as Map)['transaction_count'], 1);
      expect((report['stock_out'] as Map)['transaction_count'], 2);

      final increased = report['increased_stock_outs'] as List;
      expect(increased, hasLength(1));
      expect(increased.single['product'], 'Steel Sheets');
      expect(increased.single['previous_period_stock_outs'], 1);

      final frequent = report['most_frequently_issued'] as List;
      expect(frequent.single['product'], 'Steel Sheets');
      expect(frequent.single['quantity_issued'], 5);
    },
  );

  test('zero minimum stock is excluded from low and critical stock counts', () {
    final report = reportService.buildReport(
      period: ReportPeriod.daily,
      now: now,
      products: [products.last],
      categories: const [],
      suppliers: const [],
      transactions: const [],
      notifications: const [],
    );

    expect(report['low_stock_count'], 0);
    expect(report['critical_stock_count'], 0);
    expect((report['stock_levels'] as List).single['status'], 'Out of Stock');
  });
}
