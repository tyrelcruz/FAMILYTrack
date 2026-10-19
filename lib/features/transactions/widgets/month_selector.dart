import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/features/transactions/providers/finance_provider.dart';
import 'package:finance_tracker/core/utils/formatters.dart';

class MonthSelector extends StatelessWidget {
  const MonthSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FinanceProvider>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => p.changeMonth(-1),
        ),
        Text(
          formatMonth(p.month),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => p.changeMonth(1),
        ),
      ],
    );
  }
}
