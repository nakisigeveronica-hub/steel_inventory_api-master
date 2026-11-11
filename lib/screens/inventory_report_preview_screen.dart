import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InventoryReportPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> report;
  final String executiveSummary;

  const InventoryReportPreviewScreen({
    super.key,
    required this.report,
    required this.executiveSummary,
  });

  List<Map<String, dynamic>> _items(String key) {
    final values = report[key];
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  String _text(dynamic value) => value?.toString() ?? '0';

  String _quantity(dynamic value) {
    if (value is num && value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value?.toString() ?? '0';
  }

  Future<Uint8List> _buildPdf(PdfPageFormat pageFormat) async {
    final document = pw.Document();
    final stockLevels = _items('stock_levels');
    final lowStockProducts = _items('low_stock_products');
    final criticalStockProducts = _items('critical_stock_products');
    final transactions = _items('transactions');
    final increasedStockOuts = _items('increased_stock_outs');
    final frequentIssues = _items('most_frequently_issued');
    final stockIn = report['stock_in'] as Map? ?? const {};
    final stockOut = report['stock_out'] as Map? ?? const {};

    final content = <pw.Widget>[
      pw.Text(
        'Steel Inventory Report',
        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        '${_text(report['period'])} · ${_text(report['period_start'])} to '
        '${_text(report['period_end'])}',
      ),
      pw.Divider(),
      pw.Text(
        'Executive Summary',
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 5),
      pw.Text(executiveSummary),
      pw.SizedBox(height: 14),
      pw.Text(
        'Inventory Summary',
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 5),
      pw.Text('Total products: ${_text(report['total_products'])}'),
      pw.Text('Raw materials: ${_text(report['raw_materials'])}'),
      pw.Text('Finished products: ${_text(report['finished_products'])}'),
      pw.Text('Suppliers: ${_text(report['total_suppliers'])}'),
      pw.Text('Low-stock products: ${_text(report['low_stock_count'])}'),
      pw.Text(
        'Critical-stock products: ${_text(report['critical_stock_count'])}',
      ),
      pw.SizedBox(height: 12),
      pw.Text(
        'Stock Activity',
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 5),
      pw.Text(
        'Stock in: ${_text(stockIn['transaction_count'])} transactions, '
        '${_quantity(stockIn['quantity_total'])} units received',
      ),
      pw.Text(
        'Stock out: ${_text(stockOut['transaction_count'])} transactions, '
        '${_quantity(stockOut['quantity_total'])} units issued',
      ),
      pw.SizedBox(height: 12),
      pw.Text(
        'Current Stock Levels',
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 5),
      if (stockLevels.isEmpty)
        pw.Text('No products are recorded.')
      else
        ...stockLevels.map(
          (product) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Text(
              '${product['name']} (${product['category']}) — '
              '${_quantity(product['quantity'])} ${product['unit']}; '
              'minimum ${_quantity(product['minimum_stock'])}; '
              '${product['status']}',
            ),
          ),
        ),
      pw.SizedBox(height: 12),
      pw.Text(
        'Restocking Recommendations',
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 5),
      if (lowStockProducts.isEmpty)
        pw.Text('No products are below their minimum stock.')
      else
        ...lowStockProducts.map(
          (product) => pw.Text(
            '${product['name']}: order '
            '${_quantity(product['recommended_restock_quantity'])} '
            '${product['unit']} (current '
            '${_quantity(product['quantity'])}, minimum '
            '${_quantity(product['minimum_stock'])})',
          ),
        ),
      pw.SizedBox(height: 12),
      pw.Text(
        'Critical-Stock Products',
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 5),
      if (criticalStockProducts.isEmpty)
        pw.Text('No critical-stock products are recorded.')
      else
        ...criticalStockProducts.map(
          (product) => pw.Text(
            '${product['name']}: ${_quantity(product['quantity'])} '
            '${product['unit']} (minimum '
            '${_quantity(product['minimum_stock'])})',
          ),
        ),
      pw.SizedBox(height: 12),
      pw.Text(
        'Inventory Trends',
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 5),
      if (increasedStockOuts.isEmpty)
        pw.Text('No increased stock-out frequency was found.')
      else
        ...increasedStockOuts.map(
          (product) => pw.Text(
            '${product['product']}: ${_text(product['current_period_stock_outs'])} '
            'stock-outs vs ${_text(product['previous_period_stock_outs'])} '
            'in the previous period',
          ),
        ),
      pw.SizedBox(height: 8),
      pw.Text('Most frequently issued:'),
      if (frequentIssues.isEmpty)
        pw.Text('No stock-out transactions were recorded.')
      else
        ...frequentIssues.map(
          (item) => pw.Text(
            '${item['product']}: ${_text(item['issue_count'])} issues, '
            '${_quantity(item['quantity_issued'])} ${item['unit']}',
          ),
        ),
      pw.SizedBox(height: 12),
      pw.Text(
        'Transactions in this period (${transactions.length} shown of '
        '${_text(report['transaction_count'])} total)',
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 5),
      if (transactions.isEmpty)
        pw.Text('No transactions were recorded in this period.')
      else
        ...transactions.map(
          (transaction) => pw.Text(
            '${transaction['date'] ?? 'Unknown date'} · '
            '${transaction['type']} · ${transaction['product']} · '
            '${_quantity(transaction['quantity'])} ${transaction['unit']}',
          ),
        ),
    ];

    document.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => content,
      ),
    );
    return document.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory Report PDF')),
      body: PdfPreview(
        build: _buildPdf,
        pdfFileName: 'steel-inventory-${report['period']}.pdf',
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: true,
        initialPageFormat: PdfPageFormat.a4,
      ),
    );
  }
}
