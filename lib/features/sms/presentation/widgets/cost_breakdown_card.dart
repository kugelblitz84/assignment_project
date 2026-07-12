import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../domain/cost_breakdown.dart';

class CostBreakdownCard extends StatelessWidget {
  const CostBreakdownCard({super.key, required this.breakdown});

  final CostBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Monthly cost breakdown', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              breakdown.totalCost.format(),
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (breakdown.rows.isEmpty)
              const AppEmptyView(
                title: 'No cost yet',
                message: 'This tenant has no SMS spend in the selected month.',
                icon: Icons.receipt_long_outlined,
              )
            else
              ...breakdown.rows.map((row) => _CostRowTile(row: row)),
          ],
        ),
      ),
    );
  }
}

class _CostRowTile extends StatelessWidget {
  const _CostRowTile({required this.row});

  final CostBreakdownRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          CircleAvatar(
            child: Text(row.provider.isEmpty ? '?' : row.provider.substring(0, 1)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.provider, style: theme.textTheme.titleSmall),
                Text('${row.messageCount} messages', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Text(row.totalCost.format(), style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
