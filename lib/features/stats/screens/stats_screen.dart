import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/features/categories/models/category.dart';
import 'package:finance_tracker/features/transactions/providers/finance_provider.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/features/transactions/widgets/month_selector.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FinanceProvider>();
    final byCat = p.expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = p.monthExpense;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const MonthSelector(),
        Text(
          'Spending by category',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        if (byCat.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No expenses this month')),
          )
        else ...[
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: [
                  for (final e in byCat)
                    PieChartSectionData(
                      value: e.value,
                      color: Category.byId(e.key).color,
                      title: '${(e.value / total * 100).round()}%',
                      radius: 60,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final e in byCat)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Category.byId(
                  e.key,
                ).color.withValues(alpha: 0.15),
                child: Icon(
                  Category.byId(e.key).icon,
                  color: Category.byId(e.key).color,
                ),
              ),
              title: Text(Category.byId(e.key).name),
              trailing: Text(
                formatMoney(e.value),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ],
    );
  }
}
