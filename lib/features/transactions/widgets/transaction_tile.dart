import 'package:flutter/material.dart';

import 'package:finance_tracker/features/categories/models/category.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';
import 'package:finance_tracker/core/utils/formatters.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.item, this.onTap});

  final TransactionItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cat = Category.byId(item.categoryId);
    final color = item.isExpense ? Colors.red.shade600 : Colors.green.shade600;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: cat.color.withValues(alpha: 0.15),
        child: Icon(cat.icon, color: cat.color),
      ),
      title: Text(item.title),
      subtitle: Text('${cat.name} • ${formatDay(item.date)}'),
      trailing: Text(
        '${item.isExpense ? '-' : '+'}${formatMoney(item.amount)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
