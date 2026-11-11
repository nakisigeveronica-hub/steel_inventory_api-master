import 'package:flutter_test/flutter_test.dart';
import 'package:steel_inventory_api/models/product.dart';

void main() {
  test('product reads and serializes its barcode', () {
    final product = Product.fromJson({
      'id': 1,
      'name': 'Steel Rod',
      'unit': 'Pieces',
      'minimum_stock': 5,
      'item_type': 'Raw Material',
      'barcode': '0123456789012',
    });

    expect(product.barcode, '0123456789012');
    expect(product.toJson()['barcode'], '0123456789012');
  });

  test('product barcode is optional for existing inventory records', () {
    final product = Product.fromJson({
      'id': 1,
      'name': 'Steel Rod',
      'unit': 'Pieces',
      'minimum_stock': 5,
      'item_type': 'Raw Material',
    });

    expect(product.barcode, isNull);
  });
}
