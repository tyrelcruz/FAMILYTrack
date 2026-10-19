import 'package:finance_tracker/core/widgets/empty_state.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';
import 'package:finance_tracker/features/transactions/widgets/activity_row.dart';
import 'package:flutter/material.dart';

/// Latest transactions as plain rows on the page background.
class RecentActivity extends StatelessWidget {
  const RecentActivity({
    super.key,
    required this.items,
    required this.format,
    required this.onTap,
  });

  final List<TransactionItem> items;
  final String Function(double) format;
  final ValueChanged<TransactionItem> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const EmptyState('No activity yet');
    return Column(
      children: [
        for (final t in items)
          ActivityRow(item: t, format: format, onTap: () => onTap(t)),
      ],
    );
  }
}
