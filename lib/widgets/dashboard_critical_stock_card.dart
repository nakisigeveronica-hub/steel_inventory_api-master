import 'package:flutter/material.dart';

class DashboardCriticalStockCard extends StatelessWidget {
  final int criticalStockItems;
  final VoidCallback onTap;

  const DashboardCriticalStockCard({
    super.key,
    required this.criticalStockItems,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasCritical = criticalStockItems > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasCritical
                ? theme.colorScheme.errorContainer.withValues(alpha: 0.18)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasCritical
                  ? theme.colorScheme.error.withValues(alpha: 0.25)
                  : theme.dividerColor,
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: hasCritical
                      ? theme.colorScheme.error.withValues(alpha: 0.10)
                      : theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  hasCritical
                      ? Icons.priority_high_rounded
                      : Icons.check_circle_rounded,
                  color: hasCritical
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasCritical ? 'Critical Stock Alert' : 'Critical Stock',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasCritical
                          ? '$criticalStockItems item${criticalStockItems == 1 ? '' : 's'} critically low.'
                          : 'No critical stock items.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: hasCritical
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  criticalStockItems.toString(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
