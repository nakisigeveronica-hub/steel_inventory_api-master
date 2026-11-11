import 'package:flutter/material.dart';

class DashboardAssistantCard extends StatelessWidget {
  final int lowStockItems;
  final int criticalStockItems;
  final VoidCallback onTap;

  const DashboardAssistantCard({
    super.key,
    required this.lowStockItems,
    required this.criticalStockItems,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool needsAttention = lowStockItems > 0 || criticalStockItems > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: needsAttention
                  ? Colors.orange.withValues(alpha: 0.20)
                  : theme.colorScheme.primary.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: needsAttention
                      ? Colors.orange.withValues(alpha: 0.10)
                      : theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  needsAttention
                      ? Icons.auto_awesome_rounded
                      : Icons.check_circle_rounded,
                  color: needsAttention
                      ? Colors.orange
                      : theme.colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventory Assistant',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      needsAttention
                          ? '$criticalStockItems critical and $lowStockItems low-stock items need attention.'
                          : 'Your inventory looks healthy.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.72,
                        ),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: needsAttention
                      ? Colors.orange.withValues(alpha: 0.10)
                      : theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  needsAttention ? 'Review' : 'Healthy',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: needsAttention
                        ? Colors.orange.shade800
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
