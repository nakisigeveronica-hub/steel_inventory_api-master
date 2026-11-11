import 'package:flutter/material.dart';
import '../models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showActions;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _getStockStatus(context);
    final statusColor = status['color'] as Color;
    final statusIcon = status['icon'] as IconData;
    final statusText = status['text'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ------------------------------------------------------------
              // TOP SECTION
              // ------------------------------------------------------------
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      _getProductIcon(),
                      color: theme.colorScheme.primary,
                      size: 27,
                    ),
                  ),

                  const SizedBox(width: 13),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          product.categoryName?.isNotEmpty == true
                              ? product.categoryName!
                              : product.itemType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.72,
                            ),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // More menu
                  if (showActions)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit?.call();
                        } else if (value == 'delete') {
                          onDelete?.call();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              const Text('Edit Product'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(width: 10),
                              const Text('Delete Product'),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // ------------------------------------------------------------
              // QUANTITY SECTION
              // ------------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _InfoItem(
                        label: 'Current Stock',
                        value: _formatNumber(product.quantity),
                        icon: Icons.inventory_2_outlined,
                      ),
                    ),

                    Container(width: 1, height: 38, color: theme.dividerColor),

                    Expanded(
                      child: _InfoItem(
                        label: 'Minimum Stock',
                        value: _formatNumber(product.minimumStock),
                        icon: Icons.flag_outlined,
                      ),
                    ),

                    Container(width: 1, height: 38, color: theme.dividerColor),

                    Expanded(
                      child: _InfoItem(
                        label: 'Unit',
                        value: product.unit,
                        icon: Icons.straighten_outlined,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 13),

              // ------------------------------------------------------------
              // BOTTOM STATUS + ITEM TYPE
              // ------------------------------------------------------------
              Row(
                children: [
                  // Stock status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 15, color: statusColor),
                        const SizedBox(width: 5),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Item type
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          product.itemType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.75,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
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
  }

  // ------------------------------------------------------------------------
  // STOCK STATUS
  // ------------------------------------------------------------------------

  Map<String, dynamic> _getStockStatus(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (product.quantity <= 0) {
      return {
        'text': 'Out of Stock',
        'color': scheme.error,
        'icon': Icons.remove_shopping_cart_outlined,
      };
    }

    if (product.quantity <= product.minimumStock * 0.5) {
      return {
        'text': 'Critical Stock',
        'color': scheme.errorContainer.withValues(alpha: 0.92),
        'icon': Icons.warning_amber_rounded,
      };
    }

    if (product.quantity <= product.minimumStock) {
      return {
        'text': 'Low Stock',
        'color': scheme.tertiary,
        'icon': Icons.warning_amber_outlined,
      };
    }

    return {
      'text': 'Stock Available',
      'color': scheme.primary,
      'icon': Icons.check_circle_outline,
    };
  }

  // ------------------------------------------------------------------------
  // PRODUCT ICON
  // ------------------------------------------------------------------------

  IconData _getProductIcon() {
    final type = product.itemType.toLowerCase();

    if (type.contains('raw')) {
      return Icons.precision_manufacturing_outlined;
    }

    if (type.contains('finished')) {
      return Icons.inventory_2_outlined;
    }

    return Icons.category_outlined;
  }

  // ------------------------------------------------------------------------
  // NUMBER FORMAT
  // ------------------------------------------------------------------------

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}

// ============================================================================
// INFO ITEM
// ============================================================================

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, size: 17, color: theme.colorScheme.primary),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
