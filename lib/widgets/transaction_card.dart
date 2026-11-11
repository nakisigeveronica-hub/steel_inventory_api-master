import 'package:flutter/material.dart';

class TransactionCard extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback? onTap;

  const TransactionCard({super.key, required this.transaction, this.onTap});

  String _stringValue(String key) {
    return transaction[key]?.toString() ?? '';
  }

  double _quantity() {
    return double.tryParse(transaction['quantity']?.toString() ?? '0') ?? 0;
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  bool get _isStockIn {
    final type = _stringValue(
      'transaction_type',
    ).toLowerCase().replaceAll('_', ' ').trim();

    return type == 'stock in' || type == 'stock-in' || type == 'in';
  }

  String get _transactionType {
    if (_isStockIn) {
      return 'Stock In';
    }

    return 'Stock Out';
  }

  IconData get _transactionIcon {
    return _isStockIn
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;
  }

  Color _transactionColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _isStockIn ? scheme.primary : scheme.error;
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return 'Date unavailable';
    }

    final date = DateTime.tryParse(value.toString());

    if (date == null) {
      return value.toString();
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
    final theme = Theme.of(context);
    final productName = _stringValue('product_name').isNotEmpty
        ? _stringValue('product_name')
        : _stringValue('name').isNotEmpty
        ? _stringValue('name')
        : 'Unknown Product';

    final unit = _stringValue('unit');

    final quantity = _quantity();

    final userName = _stringValue('user_name').isNotEmpty
        ? _stringValue('user_name')
        : _stringValue('username');

    final supplierName = _stringValue('supplier_name');

    final purpose = _stringValue('purpose');

    final notes = _stringValue('notes');

    final transactionDate =
        transaction['transaction_date'] ?? transaction['created_at'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ------------------------------------------------
                // TOP ROW
                // ------------------------------------------------
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _transactionColor(
                          context,
                        ).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _transactionIcon,
                        color: _transactionColor(context),
                        size: 24,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Row(
                            children: [
                              _typeBadge(context),

                              if (userName.isNotEmpty) ...[
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    'by $userName',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.72),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_isStockIn ? '+' : '-'}${_formatQuantity(quantity)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: _transactionColor(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (unit.isNotEmpty)
                          Text(
                            unit,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ------------------------------------------------
                // DETAILS
                // ------------------------------------------------
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Column(
                    children: [
                      if (supplierName.isNotEmpty)
                        _detailRow(
                          context: context,
                          icon: Icons.local_shipping_outlined,
                          label: 'Supplier',
                          value: supplierName,
                        ),

                      if (purpose.isNotEmpty)
                        _detailRow(
                          context: context,
                          icon: Icons.assignment_outlined,
                          label: 'Purpose',
                          value: purpose,
                        ),

                      _detailRow(
                        context: context,
                        icon: Icons.calendar_today_outlined,
                        label: 'Date',
                        value: _formatDate(transactionDate),
                        isLast: notes.isEmpty,
                      ),

                      if (notes.isNotEmpty)
                        _detailRow(
                          context: context,
                          icon: Icons.notes_outlined,
                          label: 'Notes',
                          value: notes,
                          isLast: true,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeBadge(BuildContext context) {
    final transactionColor = _transactionColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: transactionColor.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _transactionType.toUpperCase(),
        style: TextStyle(
          color: transactionColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _detailRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: theme.colorScheme.primary),

          const SizedBox(width: 9),

          SizedBox(
            width: 68,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ),

          const SizedBox(width: 5),

          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
